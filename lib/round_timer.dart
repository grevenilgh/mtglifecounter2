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
    // Si se acabó con la app cerrada, se queda parado en 0:00 (sin el aviso,
    // que llegaría tarde).
    if (running && !_settle(notify: false)) _tick();
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

  /// Si se ha tocado desde el último reinicio. En el reloj de ajedrez, en
  /// cuanto alguien ha pulsado, aunque aún no haya pasado tiempo.
  bool get started => running || _accumulated > Duration.zero || _turn != null;

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

  /// La cuenta atrás ha llegado a cero. Ahí se para y se queda en 0:00: no
  /// cuenta lo que se pasan (los turnos extra se cuentan en turnos), y así un
  /// reloj olvidado no sigue horas en negativo repintando cada segundo.
  bool get finished => mode == TimerMode.countdown && elapsed >= roundLength;

  /// Quedan [warningTime] o menos (y aún no se ha acabado).
  bool get warning =>
      mode == TimerMode.countdown && !finished && remaining <= warningTime;

  bool get chess => mode == TimerMode.chess;

  /// A quién le corre el reloj de ajedrez (o le correrá al reanudar). Null
  /// antes de empezar.
  Seat? get turn => _turn;

  /// El tiempo de cada jugador: la mitad de la ronda.
  Duration get share => roundLength ~/ 2;

  /// Lo que le queda a [seat]. No baja de cero: a quien se le acaba se queda
  /// en 0:00.
  Duration leftFor(Seat seat) {
    final mine = seat == _turn ? _sinceStart : Duration.zero;
    final left = share - _spent[seat]! - mine;
    return left.isNegative ? Duration.zero : left;
  }

  /// Lo que les queda entre los dos: lo que enseña la barra en el reloj de
  /// ajedrez.
  Duration get totalLeft => leftFor(Seat.top) + leftFor(Seat.bottom);

  /// A [seat] se le ha acabado su tiempo.
  bool outOfTime(Seat seat) => leftFor(seat) == Duration.zero;

  /// En el reloj de ajedrez, al que tiene el turno se le ha acabado el suyo y
  /// al otro aún le queda: el reloj está parado hasta que pase el turno con su
  /// botón.
  bool get waitingForPress {
    final turn = _turn;
    return chess &&
        !running &&
        turn != null &&
        outOfTime(turn) &&
        !outOfTime(turn.other);
  }

  /// A [seat] le quedan [seatWarningTime] o menos (y aún no se le ha acabado).
  bool warningFor(Seat seat) =>
      !outOfTime(seat) && leftFor(seat) <= seatWarningTime;

  /// Se puede poner en marcha desde la hoja: empezar o reanudar. Acabado el
  /// tiempo, no: solo reiniciar.
  bool get canStart {
    if (running) return false;
    if (finished) return false;
    final turn = _turn;
    // El reloj de ajedrez lo arranca el botón de un jugador: sin él no se
    // sabe de quién es el turno. Y a quien se le ha acabado no le corre.
    if (chess) return turn != null && !outOfTime(turn);
    return true;
  }

  void start() {
    if (!canStart) return;
    _startedAt = _clock();
    _save();
    _tick();
    notifyListeners();
  }

  /// Lo pone en marcha como si se hubiera arrancado en [at] (con los avisos
  /// de ronda de Companion: la ronda empezó cuando llegó el aviso, aunque la
  /// app se abra después). Si para entonces ya se ha acabado, se queda parado
  /// en 0:00 sin el aviso, que llegaría tarde.
  void startFrom(DateTime at) {
    if (!canStart) return;
    final now = _clock();
    _startedAt = at.isAfter(now) ? now : at;
    _save();
    if (!_settle(notify: false)) _tick();
    notifyListeners();
  }

  /// Lo pone en hora con el reloj de Companion, leído en su pantalla: a las
  /// [at] le quedaba [left] y estaba en marcha. Queda en cuenta atrás y en
  /// marcha; si hace falta, la ronda se alarga para que quepa. El de ajedrez
  /// no se toca, y si ya va a menos de 2 segundos de eso, tampoco.
  void follow(Duration left, DateTime at) {
    if (chess) return;
    final now = _clock();
    final leftNow = left - now.difference(at);
    if (mode == TimerMode.countdown &&
        running &&
        (remaining - leftNow).abs() < const Duration(seconds: 2)) {
      return;
    }
    _ticker?.cancel();
    _mode = TimerMode.countdown;
    modeListenable.value = _mode;
    final minutes = Duration(minutes: (left.inSeconds / 60).ceil());
    roundLength = minutes > defaultLength ? minutes : defaultLength;
    _accumulated = Duration.zero;
    _finishedNotified = false;
    _startedAt = at.subtract(roundLength - left);
    _save();
    if (!_settle(notify: false)) _tick();
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
  /// en pausa no hace nada; a quien se le ha acabado el tiempo sí le vale,
  /// para pasar el turno al otro. Devuelve si ha cambiado algo.
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
    if (_turn != seat || !(running || waitingForPress)) return false;
    _bank();
    _turn = seat.other;
    if (outOfTime(seat.other)) {
      // Al otro tampoco le queda: el reloj se queda parado.
      _startedAt = null;
      _ticker?.cancel();
      _save();
      notifyListeners();
    } else {
      _startedAt = _clock();
      _save();
      _tick();
    }
    return true;
  }

  // Pasa lo que va desde que arrancó a lo acumulado y, en ajedrez, a lo del
  // jugador que tiene el turno. Puede pasar de lo que quedaba (si se paró con
  // la app cerrada): lo que queda no baja de cero ([remaining], [leftFor]), y
  // el cronómetro sigue teniendo lo que lleva de verdad.
  void _bank() {
    final since = _sinceStart;
    _accumulated += since;
    final turn = _turn;
    if (turn != null) _spent[turn] = _spent[turn]! + since;
  }

  // Si se ha acabado el tiempo con el reloj en marcha (la cuenta atrás o, en
  // ajedrez, el del que tiene el turno), lo para justo en cero y avisa una
  // vez. Devuelve si lo ha parado.
  bool _settle({bool notify = true}) {
    if (!running) return false;
    final turn = _turn;
    final bool done;
    if (mode == TimerMode.countdown) {
      done = finished;
    } else if (chess && turn != null) {
      done = outOfTime(turn);
    } else {
      done = false;
    }
    if (!done) return false;
    _bank();
    _startedAt = null;
    _ticker?.cancel();
    var first = false;
    if (chess && turn != null) {
      first = !_flagged[turn]!;
      _flagged[turn] = true;
    } else {
      first = !_finishedNotified;
      _finishedNotified = true;
    }
    _save();
    if (first && notify) onFinished?.call();
    return true;
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
    // Al llegar a cero se para en 0:00 y avisa una vez (en ajedrez, una vez
    // a cada jugador).
    _settle();
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

/// Lo que enseña el reloj: lo que queda (o lo que va, en cronómetro; o lo que
/// les queda a los dos, en ajedrez).
String timerLabel(RoundTimer timer) =>
    formatClock(timer.chess ? timer.totalLeft : timer.shown);

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
