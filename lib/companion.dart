import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:mtglifecounter/round_timer.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Los avisos de Companion que sirven: lo demás que manda no toca el reloj.
enum CompanionEventKind {
  /// «Evento empezado»: el torneo está abierto.
  eventStarted('event_started'),

  /// «Ronda iniciada»: la ronda está en marcha.
  roundStarted('round_started'),

  /// «Ronda completada»: el organizador cerró la ronda.
  roundCompleted('round_completed'),

  /// El reloj de Companion leído en su pantalla, en marcha, con lo que le
  /// quedaba ([CompanionEvent.left]).
  screenClock('screen_clock');

  const CompanionEventKind(this.wire);

  /// Como lo apunta el servicio de Android (CompanionListener.kt).
  final String wire;

  static CompanionEventKind? fromWire(String? wire) =>
      values.where((k) => k.wire == wire).firstOrNull;
}

/// Un aviso de Companion, con la hora a la que llegó.
@immutable
class CompanionEvent {
  const CompanionEvent(this.kind, this.at, {this.left});

  final CompanionEventKind kind;
  final DateTime at;

  /// En [CompanionEventKind.screenClock], lo que le quedaba en [at].
  final Duration? left;
}

/// Lo que hace falta de Android: el servicio que lee los avisos de Companion
/// (`CompanionListener.kt`) y el acceso a notificaciones. En los tests se
/// cambia por uno de mentira.
abstract class CompanionBridge {
  /// Enciende o apaga el servicio.
  Future<void> setEnabled(bool enabled);

  /// Si Android le ha dado a la app el acceso a notificaciones.
  Future<bool> hasAccess();

  /// Abre la pantalla de Android donde se da el acceso.
  Future<void> openAccess();

  /// Enciende o apaga la lectura de la pantalla de Companion
  /// (`CompanionScreenService.kt`).
  Future<void> setScreenEnabled(bool enabled);

  /// Si el servicio que lee la pantalla está activado en Accesibilidad.
  Future<bool> hasScreenAccess();

  /// Abre la pantalla de Accesibilidad de Android donde se activa.
  Future<void> openScreenAccess();

  /// Abre la información de la app, donde se permiten los ajustes
  /// restringidos (Android 13+ los pide a las apps instaladas con un APK).
  Future<void> openAppInfo();

  /// Los avisos apuntados (los del último día).
  Future<List<CompanionEvent>> events();

  /// TRAZAS PROVISIONALES: apunta [ev] en el registro de diagnóstico del
  /// móvil (`companion_debug.jsonl`), para analizar un torneo.
  Future<void> log(String ev, Map<String, Object?> data);

  /// Se llama cuando el servicio apunta un aviso nuevo (con la app abierta).
  set onChanged(VoidCallback? callback);
}

/// El [CompanionBridge] de verdad, por el canal `mtglifecounter/companion`
/// de `MainActivity.kt`.
class AndroidCompanionBridge implements CompanionBridge {
  AndroidCompanionBridge() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'changed') _onChanged?.call();
    });
  }

  static const _channel = MethodChannel('mtglifecounter/companion');
  VoidCallback? _onChanged;

  @override
  set onChanged(VoidCallback? callback) => _onChanged = callback;

  @override
  Future<void> setEnabled(bool enabled) =>
      _call<void>('setEnabled', enabled);

  @override
  Future<bool> hasAccess() async =>
      await _call<bool>('hasAccess') ?? false;

  @override
  Future<void> openAccess() => _call<void>('openAccess');

  @override
  Future<void> setScreenEnabled(bool enabled) =>
      _call<void>('setScreenEnabled', enabled);

  @override
  Future<bool> hasScreenAccess() async =>
      await _call<bool>('hasScreenAccess') ?? false;

  @override
  Future<void> openScreenAccess() => _call<void>('openScreenAccess');

  @override
  Future<void> openAppInfo() => _call<void>('openAppInfo');

  @override
  Future<void> log(String ev, Map<String, Object?> data) =>
      _call<void>('log', {'ev': ev, 'data': data});

  @override
  Future<List<CompanionEvent>> events() async {
    final raw = await _call<List<Object?>>('events') ?? const [];
    return [
      for (final item in raw.whereType<Map<Object?, Object?>>())
        if (CompanionEventKind.fromWire(item['kind'] as String?)
            case final kind?)
          if (item['at'] case final int at)
            CompanionEvent(
              kind,
              DateTime.fromMillisecondsSinceEpoch(at),
              left: switch (item['left']) {
                final int ms => Duration(milliseconds: ms),
                _ => null,
              },
            ),
    ];
  }

  static Future<T?> _call<T>(String method, [Object? arguments]) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}

/// «Eventos de Companion» (beta, solo en Android): el reloj de ronda sigue los
/// avisos de la app Companion de Wizards.
///
/// Companion no dice cuánto queda, ni la mesa ni el rival: solo avisa al
/// empezar el evento y al empezar y acabar cada ronda. Con eso:
///
/// * Con cualquiera de esos avisos se engancha al evento (si se perdió
///   «Evento empezado», con la primera ronda).
/// * «Ronda iniciada» reinicia el reloj a lo de por defecto de Ajustes y lo
///   pone en marcha desde la hora del aviso: si la app se abre tarde, ya ha
///   corrido ese rato. El de ajedrez solo se reinicia: lo arranca la primera
///   pulsación.
/// * «Ronda completada» lo para.
/// * Con el permiso de accesibilidad (opcional), cada vez que la pantalla de
///   Companion enseña su reloj en marcha, el de la app se pone en hora con
///   él ([RoundTimer.follow]).
/// * Companion no avisa del final del torneo: se suelta solo a las
///   [idleLimit] sin avisos.
///
/// Desde la hoja del reloj se puede soltar ([attached] = false): hasta que
/// acabe ese evento no toca el reloj.
///
/// Companion no manda el aviso si está abierta en ese momento (lo enseña
/// dentro): esa ronda no llega, y sin la pantalla el reloj se arranca a mano.
class CompanionLink extends ChangeNotifier {
  CompanionLink(
    this._prefs,
    this._timer, {
    bool enabled = false,
    CompanionBridge? bridge,
    DateTime Function()? clock,
  }) : bridge = bridge ?? AndroidCompanionBridge(),
       _clock = clock ?? DateTime.now,
       _enabled = enabled {
    // La lectura de la pantalla va con el mismo interruptor: funciona si
    // además se da el permiso de accesibilidad.
    this.bridge.setScreenEnabled(enabled);
    _lastSeen = _date(_prefs.getInt(_kLastSeen));
    _lastEvent = _date(_prefs.getInt(_kLastEvent));
    _detached = _prefs.getBool(_kDetached) ?? false;
    this.bridge.onChanged = () => sync('changed');
    // Que el servicio esté como dice Ajustes. Lo que llegó con la app cerrada
    // se aplica con el primer [sync].
    this.bridge.setEnabled(enabled);
  }

  /// Solo en Android: en el iPhone una web no puede ver los avisos de otra
  /// app.
  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Sin avisos en este tiempo se da el evento por acabado.
  static const Duration idleLimit = Duration(hours: 3);

  static const _kLastSeen = 'companionLastSeen';
  static const _kLastEvent = 'companionLastEvent';
  static const _kDetached = 'companionDetached';

  final SharedPreferences _prefs;
  final RoundTimer _timer;
  final CompanionBridge bridge;
  final DateTime Function() _clock;

  bool _enabled;
  // El último aviso ya visto: los de antes no se vuelven a aplicar.
  DateTime? _lastSeen;
  // El último aviso del evento de ahora.
  DateTime? _lastEvent;
  bool _detached = false;

  static DateTime? _date(int? ms) =>
      ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);

  /// Si está activado en Ajustes.
  bool get enabled => _enabled;

  /// Lo enciende o apaga desde Ajustes. Al encenderlo no se aplica lo que
  /// llegó antes: solo los avisos desde ahora.
  set enabled(bool value) {
    if (value == _enabled) return;
    _enabled = value;
    bridge.setEnabled(value);
    bridge.setScreenEnabled(value);
    if (value) {
      _lastSeen = _clock();
    } else {
      _lastEvent = null;
      _detached = false;
    }
    _save();
    // Apagado no se apunta nada: se deja escrito antes.
    if (!value) bridge.log('disabled', const {});
    trace('enabled');
    notifyListeners();
  }

  /// Hay un evento de Companion en marcha (un aviso hace menos de
  /// [idleLimit]), enganchado o no.
  bool get inEvent {
    final last = _lastEvent;
    return _enabled &&
        last != null &&
        _clock().difference(last) < idleLimit;
  }

  /// El reloj sigue a Companion: hay un evento y no se ha soltado.
  bool get engaged => inEvent && !_detached;

  /// Si el reloj sigue a Companion en este evento. Se suelta desde la hoja
  /// del reloj; vuelve a engancharse en el evento siguiente.
  bool get attached => !_detached;

  set attached(bool value) {
    if (value == !_detached) return;
    _detached = !value;
    _save();
    trace(value ? 'attached' : 'detached');
    notifyListeners();
  }

  /// Lee los avisos nuevos y se los aplica al reloj. Se llama al abrir la
  /// app, al volver a ella y cuando el servicio apunta uno.
  Future<void> sync([String why = 'sync']) async {
    if (!_enabled) return;
    final events = await bridge.events();
    trace(why, {'events': events.length});
    apply(events);
  }

  /// Aplica al reloj los avisos que aún no se habían visto, en orden.
  @visibleForTesting
  void apply(List<CompanionEvent> events) {
    if (!_enabled) return;
    final now = _clock();
    final fresh =
        events
            .where((e) => _lastSeen == null || e.at.isAfter(_lastSeen!))
            .toList()
          ..sort((a, b) => a.at.compareTo(b.at));
    for (final event in fresh) {
      _lastSeen = event.at;
      final before = _timerState();
      void traceEvent(String decision) => trace('event', {
        'kind': event.kind.wire,
        'eventAt': event.at.millisecondsSinceEpoch,
        'left': event.left?.inMilliseconds,
        'decision': decision,
        'before': before,
        'after': _timerState(),
      });
      // Lo de un evento ya acabado no se aplica.
      if (now.difference(event.at) >= idleLimit) {
        traceEvent('too-old');
        continue;
      }
      final last = _lastEvent;
      // Un evento nuevo vuelve a engancharse aunque el anterior se soltara.
      if (last == null || event.at.difference(last) >= idleLimit) {
        _detached = false;
      }
      _lastEvent = event.at;
      if (_detached) {
        traceEvent('detached');
        continue;
      }
      switch (event.kind) {
        case CompanionEventKind.eventStarted:
          break;
        case CompanionEventKind.roundStarted:
          _timer.reset();
          _timer.startFrom(event.at);
        case CompanionEventKind.roundCompleted:
          _timer.pause();
        case CompanionEventKind.screenClock:
          final left = event.left;
          if (left != null) _timer.follow(left, event.at);
      }
      traceEvent('applied');
    }
    _save();
    notifyListeners();
  }

  // ---- TRAZAS PROVISIONALES (quitar cuando se sepa todo; ver CLAUDE.md) ----

  /// Cómo está el reloj, para las trazas.
  Map<String, Object?> _timerState() => {
    'mode': _timer.mode.name,
    'running': _timer.running,
    'started': _timer.started,
    'lengthMs': _timer.roundLength.inMilliseconds,
    'shownMs': _timer.shown.inMilliseconds,
  };

  /// Apunta [ev] en el registro de diagnóstico del móvil con el estado del
  /// reloj y del enganche. Se usa también al abrir la app y volver a ella.
  void trace(String ev, [Map<String, Object?> data = const {}]) {
    if (!_enabled) return;
    bridge.log(ev, {
      ...data,
      'timer': _timerState(),
      'inEvent': inEvent,
      'attached': attached,
    });
  }

  void _save() {
    void setDate(String key, DateTime? value) => value == null
        ? _prefs.remove(key)
        : _prefs.setInt(key, value.millisecondsSinceEpoch);
    setDate(_kLastSeen, _lastSeen);
    setDate(_kLastEvent, _lastEvent);
    _prefs.setBool(_kDetached, _detached);
  }

  @override
  void dispose() {
    bridge.onChanged = null;
    super.dispose();
  }
}
