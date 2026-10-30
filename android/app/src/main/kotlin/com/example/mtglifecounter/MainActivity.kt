package com.example.mtglifecounter

import android.content.ComponentName
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

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
    }

    // El icono se cambia al salir de la app: con ella abierta, algunos móviles
    // la cierran al desactivar la entrada del lanzador que la abrió.
    override fun onStop() {
        super.onStop()
        pendingIcon?.let { applyIcon(it) }
        pendingIcon = null
    }

    private fun applyIcon(icon: String) {
        val wanted = ALIASES[icon] ?: return
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
            "mesa" to "AliasMesa",
        )
    }
}
