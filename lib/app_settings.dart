import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:mtglifecounter/look.dart';
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
    _theme = AppTheme.fromName(_prefs.getString(_kTheme));
    _modernVariant = ModernVariant.fromName(_prefs.getString(_kModernVariant));
    _backgroundMode = BackgroundMode.fromName(
      _prefs.getString(_kBackgroundMode),
    );
    _imageOpacity = _prefs.getInt(_kImageOpacity) ?? 60;
    _focus = _prefs.getBool(_kFocus);
    _frameOpacity = _prefs.getInt(_kFrameOpacity) ?? 92;
    _animations = _prefs.getBool(_kAnimations) ?? true;
    _showStepper = _prefs.getBool(_kShowStepper) ?? false;
  }

  static const _kSkin = 'skin';
  static const _kCustomSkin = 'customSkin';
  static const _kBackgroundPhoto = 'backgroundPhoto';
  static const _kRememberGame = 'rememberGame';
  static const _kKeepScreenOn = 'keepScreenOn';
  static const _kTheme = 'theme';
  static const _kModernVariant = 'modernVariant';
  static const _kBackgroundMode = 'backgroundMode';
  static const _kImageOpacity = 'imageOpacity';
  static const _kFocus = 'focus';
  static const _kFrameOpacity = 'frameOpacity';
  static const _kAnimations = 'animations';
  static const _kShowStepper = 'showStepper';

  /// Límites de la opacidad de marcos: por debajo el historial no se lee.
  static const int minFrameOpacity = 60;

  final SharedPreferences _prefs;

  late String _skinId;
  Skin _customSkin = Skin.customDefault;
  Uint8List? _backgroundPhoto;
  late bool _rememberGame;
  late bool _keepScreenOn;
  late AppTheme _theme;
  late ModernVariant _modernVariant;
  late BackgroundMode _backgroundMode;
  late int _imageOpacity;
  bool? _focus;
  late int _frameOpacity;
  late bool _animations;
  late bool _showStepper;

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

  AppTheme get theme => _theme;
  ModernVariant get modernVariant => _modernVariant;
  BackgroundMode get backgroundMode => _backgroundMode;

  /// Opacidad de la imagen de fondo, de 0 a 100. Debajo asoma el color del
  /// jugador, así que cuanto más baja mejor se lee el número.
  int get imageOpacity => _imageOpacity;

  /// Opacidad de marcos, barra e historial, de [minFrameOpacity] a 100.
  int get frameOpacity => _frameOpacity;
  bool get animations => _animations;

  /// Si la barra enseña la cantidad por toque (− 1 +). Sin ella cada toque cuenta 1.
  bool get showStepper => _showStepper;

  /// El tema ya resuelto para pintar.
  Look get look => Look.of(_theme, _modernVariant);

  /// «Foco en el número». Mientras no se toque, depende del tema.
  bool get focus => _focus ?? look.focusByDefault;

  set theme(AppTheme value) {
    _theme = value;
    _prefs.setString(_kTheme, value.name);
    _resetFocus();
    notifyListeners();
  }

  set modernVariant(ModernVariant value) {
    _modernVariant = value;
    _prefs.setString(_kModernVariant, value.name);
    _resetFocus();
    notifyListeners();
  }

  set backgroundMode(BackgroundMode value) {
    _backgroundMode = value;
    _prefs.setString(_kBackgroundMode, value.name);
    notifyListeners();
  }

  set imageOpacity(int value) {
    _imageOpacity = value.clamp(0, 100);
    _prefs.setInt(_kImageOpacity, _imageOpacity);
    notifyListeners();
  }

  set focus(bool value) {
    _focus = value;
    _prefs.setBool(_kFocus, value);
    notifyListeners();
  }

  set frameOpacity(int value) {
    _frameOpacity = value.clamp(minFrameOpacity, 100);
    _prefs.setInt(_kFrameOpacity, _frameOpacity);
    notifyListeners();
  }

  set animations(bool value) {
    _animations = value;
    _prefs.setBool(_kAnimations, value);
    notifyListeners();
  }

  set showStepper(bool value) {
    _showStepper = value;
    _prefs.setBool(_kShowStepper, value);
    notifyListeners();
  }

  // Al cambiar de tema, el foco vuelve a lo que trae el tema nuevo.
  void _resetFocus() {
    _focus = null;
    _prefs.remove(_kFocus);
  }
}
