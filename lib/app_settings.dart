import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:mtglifecounter/skin.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Preferencias de la app. Se guardan en cuanto cambian.
class AppSettings extends ChangeNotifier {
  AppSettings(this._prefs) {
    _skinId = _prefs.getString(_kSkin) ?? Skin.alicante.id;
    final custom = _prefs.getString(_kCustomSkin);
    if (custom != null) {
      try {
        _customSkin = Skin.customFromJson(
          jsonDecode(custom) as Map<String, dynamic>,
        );
      } on FormatException {
        // Si lo guardado no se puede leer, se queda la personalizada por defecto.
      }
    }
    final photo = _prefs.getString(_kBackgroundPhoto);
    if (photo != null) {
      try {
        _backgroundPhoto = base64Decode(photo);
      } on FormatException {
        _prefs.remove(_kBackgroundPhoto);
      }
    }
    _rememberGame = _prefs.getBool(_kRememberGame) ?? true;
    _keepScreenOn = _prefs.getBool(_kKeepScreenOn) ?? true;
  }

  static const _kSkin = 'skin';
  static const _kCustomSkin = 'customSkin';
  static const _kBackgroundPhoto = 'backgroundPhoto';
  static const _kRememberGame = 'rememberGame';
  static const _kKeepScreenOn = 'keepScreenOn';

  final SharedPreferences _prefs;

  late String _skinId;
  Skin _customSkin = Skin.customDefault;
  Uint8List? _backgroundPhoto;
  late bool _rememberGame;
  late bool _keepScreenOn;

  /// La skin en uso.
  Skin get skin => switch (_skinId) {
    'fulltapped' => Skin.fullTapped,
    'custom' => _customSkin,
    _ => Skin.alicante,
  };

  String get skinId => _skinId;
  Skin get customSkin => _customSkin;
  bool get rememberGame => _rememberGame;
  bool get keepScreenOn => _keepScreenOn;

  set skinId(String id) {
    _skinId = id;
    _prefs.setString(_kSkin, id);
    notifyListeners();
  }

  set customSkin(Skin skin) {
    _customSkin = skin;
    _prefs.setString(_kCustomSkin, jsonEncode(skin.toJson()));
    notifyListeners();
  }

  /// La foto de fondo elegida por el usuario, si hay una.
  Uint8List? get backgroundPhoto => _backgroundPhoto;

  /// Guarda la foto de fondo y la pone en la skin personalizada.
  ///
  /// Va en las preferencias como base64, así que la foto tiene que llegar ya
  /// reducida (el selector la pide a 1440 px como mucho).
  set backgroundPhoto(Uint8List? bytes) {
    _backgroundPhoto = bytes;
    if (bytes == null) {
      _prefs.remove(_kBackgroundPhoto);
    } else {
      _prefs.setString(_kBackgroundPhoto, base64Encode(bytes));
    }
    customSkin = _customSkin.copyWith(
      background: bytes == null ? SkinBackground.none : SkinBackground.photo,
    );
  }

  /// La imagen de fondo de la skin en uso, o `null` si no lleva.
  ImageProvider? backgroundOf(Skin skin) {
    if (skin.background == SkinBackground.photo) {
      final photo = _backgroundPhoto;
      return photo == null ? null : MemoryImage(photo);
    }
    final asset = skin.background.asset;
    return asset == null ? null : AssetImage(asset);
  }

  set rememberGame(bool value) {
    _rememberGame = value;
    _prefs.setBool(_kRememberGame, value);
    notifyListeners();
  }

  set keepScreenOn(bool value) {
    _keepScreenOn = value;
    _prefs.setBool(_kKeepScreenOn, value);
    applyWakelock();
    notifyListeners();
  }

  /// Aplica "mantener la pantalla encendida" según el ajuste guardado.
  void applyWakelock() => WakelockPlus.toggle(enable: _keepScreenOn);
}
