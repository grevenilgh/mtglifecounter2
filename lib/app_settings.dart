import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:mtglifecounter/look.dart';
import 'package:mtglifecounter/round_timer.dart';
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
      } on Object {
        // Si lo guardado no se puede leer (o no es lo que se espera), se
        // queda la personalizada por defecto.
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
    _loadLook();
    _showTimer = _prefs.getBool(_kShowTimer) ?? true;
    _timerMode = TimerMode.fromName(_prefs.getString(_kTimerMode));
    _roundMinutes = _prefs.getInt(_kRoundMinutes) ?? 50;
    _timerWarning = _prefs.getBool(_kTimerWarning) ?? true;
    _timerVibrate = _prefs.getBool(_kTimerVibrate) ?? true;
    // Quien ya tenía el reloj de ajedrez por defecto lo tiene activado.
    _chessEnabled =
        _prefs.getBool(_kChessEnabled) ?? _timerMode == TimerMode.chess;
    _showStepper = _prefs.getBool(_kShowStepper) ?? false;
    _showHistory = _prefs.getBool(_kShowHistory) ?? true;
    _welcomeDone = _prefs.getBool(_kWelcomeDone) ?? false;
  }

  // Lo que vuelve a lo de por defecto con [resetLook].
  static const _lookKeys = [
    _kBackgroundMode,
    _kImageOpacity,
    _kFocus,
    _kFrameOpacity,
    _kBarOpacity,
    _kHistoryOpacity,
    _kZoneMarks,
    _kAnimations,
  ];

  void _loadLook() {
    _backgroundMode = BackgroundMode.fromName(
      _prefs.getString(_kBackgroundMode),
    );
    _imageOpacity = _prefs.getInt(_kImageOpacity) ?? 60;
    _focus = _prefs.getBool(_kFocus);
    _frameOpacity = _prefs.getInt(_kFrameOpacity) ?? 92;
    _barOpacity = _prefs.getInt(_kBarOpacity);
    _historyOpacity = _prefs.getInt(_kHistoryOpacity);
    _zoneMarks = ZoneMarks.fromName(_prefs.getString(_kZoneMarks));
    _animations = _prefs.getBool(_kAnimations) ?? true;
  }

  /// Vuelve el aspecto a lo de por defecto de cada tema: la imagen de fondo
  /// (para toda la pantalla y su opacidad), el foco, las mitades, las
  /// transparencias de la barra, el historial y el marco, y las animaciones.
  /// No toca el tema, la skin, sus colores ni su foto, ni nada de la partida.
  Future<void> resetLook() async {
    await Future.wait([for (final key in _lookKeys) _prefs.remove(key)]);
    _loadLook();
    notifyListeners();
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
  static const _kBarOpacity = 'barOpacity';
  static const _kHistoryOpacity = 'historyOpacity';
  static const _kZoneMarks = 'zoneMarks';
  static const _kShowTimer = 'showTimer';
  static const _kTimerMode = 'timerMode';
  static const _kRoundMinutes = 'roundMinutes';
  static const _kTimerWarning = 'timerWarning';
  static const _kTimerVibrate = 'timerVibrate';
  static const _kChessEnabled = 'chessEnabled';

  /// Límites de la duración de la ronda, en minutos.
  static const int minRoundMinutes = 5;
  static const int maxRoundMinutes = 120;
  static const _kAnimations = 'animations';
  static const _kShowStepper = 'showStepper';
  static const _kShowHistory = 'showHistory';
  static const _kWelcomeDone = 'welcomeDone';

  /// Mínimos de las opacidades: por debajo el marco se pierde y los botones
  /// de la barra se dejan de ver sobre la imagen.
  static const int minFrameOpacity = 60;
  static const int minBarOpacity = 30;

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
  int? _barOpacity;
  int? _historyOpacity;
  late ZoneMarks _zoneMarks;
  late bool _showTimer;
  late TimerMode _timerMode;
  late int _roundMinutes;
  late bool _timerWarning;
  late bool _timerVibrate;
  late bool _chessEnabled;
  late bool _animations;
  late bool _showStepper;
  late bool _showHistory;
  late bool _welcomeDone;

  /// La skin en uso.
  Skin get skin => switch (_skinId) {
    'fulltapped' => Skin.fullTapped,
    'oldschool' => Skin.oldSchool,
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
    final background = skin.background;
    final asset = _backgroundMode == BackgroundMode.screen
        ? background.screenAsset ?? background.asset
        : background.asset;
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

  /// Aplica "mantener la pantalla encendida" según el ajuste guardado. En el
  /// navegador puede negarse (Safari solo lo deja después de un toque): no
  /// es un error, se vuelve a pedir al tocar ([MyHomePage]).
  Future<void> applyWakelock() =>
      WakelockPlus.toggle(enable: _keepScreenOn).catchError((Object _) {});

  AppTheme get theme => _theme;
  ModernVariant get modernVariant => _modernVariant;
  BackgroundMode get backgroundMode => _backgroundMode;

  /// Opacidad de la imagen de fondo, de 0 a 100. Debajo asoma el color del
  /// jugador, así que cuanto más baja mejor se lee el número.
  int get imageOpacity => _imageOpacity;

  /// Opacidad del marco del borde antiguo, de [minFrameOpacity] a 100.
  int get frameOpacity => _frameOpacity;

  /// Opacidad de la barra central, de [minBarOpacity] a 100. Mientras no se
  /// toque, la de cada tema.
  int get barOpacity => _barOpacity ?? look.defaultBarOpacity;

  /// Opacidad del fondo del historial, de 0 a 100. Mientras no se toque, la
  /// de cada tema.
  int get historyOpacity => _historyOpacity ?? look.defaultHistoryOpacity;
  bool get animations => _animations;

  /// Si la barra enseña la cantidad por toque (− 1 +). Sin ella cada toque cuenta 1.
  bool get showStepper => _showStepper;

  /// Si los paneles enseñan el historial. Oculto se sigue apuntando, así que
  /// al volver a enseñarlo sale entero.
  bool get showHistory => _showHistory;

  /// Si ya se vio la bienvenida de la primera vez ([WelcomePage]). Se guarda
  /// en el móvil: no vuelve a salir al abrir la app ni al actualizarla.
  bool get welcomeDone => _welcomeDone;

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

  /// Cómo se distingue la mitad que suma de la que resta.
  ZoneMarks get zoneMarks => _zoneMarks;

  set zoneMarks(ZoneMarks value) {
    _zoneMarks = value;
    _prefs.setString(_kZoneMarks, value.name);
    notifyListeners();
  }

  /// Si la barra enseña el temporizador de ronda. Con el reloj de ajedrez
  /// siempre: en él se pone el tiempo y se pausa.
  bool get showTimer => _showTimer || chessClock;
  TimerMode get timerMode => _timerMode;

  /// Si el reloj empieza por defecto como reloj de ajedrez.
  bool get chessClock => _timerMode == TimerMode.chess;

  /// Si se puede usar el reloj de ajedrez (desactivado si no se toca): sin
  /// esto no sale «Ajedrez» ni en Ajustes ni en el reloj de la barra.
  bool get chessEnabled => _chessEnabled;

  /// Al quitarlo, si el reloj empezaba en ajedrez vuelve a la cuenta atrás.
  set chessEnabled(bool value) {
    _chessEnabled = value;
    _prefs.setBool(_kChessEnabled, value);
    if (!value && _timerMode == TimerMode.chess) {
      _timerMode = TimerMode.countdown;
      _prefs.setString(_kTimerMode, _timerMode.name);
    }
    notifyListeners();
  }

  /// Duración de la ronda en la cuenta atrás (50 minutos si no se toca). En
  /// el reloj de ajedrez, la mitad para cada uno.
  int get roundMinutes => _roundMinutes;

  /// Avisar a falta de 5 minutos (en el reloj de ajedrez, de 2 a cada uno).
  bool get timerWarning => _timerWarning;

  /// Vibrar al acabar el tiempo (y, en el reloj de ajedrez, al pulsar).
  bool get timerVibrate => _timerVibrate;

  set showTimer(bool value) {
    _showTimer = value;
    _prefs.setBool(_kShowTimer, value);
    notifyListeners();
  }

  set timerMode(TimerMode value) {
    _timerMode = value;
    _prefs.setString(_kTimerMode, value.name);
    notifyListeners();
  }

  set roundMinutes(int value) {
    _roundMinutes = value.clamp(minRoundMinutes, maxRoundMinutes);
    _prefs.setInt(_kRoundMinutes, _roundMinutes);
    notifyListeners();
  }

  set timerWarning(bool value) {
    _timerWarning = value;
    _prefs.setBool(_kTimerWarning, value);
    notifyListeners();
  }

  set timerVibrate(bool value) {
    _timerVibrate = value;
    _prefs.setBool(_kTimerVibrate, value);
    notifyListeners();
  }

  set barOpacity(int value) {
    _barOpacity = value.clamp(minBarOpacity, 100);
    _prefs.setInt(_kBarOpacity, _barOpacity!);
    notifyListeners();
  }

  set historyOpacity(int value) {
    _historyOpacity = value.clamp(0, 100);
    _prefs.setInt(_kHistoryOpacity, _historyOpacity!);
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

  set showHistory(bool value) {
    _showHistory = value;
    _prefs.setBool(_kShowHistory, value);
    notifyListeners();
  }

  set welcomeDone(bool value) {
    _welcomeDone = value;
    _prefs.setBool(_kWelcomeDone, value);
  }

  // Al cambiar de tema, el foco vuelve a lo que trae el tema nuevo.
  void _resetFocus() {
    _focus = null;
    _prefs.remove(_kFocus);
  }
}
