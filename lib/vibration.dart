import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const MethodChannel _channel = MethodChannel('mtglifecounter/vibrate');

/// Vibra [duration]. En Android usa el motor de vibración (`MainActivity.kt`,
/// canal `mtglifecounter/vibrate`): la vibración de Flutter
/// ([HapticFeedback]) no se nota si en el móvil está apagada la vibración al
/// tocar. En el resto, o si falla, se queda en [HapticFeedback].
Future<void> vibrate(Duration duration) async {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    try {
      await _channel.invokeMethod<void>('vibrate', duration.inMilliseconds);
      return;
    } on PlatformException {
      // Sigue con la de Flutter.
    } on MissingPluginException {
      // En los tests no hay canal.
    }
  }
  await HapticFeedback.vibrate();
}
