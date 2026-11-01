import 'dart:async';

import 'package:flutter/material.dart';

/// Repite [onStep] mientras se mantiene pulsado [child], un botón que hace lo
/// mismo con un toque. Empieza al pulsar largo (medio segundo) y a los diez
/// pasos va el doble de rápido. Para solo al soltar o al llegar al límite
/// ([onStep] a null).
///
/// El botón de dentro no debe llevar `tooltip`: en el móvil la ayuda sale al
/// pulsar largo y se quedaría con la pulsación. Lo que dice va en [label].
class HoldToRepeat extends StatefulWidget {
  const HoldToRepeat({
    super.key,
    required this.onStep,
    required this.label,
    required this.child,
  });

  final VoidCallback? onStep;

  /// Lo que hace, para los lectores de pantalla.
  final String label;
  final Widget child;

  static const Duration slow = Duration(milliseconds: 150);
  static const Duration fast = Duration(milliseconds: 70);

  @override
  State<HoldToRepeat> createState() => _HoldToRepeatState();
}

class _HoldToRepeatState extends State<HoldToRepeat> {
  Timer? _timer;
  int _steps = 0;

  void _start() {
    _steps = 0;
    _step();
    _every(HoldToRepeat.slow);
  }

  void _every(Duration period) {
    _timer?.cancel();
    _timer = Timer.periodic(period, (_) {
      _step();
      if (_steps == 10) _every(HoldToRepeat.fast);
    });
  }

  void _step() {
    // Se lee del widget de ahora: al llegar al límite el botón lo quita.
    final step = widget.onStep;
    if (step == null) return _stop();
    step();
    _steps++;
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.label,
      child: GestureDetector(
        onLongPressStart: (_) => _start(),
        onLongPressEnd: (_) => _stop(),
        onLongPressCancel: _stop,
        child: widget.child,
      ),
    );
  }
}
