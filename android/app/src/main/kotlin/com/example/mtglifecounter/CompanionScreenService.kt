package com.example.mtglifecounter

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.content.Intent
import android.graphics.Rect
import android.os.Build
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
 * Busca el reloj de la ronda («52:18») en su sitio, preguntando a Companion
 * por sus nombres internos ([TIMER_IDS]), y si ahí no hay, cada 15 s, el
 * único texto con forma de reloj de la pantalla. Si lo ve bajar al ritmo de
 * los segundos, apunta lo que le queda como aviso «screen_clock» para la app
 * ([followClock]), que pone su reloj en hora.
 *
 * TRAZAS PROVISIONALES (quitar cuando se sepa todo lo de Companion; ver
 * CLAUDE.md): guarda cada pantalla de Companion entera (todos los elementos,
 * con y sin texto) en Android/data/<paquete>/files/companion_screen.jsonl, y
 * en companion_debug.jsonl cada ventana que se abre y cada lectura del reloj
 * con lo que se decidió ([CompanionDebug]). Se bajan con `adb pull`.
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

    // Cuándo se recorrió la pantalla entera por última vez.
    private var lastWalk = 0L

    override fun onServiceConnected() {
        CompanionDebug.log(
            this, "screen", "connected",
            JSONObject()
                .put("on", isOn(this))
                .put("companion", CompanionDebug.version(this, CompanionListener.COMPANION) ?: JSONObject.NULL)
                .put("app", CompanionDebug.version(this, packageName) ?: JSONObject.NULL)
                .put("battery", CompanionDebug.battery(this) ?: JSONObject.NULL)
                .put("batteryExempt", CompanionDebug.batteryExempt(this)),
        )
    }

    override fun onUnbind(intent: Intent?): Boolean {
        CompanionDebug.log(this, "screen", "disconnected")
        return super.onUnbind(intent)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        if (event.packageName?.toString() != CompanionListener.COMPANION) return
        if (!isOn(this)) return
        val now = System.currentTimeMillis()
        // Cada ventana de Companion que se abre: cuándo la tenías delante.
        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            CompanionDebug.log(
                this, "screen", "window",
                JSONObject()
                    .put("class", event.className?.toString() ?: JSONObject.NULL)
                    .put("battery", CompanionDebug.battery(this) ?: JSONObject.NULL),
            )
        }
        val root = rootInActiveWindow ?: return
        if (root.packageName?.toString() != CompanionListener.COMPANION) return
        // Batería: pedir cada elemento a Companion es una llamada entre
        // procesos, y recorrer sus 200–300 elementos con cada cambio (el
        // reloj cambia cada segundo) gastaba un 5 % de un núcleo en un Pixel
        // 9a. El reloj se lee preguntando solo por sus nombres internos; la
        // pantalla entera, al cambiar de ventana y como mucho cada [WALK_MS].
        val timerTexts = timerTexts(root)
        val fromTimer = timerTexts.any { CLOCK.matches(it) }
        if (fromTimer) followClock(timerTexts, "timer-id", now)
        val windowChanged = event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED
        if (!windowChanged && now - lastWalk < WALK_MS) return
        lastWalk = now
        val nodes = JSONArray()
        collect(root, nodes, 0)
        if (nodes.length() == 0) return
        // Sin nada en el sitio del reloj: el único texto con forma de reloj
        // de toda la pantalla (cada [WALK_MS] basta: se comprueba que baja
        // lo mismo que el tiempo que pasa).
        if (!fromTimer) {
            followClock(
                (0 until nodes.length()).map { nodes.getJSONObject(it).optString("text") },
                "only-clock",
                now,
            )
        }
        // La misma pantalla con otros números (el reloj): como mucho una vez
        // cada 15 s. Una pantalla distinta, al momento.
        val shape = nodes.toString().replace(Regex("\\d"), "0")
        if (shape == lastShape && now - lastSaved < SAME_SCREEN_MS) return
        lastShape = shape
        lastSaved = now
        CompanionDebug.append(
            this,
            "companion_screen.jsonl",
            JSONObject()
                .put("at", now)
                .put("type", AccessibilityEvent.eventTypeToString(event.eventType))
                .put("class", event.className?.toString() ?: JSONObject.NULL)
                .put("nodes", nodes),
        )
    }

    // El reloj de la ronda de Companion: el único texto de la pantalla con
    // forma de reloj («52:18»). Solo se le pasa a la app si se le ha visto
    // bajar al ritmo de los segundos (está en marcha): parado, en pausa o
    // con otra cosa que lo parezca, no se toca el reloj. Cada lectura se
    // apunta con lo que se decidió.
    private var seenLeft = -1L
    private var seenAt = 0L
    private var sentLeft = -1L
    private var sentAt = 0L
    private var lastDecision: String? = null

    // Los textos del reloj ([TIMER_TEXT_IDS]: «timerTimeLeft» de la pantalla
    // de la partida del jugador, que en un torneo de tienda (EventLink) lleva
    // «52:18» y en uno montado desde la app va vacío, y «countDownTimer» del
    // organizador). Una llamada a Companion por nombre, no una por elemento
    // de la pantalla.
    private fun timerTexts(root: AccessibilityNodeInfo): List<String> =
        TIMER_TEXT_IDS.flatMap { id ->
            root.findAccessibilityNodeInfosByViewId("${CompanionListener.COMPANION}:id/$id")
                .mapNotNull { it.text?.toString()?.takeIf(String::isNotBlank) }
        }.distinct()

    // [source]: «timer-id» si [texts] son los del sitio del reloj y
    // «only-clock» si son los de toda la pantalla.
    private fun followClock(texts: List<String>, source: String, now: Long) {
        val clocks = texts.mapNotNull { CLOCK.matchEntire(it) }
        // Algo con pinta de reloj pero que no encaja («-01:23», «1:02:03»…),
        // por si Companion lo enseña así al acabarse o pasarse.
        val near = texts.filter { it.contains(':') && it.any(Char::isDigit) && it.length <= 10 }
        val trace = JSONObject()
            .put("clocks", JSONArray(clocks.map { it.value }))
            .put("near", JSONArray(near))
            .put("source", source)
        // Solo cuando cambia lo que ve o lo que decide (si no, con cada
        // cambio de la pantalla se repetiría lo mismo).
        fun decide(decision: String) {
            val key = "$decision|${trace.optJSONArray("clocks")}|${trace.optJSONArray("near")}"
            if (decision != "sent" && key == lastDecision) return
            lastDecision = key
            CompanionDebug.log(this, "screen", "clock", trace.put("decision", decision))
        }
        if (clocks.size != 1) {
            if (near.isNotEmpty()) decide(if (clocks.isEmpty()) "no-clock" else "several")
            return
        }
        val (m, s) = clocks[0].destructured
        val left = (m.toLong() * 60 + s.toLong()) * 1000
        val prevLeft = seenLeft
        val prevAt = seenAt
        seenLeft = left
        seenAt = now
        trace.put("left", left).put("prevLeft", prevLeft).put("passed", now - prevAt)
        if (prevLeft < 0) return decide("first-read")
        if (left <= 0) return decide("zero")
        if (left == prevLeft) return decide("still")
        if (left > prevLeft) return decide("going-up")
        // Ha bajado lo mismo que ha pasado (con un par de segundos de margen).
        val drop = prevLeft - left
        val passed = now - prevAt
        if (passed > 30_000) return decide("stale")
        if (kotlin.math.abs(drop - passed) > 2_000) return decide("jump")
        // Ya enviado y sigue cuadrando: no se repite más que cada minuto.
        val expected = sentLeft - (now - sentAt)
        if (sentLeft >= 0 && now - sentAt < 60_000 &&
            kotlin.math.abs(expected - left) < 3_000
        ) return decide("in-sync")
        sentLeft = left
        sentAt = now
        decide("sent")
        CompanionListener.record(this, "screen_clock", now, left)
        sendBroadcast(Intent(CompanionListener.ACTION_CHANGED).setPackage(packageName))
    }

    // Todos los elementos de la pantalla: con texto o descripción, y también
    // los que solo tienen nombre interno (el puntito del reloj, iconos…), con
    // su tipo, posición y estado.
    // [inTimer]: el elemento está en el sitio del reloj (él o uno de los de
    // fuera tiene un nombre de [TIMER_IDS]).
    private fun collect(
        node: AccessibilityNodeInfo,
        out: JSONArray,
        depth: Int,
        parentInTimer: Boolean = false,
    ) {
        if (depth > 40) return
        val text = node.text?.toString()
        val desc = node.contentDescription?.toString()
        val id = node.viewIdResourceName
        val inTimer = parentInTimer || id?.substringAfter(":id/") in TIMER_IDS
        if (!text.isNullOrBlank() || !desc.isNullOrBlank() || id != null) {
            val b = Rect().also { node.getBoundsInScreen(it) }
            val o = JSONObject()
                .put("id", id?.substringAfter(":id/") ?: JSONObject.NULL)
                .put("text", text ?: JSONObject.NULL)
                .put("desc", desc ?: JSONObject.NULL)
                .put("class", node.className?.toString()?.substringAfterLast('.') ?: JSONObject.NULL)
                .put("box", JSONArray(listOf(b.left, b.top, b.right, b.bottom)))
                .put("depth", depth)
            if (node.isSelected) o.put("selected", true)
            if (node.isChecked) o.put("checked", true)
            if (!node.isEnabled) o.put("enabled", false)
            if (node.isClickable) o.put("clickable", true)
            if (!node.isVisibleToUser) o.put("visible", false)
            if (inTimer) o.put("inTimer", true)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                node.hintText?.let { o.put("hint", it.toString()) }
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                node.tooltipText?.let { o.put("tooltip", it.toString()) }
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                node.stateDescription?.let { o.put("state", it.toString()) }
            }
            out.put(o)
        }
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            collect(child, out, depth + 1, inTimer)
        }
    }

    override fun onInterrupt() {}

    companion object {
        private const val SAME_SCREEN_MS = 15_000L
        private const val WALK_MS = 15_000L
        private val CLOCK = Regex("""^\s*(\d{1,3}):(\d{2})\s*$""")

        // Los nombres internos del sitio del reloj de la ronda, vistos en un
        // torneo de prueba con emuladores (2026-11-22): «timer» y «timerRow»
        // en la pantalla de la partida del jugador y «countDownTimer» en la
        // del organizador (solo sirve para probar con un torneo montado desde
        // Companion: en los de tienda organiza la tienda desde EventLink);
        // «timerTimeLeft», el texto del reloj, también visto
        // (vacío) en esos torneos montados desde la app. En uno de tienda
        // debería llevar el tiempo: sin confirmar aún (si sale con otro
        // nombre, lo dirán las trazas de companion_screen.jsonl).
        private val TIMER_IDS = setOf("timer", "timerRow", "countDownTimer", "timerTimeLeft")

        // De esos, los que llevan el texto del reloj (en un Pixel 9a, el
        // 2026-11-26, «countDownTimer» de un torneo montado desde Companion).
        private val TIMER_TEXT_IDS = listOf("timerTimeLeft", "countDownTimer")

        // Existe si está activado en Ajustes (lo pone MainActivity).
        private const val ON = "companion_screen_on"

        fun isOn(context: Context) = File(context.filesDir, ON).exists()

        fun setOn(context: Context, on: Boolean) {
            val file = File(context.filesDir, ON)
            if (on) file.createNewFile() else file.delete()
        }
    }
}
