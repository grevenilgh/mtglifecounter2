import 'dart:math';

import 'package:flutter/material.dart';
import 'package:mtglifecounter/look.dart';
import 'package:mtglifecounter/round_timer.dart';
import 'package:mtglifecounter/vibration.dart';

/// Lo que ocupa el botón del reloj de ajedrez en cada tema. En el borde
/// antiguo es el trozo de abajo de la caja de texto: el reloj de arena y,
/// debajo, el tiempo.
Size chessClockSize(Look look) => switch (look.theme) {
  AppTheme.original => const Size(64, 64),
  AppTheme.modern => const Size(64, 64),
  AppTheme.classic => const Size(60, 84),
};

/// En qué momento está el reloj de un jugador.
enum _Phase {
  /// Aún no ha empezado nadie.
  idle,

  /// Le toca: su reloj corre.
  run,

  /// Le toca al otro.
  wait,

  /// En pausa desde la barra.
  pause,
}

/// El botón del reloj de ajedrez de un jugador, abajo a la derecha de su
/// panel. Enseña lo que le queda; al pulsarlo se para su reloj y corre el
/// del otro. Al que le toca le sobresale, con «PASAR»; al que espera se le
/// ve hundido. Con poco tiempo se pone ámbar y, si se le acaba, se queda en 0:00
/// en rojo: el reloj se para hasta que pulse para pasar el turno al otro.
///
/// En el borde antiguo es un reloj de arena de madera y latón sobre una placa
/// de latón: de pie corre la arena y tumbado espera.
class ChessClockButton extends StatefulWidget {
  const ChessClockButton({
    super.key,
    required this.timer,
    required this.seat,
    required this.look,
    required this.color,
    this.darkInk = false,
    this.warningEnabled = true,
    this.vibrate = true,
    this.animations = true,
  });

  final RoundTimer timer;
  final Seat seat;
  final Look look;

  /// El color del jugador.
  final Color color;

  /// En el borde antiguo, si va sobre fondo oscuro (la caja de texto oscura o,
  /// sin historial, la ilustración): el tiempo va en tinta clara.
  final bool darkInk;

  final bool warningEnabled;

  /// Un toque corto al pulsar.
  final bool vibrate;

  /// El brillo que late y la arena que cae.
  final bool animations;

  @override
  State<ChessClockButton> createState() => _ChessClockButtonState();
}

class _ChessClockButtonState extends State<ChessClockButton> {
  // Nada late ni brilla a saltos: con un AnimationController que se repetía,
  // el reloj de ajedrez en marcha tenía el móvil a 60 fotogramas por segundo
  // y con tres cuartos del procesador toda la ronda, y un brillo que cambiaba
  // una vez por segundo parpadeaba. Solo cambian el tiempo, el anillo y la
  // arena, con el segundero.

  void _press() {
    if (widget.timer.press(widget.seat) && widget.vibrate) {
      // Un toque corto: se nota que ha pasado el turno.
      vibrate(const Duration(milliseconds: 90));
    }
  }

  _Phase get _phase {
    final timer = widget.timer;
    if (timer.turn == null) return _Phase.idle;
    // Al que tiene el turno se le ha acabado: le sigue tocando (tiene que
    // pulsar para pasarlo), aunque el reloj esté parado.
    if (timer.waitingForPress) {
      return timer.turn == widget.seat ? _Phase.run : _Phase.wait;
    }
    // Se les ha acabado a los dos: los dos esperan, en rojo.
    if (timer.outOfTime(Seat.top) && timer.outOfTime(Seat.bottom)) {
      return _Phase.wait;
    }
    if (!timer.running) return _Phase.pause;
    return timer.turn == widget.seat ? _Phase.run : _Phase.wait;
  }

  @override
  Widget build(BuildContext context) {
    final size = chessClockSize(widget.look);
    return ListenableBuilder(
      listenable: widget.timer,
      builder: (context, _) {
        final timer = widget.timer;
        final seat = widget.seat;
        final phase = _phase;
        final left = timer.leftFor(seat);
        final over = phase != _Phase.idle && timer.outOfTime(seat);
        final warn =
            widget.warningEnabled &&
            phase == _Phase.run &&
            timer.warningFor(seat);
        final share = timer.share.inMilliseconds;
        final fraction = share == 0
            ? 0.0
            : (left.inMilliseconds / share).clamp(0.0, 1.0);
        // Solo se anima mientras corre su reloj (sin tiempo no corre).
        final animate =
            widget.animations && phase == _Phase.run && timer.running;
        // La arena baja una raya por segundo (el dibujo se repite cada 3).
        final flow = animate ? (left.inSeconds % 3) / 8 : null;
        final label = formatClock(left);
        final state = switch (phase) {
          _Phase.idle => 'pulsa para que empiece el otro',
          _Phase.run =>
            over ? 'sin tiempo: pulsa para pasar el turno' : 'le toca',
          _Phase.wait => over ? 'sin tiempo' : 'esperando',
          _Phase.pause => 'en pausa',
        };
        final who = seat == Seat.top ? 'de arriba' : 'de abajo';
        final look = widget.look;
        return Semantics(
          button: true,
          label: 'Reloj de ajedrez $who: $label, $state',
          excludeSemantics: true,
          child: GestureDetector(
            onTap: _press,
            behavior: HitTestBehavior.opaque,
            // Tamaño fijo y su propia capa: cada segundo se repinta solo el
            // botón, no el panel.
            child: SizedBox.fromSize(
              size: size,
              child: RepaintBoundary(
                child: look.isClassic
                    ? _Hourglass(
                        phase: phase,
                        over: over,
                        warn: warn,
                        fraction: over ? 0 : fraction,
                        label: label,
                        flow: flow,
                        darkInk: widget.darkInk,
                      )
                    : _RoundButton(
                        look: look,
                        color: widget.color,
                        phase: phase,
                        over: over,
                        warn: warn,
                        fraction: fraction,
                        label: label,
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// El botón de los temas Original, Cristal y Tarjetas: un pulsador redondo
/// con el tiempo dentro y un anillo alrededor que se vacía segundo a
/// segundo. Al que le toca le sobresale, con «PASAR»; el que espera está
/// hundido y apagado.
class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.look,
    required this.color,
    required this.phase,
    required this.over,
    required this.warn,
    required this.fraction,
    required this.label,
  });

  final Look look;
  final Color color;
  final _Phase phase;
  final bool over;
  final bool warn;
  final double fraction;
  final String label;

  static const _amber = Color(0xFFF59E0B);
  static const _amberInk = Color(0xFF1F1403);
  static const _red = Color(0xFFDC2626);

  @override
  Widget build(BuildContext context) {
    final running = phase == _Phase.run;
    final idle = phase == _Phase.idle;
    // Sobresale el que tiene que pulsar: el del turno y, sin empezar, los
    // dos (cualquiera puede arrancar el reloj del otro).
    final raised = running || idle;
    Gradient face;
    Color ink;
    Color ring;
    Border? edge;
    if (over && running) {
      face = const RadialGradient(colors: [Color(0xFFF05252), _red]);
      ink = Colors.white;
      ring = Colors.transparent;
    } else if (over) {
      face = const RadialGradient(
        colors: [Color(0xB3B91C1C), Color(0xB3B91C1C)],
      );
      ink = const Color(0xFFFFE4E4);
      ring = Colors.transparent;
      edge = Border.all(color: const Color(0xFFF87171), width: 1.5);
    } else if (warn) {
      face = const RadialGradient(
        center: Alignment(-0.3, -0.4),
        colors: [Color(0xFFFFD27A), _amber],
      );
      ink = _amberInk;
      ring = _amber;
    } else if (running) {
      if (look.theme == AppTheme.original) {
        face = const RadialGradient(
          center: Alignment(-0.3, -0.4),
          colors: [Colors.white, Color(0xFFE6E0D2)],
        );
        ink = const Color(0xFF141414);
      } else {
        // Cristal y Tarjetas: del color del jugador.
        face = RadialGradient(
          center: const Alignment(-0.3, -0.4),
          colors: [shade(color, 1.9), shade(color, 0.85)],
        );
        ink = Colors.white;
      }
      ring = Colors.white;
    } else {
      // Sin empezar, esperando o en pausa: apagado.
      face = RadialGradient(
        colors: [
          Colors.black.withValues(alpha: 0.28),
          Colors.black.withValues(alpha: look.isGlass ? 0.5 : 0.42),
        ],
      );
      ink = Colors.white.withValues(alpha: idle ? 1 : 0.62);
      ring = Colors.white.withValues(alpha: idle ? 0.6 : 0.4);
      if (idle) edge = Border.all(color: Colors.white.withValues(alpha: 0.6));
    }
    final IconData? icon = switch (phase) {
      _ when over => Icons.flag_rounded,
      _Phase.idle => Icons.play_arrow_rounded,
      _Phase.pause => Icons.pause_rounded,
      _ => null,
    };
    final showPass = running && !over;
    return Transform.translate(
      // El que espera está hundido, como el botón pulsado de un reloj de
      // ajedrez de verdad.
      offset: Offset(0, raised ? 0 : 4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: raised
              ? const [
                  BoxShadow(color: Color(0x80000000), offset: Offset(0, 5)),
                  BoxShadow(
                    color: Color(0x70000000),
                    blurRadius: 14,
                    offset: Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: CustomPaint(
          painter: _RingPainter(
            fraction: over ? 0 : fraction,
            color: ring,
            track: Colors.white.withValues(alpha: 0.14),
          ),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: face,
                border: edge,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label,
                        maxLines: 1,
                        textScaler: TextScaler.noScaling,
                        style: TextStyle(
                          color: ink,
                          fontSize: 16,
                          height: 1.05,
                          fontWeight: FontWeight.w900,
                          fontFeatures: kNumberFeatures,
                        ),
                      ),
                    ),
                    if (showPass)
                      Text(
                        'PASAR',
                        maxLines: 1,
                        textScaler: TextScaler.noScaling,
                        style: TextStyle(
                          color: ink,
                          fontSize: 7.5,
                          height: 1.2,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      )
                    else if (icon != null)
                      Icon(icon, size: 12, color: ink),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// El anillo de lo que le queda: la pista y, encima, el arco desde arriba en
/// el sentido de las agujas del reloj.
class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.fraction,
    required this.color,
    required this.track,
  });

  final double fraction;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(2.5);
    final pen = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;
    canvas.drawOval(rect, pen..color = track);
    if (fraction > 0 && color.a > 0) {
      canvas.drawArc(
        rect,
        -pi / 2,
        2 * pi * fraction,
        false,
        pen
          ..color = color
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction || old.color != color || old.track != track;
}

/// El botón del borde antiguo: un reloj de arena de madera y latón sobre una
/// placa de latón que sobresale como un pulsador, con el tiempo debajo. De pie la arena cae; tumbado (esperando o en pausa) se
/// para.
class _Hourglass extends StatelessWidget {
  const _Hourglass({
    required this.phase,
    required this.over,
    required this.warn,
    required this.fraction,
    required this.label,
    required this.flow,
    required this.darkInk,
  });

  final _Phase phase;
  final bool over;
  final bool warn;

  /// La arena que queda arriba, de 0 a 1.
  final double fraction;
  final String label;

  /// Por dónde va la arena que cae, de 0 a 1; null si no cae.
  final double? flow;
  final bool darkInk;

  /// El ancho del botón y el lado de la placa de latón.
  static const double _width = 60;
  static const double _plate = 48;

  @override
  Widget build(BuildContext context) {
    final lying = phase == _Phase.wait || phase == _Phase.pause;
    final running = phase == _Phase.run;
    final Color? glowColor = over
        ? const Color(0xFFDC2626)
        : warn
        ? const Color(0xFFF59E0B)
        : running
        ? const Color(0xFFFFD678)
        : null;
    final Color ink;
    if (over) {
      ink = darkInk ? const Color(0xFFFF8A80) : const Color(0xFFA31515);
    } else if (warn) {
      ink = darkInk ? const Color(0xFFFBBF24) : const Color(0xFF8A4B00);
    } else {
      final base = darkInk ? const Color(0xFFFFF6E4) : const Color(0xFF14110E);
      ink = lying ? base.withValues(alpha: 0.62) : base;
    }
    Widget glass = CustomPaint(
      size: const Size(26, 44),
      painter: _HourglassPainter(
        fraction: fraction,
        flow: flow,
        glow: glowColor?.withValues(alpha: 0.8),
      ),
    );
    if (lying) {
      // Apagado: menos color y menos luz.
      glass = ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          0.55, 0.3, 0.05, 0, 0, //
          0.15, 0.65, 0.05, 0, 0, //
          0.15, 0.3, 0.4, 0, 0, //
          0, 0, 0, 1, 0, //
        ]),
        child: glass,
      );
    }
    // La placa de latón sobresale para el que tiene que pulsar (el del turno
    // y, sin empezar, los dos) y se hunde para el que espera.
    final raised = running || phase == _Phase.idle;
    TextStyle vollkorn(double size, {double spacing = 0}) => withFont(
      'Vollkorn',
      TextStyle(
        color: ink,
        fontSize: size,
        height: 1.15,
        fontWeight: FontWeight.w800,
        letterSpacing: spacing,
        fontFeatures: kNumberFeatures,
        shadows: darkInk
            ? const [Shadow(color: Color(0xE6000000), blurRadius: 3)]
            : null,
      ),
    );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: raised ? 0 : 4,
          left: (_width - _plate) / 2,
          width: _plate,
          height: _plate,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: raised
                    ? const [
                        Color(0xFFF6DC8F),
                        Color(0xFFB8862E),
                        Color(0xFF7A5418),
                      ]
                    : const [
                        Color(0xFFBFAE84),
                        Color(0xFF8C7346),
                        Color(0xFF5C4A2A),
                      ],
                stops: const [0, 0.55, 1],
              ),
              border: Border.all(
                color: raised
                    ? const Color(0xFFFFF0C2)
                    : const Color(0xFF6B5A3A),
                width: 1,
              ),
              boxShadow: raised
                  ? const [
                      BoxShadow(color: Color(0xFF3A2508), offset: Offset(0, 4)),
                      BoxShadow(
                        color: Color(0x66000000),
                        blurRadius: 10,
                        offset: Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Transform.scale(
                scale: 0.82,
                child: AnimatedRotation(
                  turns: lying ? 0.25 : 0,
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutBack,
                  child: glass,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: _plate + 5,
          height: 19,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              textScaler: TextScaler.noScaling,
              style: vollkorn(16),
            ),
          ),
        ),
        if (running && !over)
          Positioned(
            left: 0,
            right: 0,
            top: _plate + 23,
            height: 11,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'PASAR',
                maxLines: 1,
                textScaler: TextScaler.noScaling,
                style: vollkorn(9, spacing: 1),
              ),
            ),
          ),
      ],
    );
  }
}

/// El reloj de arena, dibujado en una caja de 26 × 44: tapas de madera,
/// columnas de latón, el cristal y la arena dorada.
class _HourglassPainter extends CustomPainter {
  _HourglassPainter({required this.fraction, this.flow, this.glow});

  final double fraction;
  final double? flow;
  final Color? glow;

  static final Path _glass = Path()
    ..moveTo(6, 4.5)
    ..cubicTo(6, 13, 11.5, 17.5, 12.4, 22)
    ..cubicTo(11.5, 26.5, 6, 31, 6, 39.5)
    ..lineTo(20, 39.5)
    ..cubicTo(20, 31, 14.5, 26.5, 13.6, 22)
    ..cubicTo(14.5, 17.5, 20, 13, 20, 4.5)
    ..close();

  static final Path _top = Path()
    ..moveTo(6, 4.5)
    ..cubicTo(6, 13, 11.5, 17.5, 12.4, 22)
    ..lineTo(13.6, 22)
    ..cubicTo(14.5, 17.5, 20, 13, 20, 4.5)
    ..close();

  static final Path _bottom = Path()
    ..moveTo(12.4, 22)
    ..cubicTo(11.5, 26.5, 6, 31, 6, 39.5)
    ..lineTo(20, 39.5)
    ..cubicTo(20, 31, 14.5, 26.5, 13.6, 22)
    ..close();

  static const _sand = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFF4D58A), Color(0xFFC08B2C)],
  );

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 26, size.height / 44);
    final glow = this.glow;
    if (glow != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(1, 2, 24, 40),
          const Radius.circular(6),
        ),
        Paint()
          ..color = glow
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }
    // Las columnas de latón.
    final brass = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF7D5A17), Color(0xFFF3D77A), Color(0xFF8A6420)],
      ).createShader(const Rect.fromLTWH(1.4, 0, 2.2, 1));
    canvas.drawRect(const Rect.fromLTWH(1.4, 3.5, 2.2, 37), brass);
    brass.shader = const LinearGradient(
      colors: [Color(0xFF7D5A17), Color(0xFFF3D77A), Color(0xFF8A6420)],
    ).createShader(const Rect.fromLTWH(22.4, 0, 2.2, 1));
    canvas.drawRect(const Rect.fromLTWH(22.4, 3.5, 2.2, 37), brass);
    // El cristal y la arena.
    canvas.drawPath(_glass, Paint()..color = const Color(0x59E1F0F5));
    final sand = Paint()
      ..shader = _sand.createShader(const Rect.fromLTWH(0, 4.5, 26, 35));
    final topHeight = 17 * fraction;
    canvas.save();
    canvas.clipPath(_top);
    canvas.drawRect(Rect.fromLTWH(0, 22 - topHeight, 26, topHeight), sand);
    canvas.restore();
    final bottomHeight = 17 * (1 - fraction);
    final bottomTop = 39.5 - bottomHeight;
    canvas.save();
    canvas.clipPath(_bottom);
    canvas.drawRect(Rect.fromLTWH(0, bottomTop, 26, bottomHeight), sand);
    canvas.restore();
    // El chorrito que cae, a trazos que bajan.
    final flow = this.flow;
    if (flow != null && fraction > 0) {
      final stream = Paint()
        ..color = const Color(0xFFE9C46A)
        ..strokeWidth = 1;
      const dash = 1.5;
      var y = 22 - dash * 2 + (flow * 8 % (dash * 2));
      while (y < bottomTop) {
        final from = max(y, 22.0);
        final to = min(y + dash, bottomTop);
        if (to > from) {
          canvas.drawLine(Offset(13, from), Offset(13, to), stream);
        }
        y += dash * 2;
      }
    }
    canvas.drawPath(
      _glass,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6
        ..color = const Color(0xCCFFFFFF),
    );
    // Las tapas de madera.
    final wood = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF9A6634), Color(0xFF4A2A10)],
      ).createShader(const Rect.fromLTWH(0, 0, 26, 4.2));
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.4
      ..color = const Color(0xFF2A1606);
    for (final top in [0.0, 39.8]) {
      final cap = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, top, 26, 4.2),
        const Radius.circular(1.2),
      );
      wood.shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF9A6634), Color(0xFF4A2A10)],
      ).createShader(Rect.fromLTWH(0, top, 26, 4.2));
      canvas.drawRRect(cap, wood);
      canvas.drawRRect(cap, edge);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_HourglassPainter old) =>
      old.fraction != fraction || old.flow != flow || old.glow != glow;
}

/// El icono del reloj de ajedrez: la caja con las dos esferas y los dos
/// botones, uno levantado y otro hundido. Va en el reloj de la barra.
class ChessClockIcon extends StatelessWidget {
  const ChessClockIcon({super.key, required this.color, this.size = 18});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _ChessClockIconPainter(color),
    );
  }
}

class _ChessClockIconPainter extends CustomPainter {
  _ChessClockIconPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final pen = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(2, 8, 20, 13),
        const Radius.circular(2.5),
      ),
      pen,
    );
    canvas.drawCircle(const Offset(8, 14.5), 3, pen);
    canvas.drawCircle(const Offset(16, 14.5), 3, pen);
    canvas.drawPath(
      Path()
        ..moveTo(6.5, 8)
        ..lineTo(6.5, 4.5)
        ..lineTo(9.5, 4.5)
        ..lineTo(9.5, 8)
        ..moveTo(15, 8)
        ..lineTo(15, 6.5)
        ..lineTo(18, 6.5)
        ..lineTo(18, 8),
      pen,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ChessClockIconPainter old) => old.color != color;
}
