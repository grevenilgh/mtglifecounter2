// El iPhone no da el acelerómetro a una web hasta que el usuario lo permite,
// y solo se puede pedir dentro de un toque. En el resto no hace nada.
export 'motion_permission_stub.dart'
    if (dart.library.js_interop) 'motion_permission_web.dart';
