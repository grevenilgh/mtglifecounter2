import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:mtglifecounter/skin.dart';

const _channel = MethodChannel('mtglifecounter/app_icon');

/// El icono y el nombre de la app en el lanzador para cada skin. Las claves
/// son las de `MainActivity.kt`.
String appIconFor(String skinId) {
  if (skinId == Skin.fullTapped.id) return 'fulltapped';
  if (skinId == Skin.oldSchool.id) return 'oldschool';
  if (skinId == Skin.customDefault.id) return 'mesa';
  return 'alicante';
}

/// Pide a Android que cambie el icono de la app. Se aplica al salir de ella.
Future<void> setAppIcon(String skinId) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  try {
    await _channel.invokeMethod<void>('set', appIconFor(skinId));
  } on MissingPluginException {
    // En los tests no hay parte nativa.
  } on PlatformException {
    // Si falla, se queda el icono que había.
  }
}
