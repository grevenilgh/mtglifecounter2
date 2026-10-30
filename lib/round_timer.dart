import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Qué cuenta el temporizador de ronda.
enum TimerMode {
  /// Del tiempo de ronda hacia cero, con aviso a falta de 5 minutos.
  countdown('Cuenta atrás'),

  /// Hacia delante, sin límite: para saber cuánto dura la partida.
  stopwatch('Cronómetro');

  const TimerMode(this.label);

  final String label;

  static TimerMode fromName(String? name) =>
      values.firstWhere((m) => m.name == name, orElse: () => countdown);
}

/// El temporizador de ronda.
///
/// Guarda cuándo se puso en marcha y lo acumulado en las pausas, no un
/// contador que vaya bajando: así sigue bien aunque la app se cierre o el
/// móvil se bloquee, y al volver enseña el tiempo real.
class RoundTimer extends ChangeNotifier {
  // El modo y la duración llegan ya en el constructor: si se pusieran después,
  // un cronómetro de más de 50 minutos se daría por acabado al abrir la app.
  RoundTimer(
    this._prefs, {
    this.mode = TimerMode.countdown,
    this.roundLength = const Duration(minutes: 50),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    _accumulated = Duration(milliseconds: _prefs.getInt(_kAccumulated) ?? 0);
    final started = _prefs.getInt(_kStartedAt);
    _startedAt = started == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(started);
    _finishedNotified = _prefs.getBool(_kFinished) ?? false;
    if (running) _tick();
  }

  static const _kAccumulated = 'timerAccumulated';
  static const _kStartedAt = 'timerStartedAt';
  static const _kFinished = 'timerFinished';

  /// Cuánto antes del final se avisa.
  static const Duration warningTime = Duration(minutes: 5);

  final SharedPreferences _prefs;
  final DateTime Function() _clock;
  Duration _accumulated = Duration.zero;
  DateTime? _startedAt;
  Timer? _ticker;
  bool _finishedNotified = false;

  TimerMode mode;
  Duration roundLength;

  /// Se llama una vez cuando la cuenta atrás llega a cero.
  VoidCallback? onFinished;

  bool get running => _startedAt != null;

  /// Si se ha tocado desde el último reinicio.
  bool get started => running || _accumulated > Duration.zero;

  Duration get elapsed =>
      _accumulated +
      (running ? _clock().difference(_startedAt!) : Duration.zero);

  Duration get remaining {
    final left = roundLength - elapsed;
    return left.isNegative ? Duration.zero : left;
  }

  /// Lo que enseña el reloj: lo que queda o, en cronómetro, lo que va.
  Duration get shown => mode == TimerMode.countdown ? remaining : elapsed;

  bool get finished =>
      mode == TimerMode.countdown && remaining == Duration.zero;

  /// Quedan [warningTime] o menos (y aún no se ha acabado).
  bool get warning =>
      mode == TimerMode.countdown && !finished && remaining <= warningTime;

  void start() {
    if (running || finished) return;
    _startedAt = _clock();
    _save();
    _tick();
    notifyListeners();
  }

  void pause() {
    if (!running) return;
    _accumulated = elapsed;
    _startedAt = null;
    _ticker?.cancel();
    _save();
    notifyListeners();
  }

  void reset() {
    _ticker?.cancel();
    _accumulated = Duration.zero;
    _startedAt = null;
    _finishedNotified = false;
    _save();
    notifyListeners();
  }

  /// Cambia la duración de la ronda. Solo antes de empezar.
  void setRoundLength(Duration value) {
    if (started) return;
    roundLength = value;
    notifyListeners();
  }

  void _tick() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
    _onTick();
  }

  void _onTick() {
    if (finished) {
      // La cuenta atrás se para sola en cero.
      _accumulated = roundLength;
      _startedAt = null;
      _ticker?.cancel();
      if (!_finishedNotified) {
        _finishedNotified = true;
        onFinished?.call();
      }
      _save();
    }
    notifyListeners();
  }

  void _save() {
    _prefs.setInt(_kAccumulated, _accumulated.inMilliseconds);
    final started = _startedAt;
    if (started == null) {
      _prefs.remove(_kStartedAt);
    } else {
      _prefs.setInt(_kStartedAt, started.millisecondsSinceEpoch);
    }
    _prefs.setBool(_kFinished, _finishedNotified);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}

/// «m:ss», o «h:mm:ss» a partir de una hora (el cronómetro puede pasar).
String formatClock(Duration d) {
  final seconds = d.inSeconds;
  final h = seconds ~/ 3600;
  final m = (seconds ~/ 60) % 60;
  final s = (seconds % 60).toString().padLeft(2, '0');
  return h > 0
      ? '$h:${m.toString().padLeft(2, '0')}:$s'
      : '${seconds ~/ 60}:$s';
}
