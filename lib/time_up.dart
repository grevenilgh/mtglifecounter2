import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:mtglifecounter/look.dart';

/// El aviso de «¡Tiempo!» al acabar la ronda: un sello rojo a pantalla
/// completa, uno para cada jugador (el de arriba girado si su panel lo está),
/// que cae de golpe, se sacude y se va solo a los pocos segundos. Tocar la
/// pantalla lo quita antes.
///
/// Dura [duration] y se acaba: nada de animaciones sin fin en la pantalla
/// principal, que la app pasa el día encendida en la mesa. Sin animaciones
/// (Ajustes), sale quieto el mismo tiempo.
class TimeUpOverlay extends StatefulWidget {
  const TimeUpOverlay({
    super.key,
    required this.look,
    required this.flipTop,
    required this.animate,
    required this.onDone,
  });

  final Look look;

  /// Si el panel de arriba está girado hacia el otro lado de la mesa.
  final bool flipTop;
  final bool animate;
  final VoidCallback onDone;

  static const Duration duration = Duration(milliseconds: 3200);

  @override
  State<TimeUpOverlay> createState() => _TimeUpOverlayState();
}

class _TimeUpOverlayState extends State<TimeUpOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: TimeUpOverlay.duration,
  );
  Timer? _still;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      _c.forward().whenComplete(_finish);
    } else {
      // Quieto, a mitad del aviso, y se quita a su hora.
      _c.value = 0.5;
      _still = Timer(TimeUpOverlay.duration, _finish);
    }
  }

  void _finish() {
    if (_done || !mounted) return;
    _done = true;
    widget.onDone();
  }

  @override
  void dispose() {
    _still?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'Se acabó el tiempo de la ronda',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _finish,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = _c.value;
            // Entra en una décima y se va en el último 18 %.
            final fadeIn = Curves.easeOut.transform((t / 0.08).clamp(0, 1));
            final fadeOut = Curves.easeIn.transform(
              ((t - 0.82) / 0.18).clamp(0, 1),
            );
            final opacity = fadeIn * (1 - fadeOut);
            // El sello cae desde grande y rebota un poco al dar en la mesa.
            final land = Curves.easeOutBack.transform((t / 0.16).clamp(0, 1));
            final scale = 2.2 - 1.2 * land;
            // Y se sacude al caer, cada vez menos.
            final shakeT = ((t - 0.1) / 0.22).clamp(0.0, 1.0);
            final shake = shakeT == 0 || shakeT == 1
                ? 0.0
                : sin(shakeT * pi * 6) * (1 - shakeT) * 0.08;
            Widget stamp(bool top) => Center(
              child: Transform.rotate(
                angle: (top && widget.flipTop ? pi : 0) + shake,
                child: Transform.scale(
                  scale: scale,
                  child: _Stamp(look: widget.look),
                ),
              ),
            );
            return Opacity(
              opacity: opacity,
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.55),
                child: Column(
                  children: [
                    Expanded(child: stamp(true)),
                    Expanded(child: stamp(false)),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Stamp extends StatelessWidget {
  const _Stamp({required this.look});

  final Look look;

  @override
  Widget build(BuildContext context) {
    final style = withFont(
      look.numberFont,
      const TextStyle(
        color: Colors.white,
        fontSize: 52,
        fontWeight: FontWeight.w900,
        height: 1,
        letterSpacing: 1,
      ),
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(26, 16, 26, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFDC2626),
        borderRadius: BorderRadius.circular(look.isClassic ? 10 : 22),
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [
          BoxShadow(color: Color(0x99000000), blurRadius: 24, spreadRadius: 2),
        ],
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.hourglass_bottom,
                  color: Colors.white,
                  size: 46,
                ),
                const SizedBox(width: 8),
                Text('¡TIEMPO!', style: style),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Se acabó la ronda',
              style: withFont(
                look.numberFont,
                const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
