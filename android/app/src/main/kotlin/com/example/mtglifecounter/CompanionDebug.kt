package com.example.mtglifecounter

import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.os.Build
import android.util.Log
import org.json.JSONObject
import java.io.File

/**
 * Registro de diagnóstico de «Eventos de Companion» (mientras esté en beta):
 * qué ve y qué decide cada parte, para entender tras un torneo qué ha ido
 * bien o mal (solo hay uno al mes). Lo escriben el servicio de avisos, el de
 * la pantalla y la app (canal mtglifecounter/companion, método "log"), cada
 * uno con su `src`.
 *
 * Va en Android/data/<paquete>/files/companion_debug.jsonl, una línea JSON
 * por cosa, y se baja con `adb pull`. Al pasar de [MAX_BYTES] se guarda el
 * anterior como .1 (no se borra lo de un torneo a medias).
 */
object CompanionDebug {
    private const val FILE = "companion_debug.jsonl"
    private const val MAX_BYTES = 20L * 1024 * 1024

    @Synchronized
    fun log(context: Context, src: String, ev: String, data: JSONObject = JSONObject()) {
        data.put("at", System.currentTimeMillis()).put("src", src).put("ev", ev)
            // El procesador gastado por el proceso que escribe (`:companion`
            // en «notif» y «screen», el de la app en «app») desde que
            // arrancó, y cuál es: entre dos líneas del mismo pid sale lo que
            // gasta (en un Pixel 9a, 0,02 % de un núcleo con Companion
            // cerrada y ~1,5 % abierta con el reloj en marcha).
            .put("cpuMs", android.os.Process.getElapsedCpuTime())
            .put("pid", android.os.Process.myPid())
        append(context, FILE, data)
    }

    /** El % de batería, para ver lo que gasta a lo largo de un torneo. */
    fun battery(context: Context): Int? = try {
        val status = context.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
        val level = status?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
        val scale = status?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
        if (level < 0 || scale <= 0) null else level * 100 / scale
    } catch (e: Exception) {
        null
    }

    /** Si Android no le aplica el ahorro de batería a la app. */
    fun batteryExempt(context: Context): Boolean = try {
        val power = context.getSystemService(android.os.PowerManager::class.java)
        power.isIgnoringBatteryOptimizations(context.packageName)
    } catch (e: Exception) {
        false
    }

    /** Xiaomi (y sus marcas): duerme las apps aunque no tengan ahorro. */
    fun isXiaomi(): Boolean {
        val brand = "${Build.MANUFACTURER} ${Build.BRAND}".lowercase()
        return listOf("xiaomi", "redmi", "poco").any { brand.contains(it) }
    }

    /** La versión de una app instalada (Companion o esta), o null. */
    fun version(context: Context, pkg: String): String? = try {
        val info = context.packageManager.getPackageInfo(pkg, 0)
        @Suppress("DEPRECATION")
        "${info.versionName} (${info.versionCode})"
    } catch (e: Exception) {
        null
    }

    /**
     * APK DE PRUEBA («Enviar trazas»): junta los registros en un zip y abre el
     * menú de compartir de Android, sin destinatario (quien lo manda sabe a
     * quién). En las pantallas de Companion los nombres de los jugadores se
     * cambian por «[nombre]»: no hacen falta y son de otra gente.
     */
    fun share(activity: android.app.Activity) {
        val dir = activity.getExternalFilesDir(null) ?: activity.filesDir
        val out = File(activity.cacheDir, "traces").apply { mkdirs() }
        out.listFiles()?.forEach { it.delete() }
        val stamp = java.text.SimpleDateFormat("yyyyMMdd-HHmm", java.util.Locale.ROOT)
            .format(java.util.Date())
        val zip = File(out, "trazas-companion-$stamp.zip")
        java.util.zip.ZipOutputStream(zip.outputStream().buffered()).use { z ->
            z.putNextEntry(java.util.zip.ZipEntry("info.txt"))
            z.write(info(activity).toByteArray())
            z.closeEntry()
            val names = listOf("companion_log.jsonl", "companion_screen.jsonl", "companion_debug.jsonl")
            for (name in names.flatMap { listOf("$it.1", it) }) {
                val file = File(dir, name)
                if (!file.exists()) continue
                z.putNextEntry(java.util.zip.ZipEntry(name))
                val writer = z.bufferedWriter()
                file.forEachLine { line ->
                    writer.write(if (name.startsWith("companion_screen")) hideNames(line) else line)
                    writer.write("\n")
                }
                writer.flush()
                z.closeEntry()
            }
        }
        val uri = androidx.core.content.FileProvider.getUriForFile(
            activity, "${activity.packageName}.updates", zip,
        )
        val send = Intent(Intent.ACTION_SEND)
            .setType("application/zip")
            .putExtra(Intent.EXTRA_STREAM, uri)
            .putExtra(Intent.EXTRA_SUBJECT, "Trazas de Companion ($stamp)")
            .putExtra(
                Intent.EXTRA_TEXT,
                "Trazas del contador con «Eventos de Companion» (${Build.MODEL}, $stamp).",
            )
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        activity.startActivity(Intent.createChooser(send, "Enviar trazas"))
    }

    // Lo del móvil, para saber de dónde vienen las trazas.
    private fun info(context: Context) = buildString {
        appendLine("Móvil: ${Build.MANUFACTURER} ${Build.MODEL}")
        appendLine("Android: ${Build.VERSION.RELEASE} (API ${Build.VERSION.SDK_INT})")
        appendLine("Contador: ${version(context, context.packageName)}")
        appendLine("Companion: ${version(context, CompanionListener.COMPANION)}")
        appendLine("Batería: ${battery(context)} %")
        appendLine("Sin ahorro de batería: ${batteryExempt(context)}")
        appendLine("Acceso a notificaciones: ${notifAccess(context)}")
        appendLine("Lectura de pantalla (Accesibilidad): ${screenAccess(context)}")
        appendLine("Enviado: ${java.util.Date()}")
    }

    /** Si Android le ha dado a la app el acceso a notificaciones. */
    fun notifAccess(context: Context): Boolean =
        androidx.core.app.NotificationManagerCompat.getEnabledListenerPackages(context)
            .contains(context.packageName)

    /**
     * Si el servicio que lee la pantalla de Companion está activado en
     * Ajustes → Accesibilidad. Se apunta en las trazas porque un Xiaomi
     * (MIUI) lo apagó al matar la app y no quedó rastro de por qué no leía.
     */
    fun screenAccess(context: Context): Boolean {
        val enabled = android.provider.Settings.Secure.getString(
            context.contentResolver,
            android.provider.Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
        ) ?: return false
        val component = android.content.ComponentName(context, CompanionScreenService::class.java)
        return enabled.split(':').any {
            android.content.ComponentName.unflattenFromString(it) == component
        }
    }

    // Una pantalla de Companion sin datos de personas: los nombres de los
    // jugadores (los elementos cuyo nombre interno lleva «name», como
    // playerName u opponents_name, y «Uniéndose como …», joining_as_text) y
    // las distancias a las tiendas («0,3 km»), que dicen dónde está quien lo
    // manda. Lo demás (puesto, puntos, récord, porcentajes) se queda.
    private val DISTANCE = Regex("""^\s*[\d.,]+\s*(km|m|mi)\s*$""")

    private fun hideNames(line: String): String = try {
        val o = JSONObject(line)
        val nodes = o.optJSONArray("nodes")
        if (nodes != null) {
            for (i in 0 until nodes.length()) {
                val node = nodes.getJSONObject(i)
                val id = node.optString("id").lowercase()
                for (key in listOf("text", "desc")) {
                    if (node.isNull(key)) continue
                    val value = node.getString(key)
                    when {
                        id.contains("name") && !id.contains("header") ->
                            node.put(key, "[nombre]")
                        id.contains("joining_as") -> node.put(key, "[nombre]")
                        DISTANCE.matches(value) -> node.put(key, "[distancia]")
                    }
                }
            }
        }
        o.toString()
    } catch (e: Exception) {
        line
    }

    /**
     * Añade una línea a un archivo de la carpeta de la app que se baja con
     * adb. Pasado el tope, el de antes queda como `<nombre>.1`.
     */
    @Synchronized
    fun append(context: Context, name: String, o: JSONObject) {
        try {
            val dir = context.getExternalFilesDir(null) ?: context.filesDir
            val file = File(dir, name)
            if (file.length() > MAX_BYTES) {
                val old = File(dir, "$name.1")
                old.delete()
                file.renameTo(old)
            }
            file.appendText(o.toString() + "\n")
        } catch (e: Exception) {
            Log.w("CompanionDebug", "no se pudo guardar $name: $e")
        }
    }
}
