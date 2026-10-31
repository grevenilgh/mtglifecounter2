import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const int kInitialLife = 20;
const int kMinLife = -999;
const int kMaxLife = 999;

/// Vida e historial de un jugador.
///
/// Los toques seguidos se agrupan: [change] mueve [life] y [commit] escribe
/// **una** entrada `+N = vida` con todo lo acumulado desde la anterior.
/// [committedLife] es la vida de la última entrada del historial, así que
/// [pending] es el cambio que aún no se ha apuntado.
class PlayerState extends ChangeNotifier {
  int _life = kInitialLife;
  int _committedLife = kInitialLife;
  final List<String> _history = [];

  int get life => _life;
  int get committedLife => _committedLife;
  int get pending => _life - _committedLife;
  List<String> get history => List.unmodifiable(_history);

  /// Suma [delta] a la vida. Devuelve `false` si se saldría de [kMinLife, kMaxLife].
  bool change(int delta) {
    final newLife = _life + delta;
    if (newLife < kMinLife || newLife > kMaxLife) return false;
    _life = newLife;
    notifyListeners();
    return true;
  }

  /// Apunta en el historial el cambio pendiente, si lo hay.
  void commit() {
    final change = pending;
    if (change == 0) return;
    final sign = change > 0 ? '+' : '';
    _history.add('$sign$change = $_life');
    _committedLife = _life;
    notifyListeners();
  }

  void reset() {
    _life = kInitialLife;
    _committedLife = kInitialLife;
    _history.clear();
    notifyListeners();
  }

  Map<String, dynamic> toJson() => {
    'life': _life,
    'committedLife': _committedLife,
    'history': _history,
  };

  void restore(Map<String, dynamic> json) {
    // Fuera de rango no se podría ni sumar ni restar: se recorta.
    _life = (json['life'] as int? ?? kInitialLife).clamp(kMinLife, kMaxLife);
    _committedLife = (json['committedLife'] as int? ?? _life).clamp(
      kMinLife,
      kMaxLife,
    );
    _history
      ..clear()
      ..addAll((json['history'] as List? ?? const []).cast<String>());
    // Un grupo que se quedó a medias al cerrar la app se apunta ya.
    commit();
    notifyListeners();
  }
}

/// La partida: los dos jugadores y si el de arriba está girado.
class GameState extends ChangeNotifier {
  GameState() {
    top.addListener(notifyListeners);
    bottom.addListener(notifyListeners);
  }

  final PlayerState top = PlayerState();
  final PlayerState bottom = PlayerState();
  bool _rotated = false;

  bool get rotated => _rotated;

  void toggleRotation() {
    _rotated = !_rotated;
    notifyListeners();
  }

  /// Vuelve a 20 y borra el historial. El giro se mantiene: depende de cómo
  /// estén sentados, no de la partida.
  void reset() {
    top.reset();
    bottom.reset();
  }

  Map<String, dynamic> toJson() => {
    'top': top.toJson(),
    'bottom': bottom.toJson(),
    'rotated': _rotated,
  };

  void restore(Map<String, dynamic> json) {
    top.restore(json['top'] as Map<String, dynamic>? ?? const {});
    bottom.restore(json['bottom'] as Map<String, dynamic>? ?? const {});
    _rotated = json['rotated'] as bool? ?? false;
    notifyListeners();
  }

  @override
  void dispose() {
    top.dispose();
    bottom.dispose();
    super.dispose();
  }
}

/// Guarda la partida en el dispositivo para que sobreviva a cerrar la app.
///
/// Escribe medio segundo después del último cambio (no en cada toque) y
/// [flush] escribe al momento, que es lo que se llama cuando la app pasa a
/// segundo plano.
class GameStorage {
  GameStorage(this._prefs, this._game);

  static const _kGame = 'game';
  static const _delay = Duration(milliseconds: 500);

  final SharedPreferences _prefs;
  final GameState _game;
  Timer? _timer;
  bool _enabled = false;

  /// Carga la partida guardada, si hay una.
  void load() {
    final saved = _prefs.getString(_kGame);
    if (saved == null) return;
    try {
      final json = jsonDecode(saved) as Map<String, dynamic>;
      // Primero en una partida de prueba: si falla a la mitad, la de verdad
      // no se queda con un jugador cargado y el otro no.
      GameState()
        ..restore(json)
        ..dispose();
      _game.restore(json);
    } on Object {
      // Una partida guardada que no se puede leer se descarta.
      _prefs.remove(_kGame);
    }
  }

  /// Empieza o deja de guardar. Al dejarlo se borra lo guardado.
  set enabled(bool value) {
    if (value == _enabled) return;
    _enabled = value;
    if (value) {
      _game.addListener(_schedule);
      flush();
    } else {
      _game.removeListener(_schedule);
      _timer?.cancel();
      _prefs.remove(_kGame);
    }
  }

  void _schedule() {
    _timer?.cancel();
    _timer = Timer(_delay, flush);
  }

  void flush() {
    _timer?.cancel();
    if (!_enabled) return;
    _prefs.setString(_kGame, jsonEncode(_game.toJson()));
  }
}
