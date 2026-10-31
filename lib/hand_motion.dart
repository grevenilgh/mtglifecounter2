import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

// Lanzar los sorteos moviendo el móvil. El acelerómetro mide la gravedad más
// lo que se mueve la mano: la gravedad es lo que cambia despacio, así que un
// filtro la separa y queda el movimiento de la mano. Con ella se sabe además
// dónde está «arriba», tenga el móvil como lo tenga.

/// Una lectura del movimiento de la mano, sin la gravedad, en m/s².
class HandSample {
  const HandSample(this.x, this.y, this.vertical);

  /// La aceleración en el plano de la pantalla: x a la derecha, y hacia
  /// arriba de la pantalla.
  final double x;
  final double y;

  /// La parte que va hacia arriba (positiva) o hacia abajo (negativa) de
  /// verdad, no de la pantalla.
  final double vertical;

  double get magnitude => sqrt(x * x + y * y + vertical * vertical);
}

/// Escucha el acelerómetro mientras está encendido. Fuera del móvil no se
/// enciende, y si un móvil no tiene sensor no llega ninguna lectura: en los
/// dos casos no sale la ayuda y solo queda el botón.
class HandMotion {
  HandMotion(this.onSample);

  final void Function(HandSample sample) onSample;

  // Cuánto tarda el filtro en seguir a la gravedad: más corto que un giro de
  // muñeca y más largo que un golpe.
  static const double _settle = 0.25;

  StreamSubscription<AccelerometerEvent>? _sub;
  List<double>? _gravity;
  DateTime? _last;

  /// Solo en el móvil (también desde su navegador): en el resto los sorteos
  /// se lanzan con el botón.
  static bool get supported =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  void start() {
    if (!supported) return;
    try {
      _sub = accelerometerEventStream(
        samplingPeriod: SensorInterval.gameInterval,
      ).listen(_read, onError: (Object _) {}, cancelOnError: true);
    } catch (_) {
      // Sin sensores en esta plataforma.
    }
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
  }

  void _read(AccelerometerEvent e) {
    final now = DateTime.now();
    final raw = [e.x, e.y, e.z];
    final g = _gravity;
    final last = _last;
    _last = now;
    if (g == null || last == null) {
      _gravity = raw;
      return;
    }
    final dt = now.difference(last).inMicroseconds / 1e6;
    final k = dt / (_settle + dt);
    for (var i = 0; i < 3; i++) {
      g[i] += k * (raw[i] - g[i]);
    }
    final hand = [for (var i = 0; i < 3; i++) raw[i] - g[i]];
    final norm = sqrt(g[0] * g[0] + g[1] * g[1] + g[2] * g[2]);
    if (norm < 1) return;
    // En reposo el acelerómetro marca hacia arriba, así que la gravedad
    // filtrada apunta arriba.
    final up = (hand[0] * g[0] + hand[1] * g[1] + hand[2] * g[2]) / norm;
    onSample(HandSample(hand[0], hand[1], up));
  }
}

/// Un golpe seco de arriba abajo, como el de lanzar una moneda al aire.
/// Avisa con la fuerza del golpe, de 0 a 1.
class FlickDetector {
  FlickDetector(this.onFlick);

  final void Function(double strength) onFlick;

  // A partir de cuánto es un golpe y cuánto es uno a tope, en m/s².
  static const double _threshold = 13;
  static const double _full = 34;

  // Lo que se espera desde que empieza el golpe para ver lo fuerte que es,
  // y lo que se ignora después para no lanzar dos veces.
  static const Duration _window = Duration(milliseconds: 160);
  static const Duration _rest = Duration(milliseconds: 900);

  double? _peak;
  DateTime _start = DateTime(0);
  DateTime _quietUntil = DateTime(0);

  void add(HandSample s) {
    final now = DateTime.now();
    if (now.isBefore(_quietUntil)) return;
    final v = s.vertical.abs();
    final peak = _peak;
    if (peak == null) {
      // Solo cuenta si va sobre todo de arriba abajo.
      if (v > _threshold && v > 0.7 * s.magnitude) {
        _peak = v;
        _start = now;
      }
      return;
    }
    _peak = max(peak, v);
    if (now.difference(_start) < _window) return;
    onFlick(((_peak! - _threshold) / (_full - _threshold)).clamp(0.0, 1.0));
    _peak = null;
    _quietUntil = now.add(_rest);
  }
}

/// Agitar el móvil como un cubilete: empieza con un par de sacudidas seguidas
/// y acaba cuando la mano se para. Mientras dura avisa de cada lectura y de
/// cada sacudida, y al soltar, de la fuerza con que se ha agitado (0 a 1).
class ShakeDetector {
  ShakeDetector({
    required this.onShake,
    required this.onStroke,
    required this.onRelease,
  });

  final void Function(HandSample sample) onShake;
  final void Function() onStroke;
  final void Function(double strength) onRelease;

  // Una sacudida sube de [_high] y no cuenta otra hasta que baja de [_low].
  static const double _high = 11;
  static const double _low = 5;
  static const Duration _pair = Duration(milliseconds: 700);
  static const Duration _stop = Duration(milliseconds: 380);

  bool _inStroke = false;
  bool shaking = false;
  int _strokes = 0;
  double _peak = 0;
  DateTime _lastStroke = DateTime(0);

  void add(HandSample s) {
    final now = DateTime.now();
    final m = s.magnitude;
    if (!_inStroke && m > _high) {
      _inStroke = true;
      if (!shaking) {
        if (now.difference(_lastStroke) < _pair) {
          shaking = true;
          _strokes = 1;
          _peak = 0;
        }
      }
      _lastStroke = now;
      if (shaking) {
        _strokes++;
        onStroke();
      }
    } else if (_inStroke && m < _low) {
      _inStroke = false;
    }
    if (!shaking) return;
    _peak = max(_peak, m);
    onShake(s);
    if (now.difference(_lastStroke) > _stop) {
      shaking = false;
      // Cuenta tanto lo que se ha agitado como lo fuerte.
      final strength =
          0.6 * (_strokes / 10).clamp(0.0, 1.0) +
          0.4 * ((_peak - _high) / 25).clamp(0.0, 1.0);
      onRelease(strength);
    }
  }
}
