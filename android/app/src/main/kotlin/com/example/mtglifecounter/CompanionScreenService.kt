package com.example.mtglifecounter

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.content.Intent
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

/**
 * «Leer la pantalla de Companion» (beta): un servicio de accesibilidad que
 * lee lo que se ve en la app Companion de Wizards. Android solo le pasa lo de
 * Companion (packageNames en res/xml/companion_screen.xml): las demás apps ni
 * le llegan. No toca nada en la pantalla.
 *
 * Busca el reloj de la ronda (el único texto con forma de reloj, «52:18») y,
 * si lo ve bajar al ritmo de los segundos, apunta lo que le queda como aviso
 * «screen_clock» para la app ([followClock]), que pone su reloj en hora.
 *
 * Mientras esté en beta guarda además cada pantalla (los textos con sus
 * nombres internos: ronda, mesa, jugadores…) en
 * Android/data/<paquete>/files/companion_screen.jsonl, para verla con
 * `adb pull` tras un torneo.
 *
 * Como el de las notificaciones, va en el proceso `:companion` y no hace nada
 * mientras no esté activado en Ajustes (archivo [ON]); el componente no se
 * desactiva, porque Android le quitaría el permiso.
 */
class CompanionScreenService : AccessibilityService() {

    // La última pantalla guardada (sin los números, que cambian cada
    // segundo con el reloj) y cuándo: para no guardar la misma una y otra vez.
    private var lastShape: String? = null
    private var lastSaved = 0L

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        if (event.packageName?.toString() != CompanionListener.COMPANION) return
        if (!isOn(this)) return
        val now = System.currentTimeMillis()
        val root = rootInActiveWindow ?: return
        if (root.packageName?.toString() != CompanionListener.COMPANION) return
        val nodes = JSONArray()
        collect(root, nodes, 0)
        if (nodes.length() == 0) return
        followClock(nodes, now)
        // La misma pantalla con otros números (el reloj): como mucho una vez
        // cada 15 s. Una pantalla distinta, al momento.
        val shape = nodes.toString().replace(Regex("\\d"), "0")
        if (shape == lastShape && now - lastSaved < SAME_SCREEN_MS) return
        lastShape = shape
        lastSaved = now
        save(
            JSONObject()
                .put("at", now)
                .put("activity", event.className?.toString() ?: JSONObject.NULL)
                .put("nodes", nodes),
        )
    }

    // El reloj de la ronda de Companion: el único texto de la pantalla con
    // forma de reloj («52:18»). Solo se le pasa a la app si se le ha visto
    // bajar al ritmo de los segundos (está en marcha): parado, en pausa o
    // con otra cosa que lo parezca, no se toca el reloj.
    private var seenLeft = -1L
    private var seenAt = 0L
    private var sentLeft = -1L
    private var sentAt = 0L

    private fun followClock(nodes: JSONArray, now: Long) {
        val clocks = (0 until nodes.length())
            .mapNotNull { CLOCK.matchEntire(nodes.getJSONObject(it).optString("text")) }
        if (clocks.size != 1) return
        val (m, s) = clocks[0].destructured
        val left = (m.toLong() * 60 + s.toLong()) * 1000
        val prevLeft = seenLeft
        val prevAt = seenAt
        seenLeft = left
        seenAt = now
        if (prevLeft < 0 || left <= 0 || left >= prevLeft) return
        // Ha bajado lo mismo que ha pasado (con un par de segundos de margen).
        val drop = prevLeft - left
        val passed = now - prevAt
        if (passed > 30_000 || kotlin.math.abs(drop - passed) > 2_000) return
        // Ya enviado y sigue cuadrando: no se repite más que cada minuto.
        val expected = sentLeft - (now - sentAt)
        if (sentLeft >= 0 && now - sentAt < 60_000 &&
            kotlin.math.abs(expected - left) < 3_000
        ) return
        sentLeft = left
        sentAt = now
        CompanionListener.record(this, "screen_clock", now, left)
        sendBroadcast(Intent(CompanionListener.ACTION_CHANGED).setPackage(packageName))
    }

    // Los textos de la pantalla, con su nombre interno y su posición.
    private fun collect(node: AccessibilityNodeInfo, out: JSONArray, depth: Int) {
        if (depth > 40) return
        val text = node.text?.toString()
        val desc = node.contentDescription?.toString()
        val id = node.viewIdResourceName
        if (!text.isNullOrBlank() || !desc.isNullOrBlank()) {
            val bounds = android.graphics.Rect().also { node.getBoundsInScreen(it) }
            out.put(
                JSONObject()
                    .put("id", id?.substringAfter(":id/") ?: JSONObject.NULL)
                    .put("text", text ?: JSONObject.NULL)
                    .put("desc", desc ?: JSONObject.NULL)
                    .put("y", bounds.top),
            )
        }
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            collect(child, out, depth + 1)
        }
    }

    private fun save(o: JSONObject) {
        try {
            val dir = getExternalFilesDir(null) ?: filesDir
            val file = File(dir, "companion_screen.jsonl")
            // Que no crezca sin fin: pasado el tope se empieza de nuevo.
            if (file.length() > MAX_BYTES) file.delete()
            file.appendText(o.toString() + "\n")
        } catch (e: Exception) {
            Log.w("CompanionScreen", "no se pudo guardar: $e")
        }
    }

    override fun onInterrupt() {}

    companion object {
        private const val SAME_SCREEN_MS = 15_000L
        private val CLOCK = Regex("""^\s*(\d{1,3}):(\d{2})\s*$""")
        private const val MAX_BYTES = 5L * 1024 * 1024

        // Existe si está activado en Ajustes (lo pone MainActivity).
        private const val ON = "companion_screen_on"

        fun isOn(context: Context) = File(context.filesDir, ON).exists()

        fun setOn(context: Context, on: Boolean) {
            val file = File(context.filesDir, ON)
            if (on) file.createNewFile() else file.delete()
        }
    }
}
