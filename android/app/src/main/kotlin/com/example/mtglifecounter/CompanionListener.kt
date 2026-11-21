package com.example.mtglifecounter

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

/**
 * «Eventos de Companion» (beta): lee las notificaciones de la app Companion
 * de Wizards para saber cuándo empieza y acaba cada ronda. Las de las demás
 * apps ni se miran.
 *
 * Companion no dice el tiempo que queda ni la mesa ni el rival: solo avisa
 * «Evento empezado», «Ronda iniciada» y «Ronda completada», con la hora. Cada
 * aviso de esos se apunta en [EVENTS] (en la carpeta de la app, que el
 * proceso de la app lee) y se avisa a la app con [ACTION_CHANGED], por si
 * está abierta. La app (lib/companion.dart) decide qué hacer con el reloj.
 *
 * Va en su propio proceso (`:companion` en el manifiesto): en el de la app la
 * dejaba en negro al volver a ella. Está desactivado en el manifiesto y la app
 * lo enciende con el interruptor de Ajustes (MainActivity, canal
 * mtglifecounter/companion).
 *
 * Mientras esté en pruebas, apunta además cada notificación de Companion
 * entera en Android/data/<paquete>/files/companion_log.jsonl, para ver con
 * `adb pull` qué manda en un torneo de verdad.
 */
class CompanionListener : NotificationListenerService() {

    // Si Android lo conecta y lo desconecta (y cuándo): si se desconecta en
    // un torneo, los avisos de ese rato no llegan.
    override fun onListenerConnected() {
        CompanionDebug.log(
            this, "notif", "connected",
            JSONObject()
                .put("on", isOn(this))
                .put("companion", CompanionDebug.version(this, COMPANION) ?: JSONObject.NULL)
                .put("app", CompanionDebug.version(this, packageName) ?: JSONObject.NULL)
                .put("battery", CompanionDebug.battery(this) ?: JSONObject.NULL),
        )
    }

    override fun onListenerDisconnected() {
        CompanionDebug.log(this, "notif", "disconnected")
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        // Para probar sin torneo: los avisos que se mandan desde el PC con
        // `adb shell cmd notification post -t "Ronda iniciada" companion x`
        // salen de la shell, que solo usa adb, y valen como de Companion.
        val test = sbn.packageName == ADB_SHELL && sbn.tag == "companion"
        if (sbn.packageName != COMPANION && !test) return
        val title = sbn.notification.extras
            ?.getCharSequence("android.title")?.toString()
        val trace = JSONObject()
            .put("title", title ?: JSONObject.NULL)
            .put("postTime", sbn.postTime)
            .put("test", test)
            .put("battery", CompanionDebug.battery(this) ?: JSONObject.NULL)
        // Sin activar en Ajustes no se mira nada (pero se apunta que llegó).
        if (!isOn(this)) {
            CompanionDebug.log(this, "notif", "ignored-off", trace)
            return
        }
        logRaw(describe("posted", sbn))
        val kind = title?.let { kindOf(it) }
        CompanionDebug.log(this, "notif", "posted", trace.put("kind", kind ?: JSONObject.NULL))
        if (kind == null) return
        record(this, kind, sbn.postTime)
        sendBroadcast(Intent(ACTION_CHANGED).setPackage(packageName))
    }

    override fun onNotificationRemoved(
        sbn: StatusBarNotification,
        rankingMap: RankingMap,
        reason: Int,
    ) {
        if (sbn.packageName == COMPANION && isOn(this)) {
            logRaw(describe("removed", sbn).put("reason", reason))
        }
    }

    // ---- Registro completo, para analizar (solo mientras esté en beta) ----

    private fun describe(event: String, sbn: StatusBarNotification): JSONObject {
        val n = sbn.notification
        val actions = JSONArray()
        n.actions?.forEach { actions.put(it.title?.toString()) }
        return JSONObject()
            .put("event", event)
            .put("id", sbn.id)
            .put("tag", sbn.tag ?: JSONObject.NULL)
            .put("postTime", sbn.postTime)
            .put("channel", n.channelId ?: JSONObject.NULL)
            .put("extras", extrasToJson(n.extras))
            .put("actions", actions)
    }

    private fun extrasToJson(extras: Bundle?): JSONObject {
        val o = JSONObject()
        if (extras == null) return o
        for (k in extras.keySet()) {
            @Suppress("DEPRECATION")
            val v = try { extras.get(k) } catch (e: Exception) { e.toString() }
            o.put(k, when (v) {
                null -> JSONObject.NULL
                is CharSequence -> v.toString()
                is Boolean, is Int, is Long, is Double, is Float -> v
                is Array<*> -> JSONArray(v.map { it?.toString() })
                is Bundle -> extrasToJson(v)
                else -> "<${v.javaClass.simpleName}>"
            })
        }
        return o
    }

    private fun logRaw(o: JSONObject) {
        o.put("at", System.currentTimeMillis())
        CompanionDebug.append(this, "companion_log.jsonl", o)
    }

    companion object {
        /** El paquete de Companion (MTG Companion de Wizards). */
        const val COMPANION = "com.wizards.winter_orb"

        /** De donde salen los avisos de prueba mandados con adb. */
        private const val ADB_SHELL = "com.android.shell"

        /** Llega a la app cuando se apunta un aviso nuevo. */
        const val ACTION_CHANGED = "mtg.premodern.alicante.lifecounter.COMPANION_CHANGED"

        /** Los avisos de ronda, uno por línea: {"kind":…,"at":…}. */
        const val EVENTS = "companion_events.jsonl"

        /** Lo de hace más de un día se borra al apuntar uno nuevo. */
        private const val KEEP_MS = 24L * 60 * 60 * 1000

        // Los títulos llegan en el idioma del móvil. Los de español son los
        // vistos en un torneo; los de inglés, los esperables (sin ver aún).
        private val KINDS = listOf(
            "round_started" to listOf("ronda iniciada", "round started", "round has started"),
            "round_completed" to listOf("ronda completada", "round completed", "round complete", "round ended"),
            "event_started" to listOf("evento empezado", "event started", "event has started"),
        )

        // Existe si está activado en Ajustes (lo pone MainActivity).
        private const val ON = "companion_on"

        fun isOn(context: Context) = File(context.filesDir, ON).exists()

        fun setOn(context: Context, on: Boolean) {
            val file = File(context.filesDir, ON)
            if (on) file.createNewFile() else file.delete()
        }

        /** Qué aviso es por su título, o null si no es de ronda ni de evento. */
        fun kindOf(title: String): String? {
            val t = title.lowercase().trim()
            return KINDS.firstOrNull { (_, words) -> words.any { t.contains(it) } }?.first
        }

        /**
         * Apunta un aviso. [left] es lo que le quedaba al reloj de Companion
         * (en los que salen de leer su pantalla, «screen_clock»).
         */
        @Synchronized
        fun record(context: Context, kind: String, at: Long, left: Long? = null) {
            val file = File(context.filesDir, EVENTS)
            val limit = System.currentTimeMillis() - KEEP_MS
            val kept = read(context).filter { it.getLong("at") >= limit }
            val line = JSONObject().put("kind", kind).put("at", at)
            if (left != null) line.put("left", left)
            file.writeText((kept + line).joinToString("") { it.toString() + "\n" })
        }

        fun read(context: Context): List<JSONObject> {
            val file = File(context.filesDir, EVENTS)
            if (!file.exists()) return emptyList()
            return file.readLines().mapNotNull {
                try { JSONObject(it) } catch (e: Exception) { null }
            }
        }
    }
}
