package com.example.mtglifecounter

import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.Uri
import android.provider.Settings
import android.service.notification.NotificationListenerService
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.os.Build
import android.os.VibrationAttributes
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    // Icono pedido desde Dart, a la espera de que la app pase a segundo plano.
    private var pendingIcon: String? = null

    private var companionChannel: MethodChannel? = null

    // Llega del servicio de Companion (otro proceso) con cada aviso nuevo:
    // la app vuelve a leer los avisos.
    private val companionReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            companionChannel?.invokeMethod("changed", null)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        companionChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "mtglifecounter/companion",
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "setEnabled" -> {
                        setCompanionEnabled(call.arguments as Boolean)
                        result.success(null)
                    }
                    "hasAccess" -> result.success(CompanionDebug.notifAccess(this))
                    "openAccess" -> {
                        openCompanionAccess()
                        result.success(null)
                    }
                    // Trazas provisionales de la app (ver CompanionDebug.kt).
                    "log" -> {
                        val args = call.arguments as Map<*, *>
                        val data = org.json.JSONObject()
                        (args["data"] as? Map<*, *>)?.forEach { (k, v) ->
                            // wrap: los mapas de dentro (el reloj antes y
                            // después) como objetos, no como texto.
                            data.put(k.toString(), org.json.JSONObject.wrap(v) ?: org.json.JSONObject.NULL)
                        }
                        val ev = args["ev"].toString()
                        // Al abrir, volver y activarlo: si siguen los dos
                        // permisos (MIUI apaga la accesibilidad sin avisar).
                        if (ev in setOf("app-open", "app-resumed", "enabled")) {
                            data.put("notifAccess", CompanionDebug.notifAccess(this))
                            data.put("screenAccess", CompanionDebug.screenAccess(this))
                        }
                        CompanionDebug.log(this, "app", ev, data)
                        result.success(null)
                    }
                    // APK de prueba: el zip de las trazas, para compartirlo.
                    "shareTraces" -> {
                        try {
                            CompanionDebug.share(this)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("share", e.message, null)
                        }
                    }
                    // Ahorro de batería: si Android duerme la app, los avisos
                    // de Companion le llegan tarde (visto en un Xiaomi).
                    "batteryExempt" -> result.success(CompanionDebug.batteryExempt(this))
                    "askBatteryExempt" -> {
                        askBatteryExempt()
                        result.success(null)
                    }
                    "isXiaomi" -> result.success(CompanionDebug.isXiaomi())
                    "openAutostart" -> {
                        openAutostart()
                        result.success(null)
                    }
                    "setScreenEnabled" -> {
                        CompanionScreenService.setOn(this, call.arguments as Boolean)
                        result.success(null)
                    }
                    "hasScreenAccess" -> result.success(hasScreenAccess())
                    "openScreenAccess" -> {
                        openScreenAccess()
                        result.success(null)
                    }
                    "openAppInfo" -> {
                        startActivity(
                            Intent(
                                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                Uri.fromParts("package", packageName, null),
                            ),
                        )
                        result.success(null)
                    }
                    "events" -> result.success(
                        CompanionListener.read(this).map {
                            mapOf(
                                "kind" to it.getString("kind"),
                                "at" to it.getLong("at"),
                                "left" to (if (it.has("left")) it.getLong("left") else null),
                            )
                        },
                    )
                    else -> result.notImplemented()
                }
            }
        }
        ContextCompat.registerReceiver(
            this,
            companionReceiver,
            IntentFilter(CompanionListener.ACTION_CHANGED),
            ContextCompat.RECEIVER_NOT_EXPORTED,
        )
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "mtglifecounter/app_icon")
            .setMethodCallHandler { call, result ->
                if (call.method == "set") {
                    pendingIcon = call.arguments as? String
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "mtglifecounter/update")
            .setMethodCallHandler { call, result ->
                if (call.method == "install") {
                    try {
                        openInstaller(File(call.arguments as String))
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("install", e.message, null)
                    }
                } else {
                    result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "mtglifecounter/vibrate")
            .setMethodCallHandler { call, result ->
                if (call.method == "vibrate") {
                    vibrate((call.arguments as Number).toLong())
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }

    // Vibra con el motor del móvil. La vibración de Flutter (HapticFeedback)
    // no se nota si en el móvil está apagada la vibración al tocar, y una
    // vibración sin tipo se la salta Android si la de multimedia está a cero.
    // Va como la de una alarma: es la que la gente deja encendida, y el reloj
    // de la ronda es eso.
    private fun vibrate(ms: Long) {
        val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            getSystemService(VibratorManager::class.java).defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(VIBRATOR_SERVICE) as Vibrator
        }
        if (!vibrator.hasVibrator()) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            vibrator.vibrate(
                VibrationEffect.createOneShot(ms, 255),
                VibrationAttributes.createForUsage(VibrationAttributes.USAGE_ALARM),
            )
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            @Suppress("DEPRECATION")
            vibrator.vibrate(
                VibrationEffect.createOneShot(ms, 255),
                AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ALARM).build(),
            )
        } else {
            @Suppress("DEPRECATION")
            vibrator.vibrate(ms)
        }
    }

    // Abre el instalador de Android con la APK descargada. Pregunta antes de
    // instalarla encima y, la primera vez, pide permiso para instalar apps
    // desde esta.
    private fun openInstaller(apk: File) {
        val uri = FileProvider.getUriForFile(this, "$packageName.updates", apk)
        startActivity(
            Intent(Intent.ACTION_VIEW)
                .setDataAndType(uri, "application/vnd.android.package-archive")
                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK),
        )
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        try {
            unregisterReceiver(companionReceiver)
        } catch (e: IllegalArgumentException) {
            // No estaba registrado.
        }
        companionChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    // Le dice al servicio de Companion si tiene que hacer caso a los avisos
    // (con un archivo que mira él, en otro proceso). No se desactiva el
    // componente: Android le quitaría el acceso a notificaciones y habría que
    // darlo otra vez. Al encenderlo se le pide a Android que lo conecte ya.
    private fun setCompanionEnabled(enabled: Boolean) {
        CompanionListener.setOn(this, enabled)
        if (enabled) {
            val component = ComponentName(this, CompanionListener::class.java)
            // Lo dejan desactivado las versiones de prueba anteriores.
            if (packageManager.getComponentEnabledSetting(component) ==
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED
            ) {
                packageManager.setComponentEnabledSetting(
                    component,
                    PackageManager.COMPONENT_ENABLED_STATE_DEFAULT,
                    PackageManager.DONT_KILL_APP,
                )
            }
            NotificationListenerService.requestRebind(component)
        }
    }

    // Pide a Android que no le aplique el ahorro de batería a la app (Android
    // pregunta con su propio aviso). Si no deja, la lista de apps.
    @android.annotation.SuppressLint("BatteryLife")
    private fun askBatteryExempt() {
        try {
            startActivity(
                Intent(
                    Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                    Uri.fromParts("package", packageName, null),
                ),
            )
        } catch (e: Exception) {
            startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
        }
    }

    // En Xiaomi, además, «Inicio automático»: sin él, la app no se despierta
    // con los avisos. La pantalla es de Xiaomi; si no está, la de la app.
    private fun openAutostart() {
        val xiaomi = Intent().setComponent(
            ComponentName(
                "com.miui.securitycenter",
                "com.miui.permcenter.autostart.AutoStartManagementActivity",
            ),
        )
        try {
            startActivity(xiaomi)
        } catch (e: Exception) {
            startActivity(
                Intent(
                    Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                    Uri.fromParts("package", packageName, null),
                ),
            )
        }
    }

    // Si el servicio que lee la pantalla de Companion está activado en
    // Ajustes → Accesibilidad.
    private fun hasScreenAccess(): Boolean = CompanionDebug.screenAccess(this)

    // La pantalla de Android del servicio (si el móvil la tiene) o la lista
    // de Accesibilidad.
    private fun openScreenAccess() {
        val component = ComponentName(this, CompanionScreenService::class.java)
        try {
            startActivity(
                Intent("android.settings.ACCESSIBILITY_DETAILS_SETTINGS")
                    .putExtra(Intent.EXTRA_COMPONENT_NAME, component.flattenToString()),
            )
        } catch (e: Exception) {
            startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
        }
    }

    // La pantalla de Android donde se da el acceso a notificaciones: la de
    // esta app directamente si se puede (Android 11+), si no la lista.
    private fun openCompanionAccess() {
        val component = ComponentName(this, CompanionListener::class.java)
        val detail = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            Intent(Settings.ACTION_NOTIFICATION_LISTENER_DETAIL_SETTINGS)
                .putExtra(
                    Settings.EXTRA_NOTIFICATION_LISTENER_COMPONENT_NAME,
                    component.flattenToString(),
                )
        } else {
            null
        }
        try {
            startActivity(detail ?: Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
        } catch (e: Exception) {
            startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
        }
    }

    // El icono se cambia al salir de la app: con ella abierta, algunos móviles
    // la cierran al desactivar la entrada del lanzador que la abrió.
    override fun onStop() {
        super.onStop()
        pendingIcon?.let { applyIcon(it) }
        pendingIcon = null
    }

    private fun applyIcon(icon: String) {
        // En la versión de depuración el icono se queda en AlicanteMTG: flutter run
        // abre la app siempre por esa entrada y, desde Android 14, adb ya no puede
        // volver a encenderla. Así también se arregla sola si estaba apagada.
        val debuggable = applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0
        val wanted = ALIASES[if (debuggable) "alicante" else icon] ?: return
        // Primero se activa la nueva para que siempre haya una en el lanzador.
        setAlias(wanted, true)
        for (alias in ALIASES.values) {
            if (alias != wanted) setAlias(alias, false)
        }
    }

    private fun setAlias(alias: String, enabled: Boolean) {
        val component = ComponentName(this, "com.example.mtglifecounter.$alias")
        val current = when (packageManager.getComponentEnabledSetting(component)) {
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED -> true
            PackageManager.COMPONENT_ENABLED_STATE_DISABLED -> false
            // Sin tocar, vale lo que dice el manifiesto: solo AlicanteMTG activa.
            else -> alias == ALIASES["alicante"]
        }
        if (current == enabled) return
        packageManager.setComponentEnabledSetting(
            component,
            if (enabled) PackageManager.COMPONENT_ENABLED_STATE_ENABLED
            else PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
            PackageManager.DONT_KILL_APP,
        )
    }

    companion object {
        private val ALIASES = mapOf(
            "alicante" to "AliasAlicante",
            "fulltapped" to "AliasFullTapped",
            "oldschool" to "AliasOldSchool",
            "mesa" to "AliasMesa",
        )
    }
}
