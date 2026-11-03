import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Qué cuenta el temporizador de ronda.
enum TimerMode {
  /// Del tiempo de ronda hacia cero, con aviso a falta de 5 minutos.
  countdown('Cuenta atrás'),

  /// Hacia delante, sin límite: para saber cuánto dura la partida.
  stopwatch('Cronómetro'),

  /// Reloj de ajedrez: el tiempo de ronda se reparte entre los dos y solo
  /// corre el del jugador al que le toca.
  chess('Ajedrez');

  const TimerMode(this.label);

  final String label;

  static TimerMode fromName(String? name) =>
      values.firstWhere((m) => m.name == name, orElse: () => countdown);
}

/// Cada uno de los dos jugadores, por el panel en el que está.
enum Seat {
  top,
  bottom;

  Seat get other => this == top ? bottom : top;
}

/// El temporizador de ronda.
///
/// Guarda cuándo se puso en marcha y lo acumulado en las pausas, no un
/// contador que vaya bajando: así sigue bien aunque la app se cierre o el
/// móvil se bloquee, y al volver enseña el tiempo real.
///
/// En el modo ajedrez lleva además lo que ha gastado cada jugador y a quién le
/// toca: lo que va desde que arrancó es del que tiene el turno.
class RoundTimer extends ChangeNotifier {
  // El modo y la duración de Ajustes llegan ya en el constructor: si se
  // pusieran después, un cronómetro de más de 50 minutos se daría por acabado
  // al abrir la app. Son los de por defecto: el reloj guarda los suyos, que
  // solo se cambian desde su hoja y al reiniciarlo vuelven a los de Ajustes.
  RoundTimer(
    this._prefs, {
    TimerMode mode = TimerMode.countdown,
    Duration roundLength = const Duration(minutes: 50),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       defaultMode = mode,
       defaultLength = roundLength {
    final savedMode = _prefs.getString(_kMode);
    _mode = savedMode == null ? mode : TimerMode.fromName(savedMode);
    final savedLength = _prefs.getInt(_kLength);
    this.roundLength = savedLength == null
        ? defaultLength
        : Duration(milliseconds: savedLength);
    _accumulated = Duration(milliseconds: _prefs.getInt(_kAccumulated) ?? 0);
    final started = _prefs.getInt(_kStartedAt);
    _startedAt = started == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(started);
    _finishedNotified = _prefs.getBool(_kFinished) ?? false;
    for (final seat in Seat.values) {
      _spent[seat] = Duration(
        milliseconds: _prefs.getInt('$_kSpent${seat.name}') ?? 0,
      );
      _flagged[seat] = _prefs.getBool('$_kFlagged${seat.name}') ?? false;
    }
    final turn = _prefs.getString(_kTurn);
    _turn = Seat.values.where((s) => s.name == turn).firstOrNull;
    if (running) _tick();
  }

  static const _kAccumulated = 'timerAccumulated';
  static const _kStartedAt = 'timerStartedAt';
  static const _kFinished = 'timerFinished';
  static const _kSpent = 'timerSpent_';
  static const _kFlagged = 'timerFlagged_';
  static const _kTurn = 'timerTurn';
  static const _kMode = 'timerModeNow';
  static const _kLength = 'timerRoundNow';

  /// Cuánto antes del final se avisa.
  static const Duration warningTime = Duration(minutes: 5);

  /// En el reloj de ajedrez, cuánto antes de acabar el suyo se avisa a cada
  /// jugador: 5 minutos de 25 sería muy pronto.
  static const Duration seatWarningTime = Duration(minutes: 2);

  final SharedPreferences _prefs;
  final DateTime Function() _clock;
  Duration _accumulated = Duration.zero;
  DateTime? _startedAt;
  Timer? _ticker;
  bool _finishedNotified = false;
  final Map<Seat, Duration> _spent = {};
  final Map<Seat, bool> _flagged = {};
  Seat? _turn;

  late TimerMode _mode;
  late Duration roundLength;

  /// Lo elegido en Ajustes: lo que se pone al reiniciar el reloj.
  TimerMode defaultMode;
  Duration defaultLength;

  /// El modo de ahora, para quien solo necesita enterarse de cuándo cambia
  /// (los paneles ponen o quitan el botón del reloj de ajedrez) y no de cada
  /// segundo.
  late final ValueNotifier<TimerMode> modeListenable = ValueNotifier(_mode);

  TimerMode get mode => _mode;

  /// Cambia el modo del reloj de ahora (en su hoja, entre cuenta atrás y
  /// cronómetro).
  set mode(TimerMode value) {
    if (value == _mode) return;
    _mode = value;
    modeListenable.value = value;
    _save();
    notifyListeners();
  }

  /// Pone lo elegido en Ajustes. Al reloj de ahora solo le llega si aún no ha
  /// empezado; si no, al reiniciarlo.
  void setDefaults(TimerMode mode, Duration length) {
    if (mode == defaultMode && length == defaultLength) return;
    defaultMode = mode;
    defaultLength = length;
    if (started || _turn != null) return;
    roundLength = length;
    this.mode = mode;
    _save();
    notifyListeners();
  }

  /// Se llama una vez cuando la cuenta atrás llega a cero y, en el reloj de
  /// ajedrez, una vez por jugador cuando se le acaba el suyo.
  VoidCallback? onFinished;

  bool get running => _startedAt != null;

  /// Si se ha tocado desde el último reinicio.
  bool get started => running || _accumulated > Duration.zero;

  // Si se atrasa el reloj del móvil con el temporizador en marcha, lo que va
  // desde que arrancó saldría negativo: cuenta como cero.
  Duration get _sinceStart {
    if (!running) return Duration.zero;
    final since = _clock().difference(_startedAt!);
    return since.isNegative ? Duration.zero : since;
  }

  Duration get elapsed => _accumulated + _sinceStart;

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

  bool get chess => mode == TimerMode.chess;

  /// A quién le corre el reloj de ajedrez (o le correrá al reanudar). Null
  /// antes de empezar.
  Seat? get turn => _turn;

  /// El tiempo de cada jugador: la mitad de la ronda.
  Duration get share => roundLength ~/ 2;

  /// Lo que le queda a [seat]. Sigue bajando de cero: quien se pasa sigue
  /// contando.
  Duration leftFor(Seat seat) {
    final mine = seat == _turn ? _sinceStart : Duration.zero;
    return share - _spent[seat]! - mine;
  }

  /// Lo que les queda entre los dos: lo que enseña la barra en el reloj de
  /// ajedrez. Puede ser negativo.
  Duration get totalLeft => roundLength - elapsed;

  /// A [seat] se le ha acabado su tiempo.
  bool overtime(Seat seat) => leftFor(seat) <= Duration.zero;

  /// A [seat] le quedan [seatWarningTime] o menos (y aún no se ha pasado).
  bool warningFor(Seat seat) =>
      !overtime(seat) && leftFor(seat) <= seatWarningTime;

  void start() {
    if (running || finished) return;
    // El reloj de ajedrez lo arranca el botón de un jugador: sin él no se
    // sabe de quién es el turno.
    if (chess && _turn == null) return;
    _startedAt = _clock();
    _save();
    _tick();
    notifyListeners();
  }

  void pause() {
    if (!running) return;
    _bank();
    _startedAt = null;
    _ticker?.cancel();
    _save();
    notifyListeners();
  }

  /// [seat] pulsa su botón del reloj de ajedrez: ha acabado lo suyo y le toca
  /// al otro. Como en ajedrez, la primera pulsación arranca el reloj del otro
  /// (pulsa quien no empieza). Solo vale el botón del que tiene el turno, y
  /// en pausa no hace nada. Devuelve si ha cambiado algo.
  bool press(Seat seat) {
    if (!chess) return false;
    if (_turn == null && !started) {
      _turn = seat.other;
      _startedAt = _clock();
      _save();
      _tick();
      notifyListeners();
      return true;
    }
    if (!running || _turn != seat) return false;
    _bank();
    _turn = seat.other;
    _startedAt = _clock();
    _save();
    _onTick();
    return true;
  }

  // Pasa lo que va desde que arrancó a lo acumulado y, en ajedrez, a lo del
  // jugador que tiene el turno.
  void _bank() {
    final since = _sinceStart;
    _accumulated += since;
    final turn = _turn;
    if (turn != null) _spent[turn] = _spent[turn]! + since;
  }

  void reset() {
    _ticker?.cancel();
    _accumulated = Duration.zero;
    _startedAt = null;
    _finishedNotified = false;
    _turn = null;
    for (final seat in Seat.values) {
      _spent[seat] = Duration.zero;
      _flagged[seat] = false;
    }
    // Vuelve a lo de Ajustes.
    roundLength = defaultLength;
    _mode = defaultMode;
    modeListenable.value = defaultMode;
    _save();
    notifyListeners();
  }

  /// Cambia la duración de la ronda de ahora. Solo antes de empezar.
  void setRoundLength(Duration value) {
    if (started) return;
    roundLength = value;
    _save();
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
    // El reloj de ajedrez no se para: avisa una vez a cada uno.
    final turn = _turn;
    if (chess && turn != null && overtime(turn) && !_flagged[turn]!) {
      _flagged[turn] = true;
      onFinished?.call();
      _save();
    }
    notifyListeners();
  }

  void _save() {
    _prefs.setString(_kMode, _mode.name);
    _prefs.setInt(_kLength, roundLength.inMilliseconds);
    _prefs.setInt(_kAccumulated, _accumulated.inMilliseconds);
    final started = _startedAt;
    if (started == null) {
      _prefs.remove(_kStartedAt);
    } else {
      _prefs.setInt(_kStartedAt, started.millisecondsSinceEpoch);
    }
    _prefs.setBool(_kFinished, _finishedNotified);
    for (final seat in Seat.values) {
      _prefs.setInt('$_kSpent${seat.name}', _spent[seat]!.inMilliseconds);
      _prefs.setBool('$_kFlagged${seat.name}', _flagged[seat]!);
    }
    final turn = _turn;
    if (turn == null) {
      _prefs.remove(_kTurn);
    } else {
      _prefs.setString(_kTurn, turn.name);
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    modeListenable.dispose();
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

/// Como [formatClock], pero con «−» delante si es negativo: lo que se ha
/// pasado un jugador del reloj de ajedrez. Lo pasado se redondea hacia
/// arriba, para que nada más pasarse salga «−0:01» y no «−0:00».
String formatSignedClock(Duration d) {
  if (!d.isNegative) return formatClock(d);
  final ms = -d.inMilliseconds;
  return '−${formatClock(Duration(seconds: (ms + 999) ~/ 1000))}';
}
