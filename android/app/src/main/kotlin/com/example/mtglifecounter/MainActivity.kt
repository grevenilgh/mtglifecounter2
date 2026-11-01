package com.example.mtglifecounter

import android.content.ComponentName
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    // Icono pedido desde Dart, a la espera de que la app pase a segundo plano.
    private var pendingIcon: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
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
