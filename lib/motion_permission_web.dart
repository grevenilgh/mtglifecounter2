import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Pide a Safari en el iPhone permiso para el acelerómetro (los gestos de los
/// sorteos). Hay que llamarla dentro de un toque, o Safari no pregunta. Los
/// demás navegadores no tienen `DeviceMotionEvent.requestPermission`.
void requestMotionPermission() {
  final event = globalContext['DeviceMotionEvent'];
  if (event == null || event.isUndefinedOrNull) return;
  final motion = event as JSObject;
  if (!motion.has('requestPermission')) return;
  try {
    // Devuelve una promesa: si dice que no, solo quedan los botones.
    motion.callMethod<JSAny?>('requestPermission'.toJS);
  } catch (_) {}
}
