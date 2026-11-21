package com.example.mtglifecounter

import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
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

    /** La versión de una app instalada (Companion o esta), o null. */
    fun version(context: Context, pkg: String): String? = try {
        val info = context.packageManager.getPackageInfo(pkg, 0)
        @Suppress("DEPRECATION")
        "${info.versionName} (${info.versionCode})"
    } catch (e: Exception) {
        null
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
