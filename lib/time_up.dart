import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:mtglifecounter/look.dart';

/// Los avisos de fin de ronda que se pueden elegir en Ajustes → Diseño.
///
/// Cada skin lleva el suyo ([defaultFor]); con la personalizada se puede
/// elegir cualquiera, también los de las comunidades ([skinId]).
enum TimeUpStyle {
  stamp('Acta del juez'),
  arcade('Recreativa'),
  crt('Tele antigua'),
  bell('El gong del ring'),
  suspend('Contadores de tiempo'),
  alicante('El esqueleto', skinId: 'alicante'),
  fullTapped('Tapeados', skinId: 'fulltapped'),
  oldSchool('Duelo Chaos Orb', skinId: 'oldschool');

  const TimeUpStyle(this.label, {this.skinId});

  final String label;

  /// La skin de la comunidad a la que pertenece, o null si es genérico.
  final String? skinId;

  /// El de cada skin: el de su comunidad si lo tiene y, si no, el sello. En
  /// la personalizada, el que sale mientras no se elige otro.
  static TimeUpStyle defaultFor(String skin) =>
      values.where((s) => s.skinId == skin).firstOrNull ?? stamp;

  static TimeUpStyle? fromName(String? name) =>
      values.where((s) => s.name == name).firstOrNull;
}

/// Cuándo vibra el móvil al acabar la ronda: tres veces de [buzzLength]. El
/// aviso sale con la primera, da un golpe con cada una de las otras dos y se
/// va en cuanto deja de vibrar.
const List<Duration> kTimeUpBuzzes = [
  Duration.zero,
  Duration(milliseconds: 800),
  Duration(milliseconds: 1600),
];
const Duration kTimeUpBuzzLength = Duration(milliseconds: 400);

// En tanto por uno de lo que dura el aviso.
const double _buzz2 = 1 / 3;
const double _buzz3 = 2 / 3;
const double _leave = 5 / 6;

/// Cuánto ha avanzado [t] entre [a] y [b], de 0 a 1.
double _seg(double t, double a, double b) => ((t - a) / (b - a)).clamp(0, 1);

/// El golpe de la segunda y la tercera vibración: sube a 1 y vuelve a 0 en
/// una décima del aviso.
double _kick(double t) {
  for (final at in const [_buzz2, _buzz3]) {
    final x = (t - at) / 0.1;
    if (x >= 0 && x <= 1) return sin(x * pi);
  }
  return 0;
}

/// Una escena de aviso con el golpe de cada vibración.
Widget _withKick(double t, Widget child, {double turn = 0.035}) {
  final k = _kick(t);
  return Transform.rotate(
    angle: (t < 0.5 ? -turn : turn) * k,
    child: Transform.scale(scale: 1 + 0.09 * k, child: child),
  );
}

TextStyle _pixel(double size, Color color, {List<Shadow>? shadows}) => withFont(
  'Press Start 2P',
  TextStyle(fontSize: size, color: color, height: 1.3, shadows: shadows),
);

/// El aviso de «¡Tiempo!» al acabar la ronda, a pantalla completa: una
/// escena para cada jugador (la de arriba girada si su panel lo está). Sale
/// mientras vibra ([kTimeUpBuzzes]) y se va solo; tocarlo lo quita antes.
/// Con [stays] no se va solo: se queda quieto, entero, hasta que se toca.
///
/// Dura [duration] y se acaba: nada de animaciones sin fin en la pantalla
/// principal, que la app pasa el día encendida en la mesa. Sin animaciones
/// (Ajustes), sale quieto el mismo tiempo. Quedándose en pantalla tampoco
/// pide fotogramas: la animación se para en la escena entera.
class TimeUpOverlay extends StatefulWidget {
  const TimeUpOverlay({
    super.key,
    required this.look,
    required this.flipTop,
    required this.animate,
    required this.onDone,
    this.style = TimeUpStyle.stamp,
    this.lives,
    this.roundMinutes,
    this.stays = false,
  });

  final TimeUpStyle style;
  final Look look;

  /// Si se queda en pantalla hasta que se toca ([AppSettings.timeUpStays]).
  final bool stays;

  /// Si el panel de arriba está girado hacia el otro lado de la mesa.
  final bool flipTop;
  final bool animate;
  final VoidCallback onDone;

  /// Las vidas de arriba y de abajo, para los avisos que las enseñan.
  final (int, int)? lives;

  /// Lo que duraba la ronda, en minutos, para los avisos que lo enseñan.
  final int? roundMinutes;

  static const Duration duration = Duration(milliseconds: 2400);

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
      if (widget.stays) {
        // Hasta la escena entera, y ahí se para hasta que lo toquen.
        _c.animateTo(_leave);
      } else {
        _c.forward().whenComplete(_finish);
      }
    } else {
      // Quieto, entero, y se quita a su hora (o al tocarlo).
      _c.value = TimeUpScene.still;
      if (!widget.stays) _still = Timer(TimeUpOverlay.duration, _finish);
    }
  }

  void _onTap() {
    // Si se había quedado esperando, se va con su salida; si no, al momento.
    if (widget.stays &&
        widget.animate &&
        !_c.isAnimating &&
        _c.value >= _leave) {
      _c.forward().whenComplete(_finish);
      return;
    }
    _finish();
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
    final lives = widget.lives;
    return Semantics(
      liveRegion: true,
      label: 'Se acabó el tiempo de la ronda',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _onTap,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            // Sin animaciones se queda quieto y entero, sin desvanecerse.
            final t = widget.animate ? _c.value : TimeUpScene.still;
            final fadeIn = Curves.easeOut.transform(_seg(t, 0, 0.05));
            final fadeOut = Curves.easeIn.transform(_seg(t, _leave, 1));
            Widget half(bool top) => Expanded(
              child: ClipRect(
                child: Transform.rotate(
                  angle: top && widget.flipTop ? pi : 0,
                  child: TimeUpScene(
                    style: widget.style,
                    t: t,
                    look: widget.look,
                    roundMinutes: widget.roundMinutes,
                    lives: lives == null
                        ? null
                        : top
                        ? lives
                        : (lives.$2, lives.$1),
                  ),
                ),
              ),
            );
            return ColoredBox(
              color: Colors.black.withValues(alpha: 0.6 * fadeIn),
              child: Opacity(
                opacity: 1 - fadeOut,
                child: Column(children: [half(true), half(false)]),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Lo que se ve en la mitad de un jugador en el momento [t] (de 0 a 1) del
/// aviso. Se dibuja en un cuadro de [size] y se escala al hueco: así es igual
/// en un móvil, en una tableta y en la miniatura de Ajustes.
class TimeUpScene extends StatelessWidget {
  const TimeUpScene({
    super.key,
    required this.style,
    required this.t,
    required this.look,
    this.lives,
    this.roundMinutes,
  });

  final TimeUpStyle style;
  final double t;
  final Look look;

  /// Las vidas de este jugador y las del otro.
  final (int, int)? lives;

  /// Lo que duraba la ronda, en minutos (sin él, los 50 de siempre).
  final int? roundMinutes;

  /// El lado del cuadro en el que se dibuja cada escena.
  static const double size = 360;

  /// El momento en que la escena está entera: lo que se ve sin animaciones
  /// y en la miniatura quieta.
  static const double still = 0.8;

  @override
  Widget build(BuildContext context) {
    final scene = switch (style) {
      TimeUpStyle.stamp => _StampScene(t: t, lives: lives),
      TimeUpStyle.arcade => _ArcadeScene(t: t, lives: lives),
      TimeUpStyle.crt => _CrtScene(t: t),
      TimeUpStyle.bell => _BellScene(t: t),
      TimeUpStyle.suspend => _SuspendScene(t: t, look: look),
      TimeUpStyle.alicante => _AlicanteScene(t: t),
      TimeUpStyle.fullTapped => _FullTappedScene(
        t: t,
        minutes: roundMinutes ?? 50,
      ),
      TimeUpStyle.oldSchool => _OldSchoolScene(t: t, look: look),
    };
    // Es un dibujo: la letra grande del sistema no lo agranda (se escala
    // entero al hueco).
    return MediaQuery.withNoTextScaling(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: FittedBox(
          child: SizedBox.square(dimension: size, child: scene),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// El acta del juez: entra la hoja de resultado de la mesa y se apuntan a mano
// las vidas de cada uno; con la segunda vibración el juez estampa «RONDA
// TERMINADA» y con la tercera se escribe «+5 turnos extra» y firma.

class _StampScene extends StatelessWidget {
  const _StampScene({required this.t, this.lives});

  final double t;

  /// Las vidas de este jugador y las del otro.
  final (int, int)? lives;

  // Se dibuja en un cuadro de 220 y se escala al de la escena.
  static const double _box = 220;
  static const double _deg = pi / 180;
  static const Color _paper = Color(0xFFF4EEDF);
  static const Color _pen = Color(0xFF1D3F9E);
  static const Color _print = Color(0xFF7A6A52);

  @override
  Widget build(BuildContext context) {
    // 1.ª vibración: entra la hoja y se apuntan las vidas.
    final enter = const Cubic(0.2, 0.8, 0.3, 1.1).transform(_seg(t, 0, 0.12));
    final writeMine = _seg(t, 0.12, 0.2);
    final writeOther = _seg(t, 0.19, 0.27);
    // 2.ª: el sello cae de golpe y la hoja da un respingo.
    final stamp = _seg(t, _buzz2, 0.375);
    final stampScale = _keys(t, const [
      (_buzz2, 2.6),
      (0.375, 0.95),
      (0.41, 1),
    ]);
    final jumpX = _keys(t, const [
      (0.375, 0),
      (0.39, 3),
      (0.41, -2),
      (0.43, 0),
    ]);
    final jumpY = _keys(t, const [
      (0.375, 0),
      (0.39, 2),
      (0.41, -1),
      (0.43, 0),
    ]);
    final turn = t < 0.12
        ? 10 - 13 * enter
        : _keys(t, const [(0.375, -3), (0.39, -2), (0.41, -3.5), (0.43, -3)]);
    // 3.ª: la nota y la firma.
    final note = _seg(t, _buzz3, 0.75);
    final sign = _seg(t, 0.72, 0.8);

    final lives = this.lives;
    TextStyle print(double size, {Color color = _print}) => withFont(
      'Inter',
      TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w600,
        letterSpacing: size < 8 ? 1.2 : 0,
        color: color,
        height: 1,
      ),
    );
    final hand = withFont(
      'Caveat',
      const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: _pen,
        height: 1,
      ),
    );
    Widget row(String who, int? life, double write) => Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(who, style: print(9, color: const Color(0xFF555555))),
        _Reveal(
          f: write,
          child: Text(life == null ? '—' : '$life', style: hand),
        ),
      ],
    );

    final slip = Container(
      width: 192,
      height: 170,
      decoration: BoxDecoration(
        color: _paper,
        borderRadius: BorderRadius.circular(3),
        boxShadow: const [
          BoxShadow(
            color: Color(0xCC000000),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: CustomPaint(
        painter: const _RuledPainter(),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 10,
              right: 10,
              top: 7,
              child: Container(
                padding: const EdgeInsets.only(bottom: 4),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFB9A988))),
                ),
                // Con letras anchas, cada texto se encoge en vez de salirse.
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (final (i, text) in const [
                      'HOJA DE RESULTADO',
                      'MESA 69',
                    ].indexed) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(text, style: print(7)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Positioned(
              left: 10,
              right: 10,
              top: 26,
              child: row('Tú', lives?.$1, writeMine),
            ),
            Positioned(
              left: 10,
              right: 10,
              top: 48,
              child: row('Rival', lives?.$2, writeOther),
            ),
            Positioned(
              left: 12,
              top: 137,
              child: Transform.rotate(
                angle: -2 * _deg,
                child: _Reveal(
                  f: note,
                  child: Text(
                    '+5 turnos extra',
                    style: hand.copyWith(fontSize: 17),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.only(top: 3),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFF9C8F78))),
                ),
                child: Text(
                  'FIRMA DEL JUEZ',
                  style: print(6.5, color: const Color(0xFF8A7A62)),
                ),
              ),
            ),
            Positioned(
              right: 8,
              bottom: 12,
              width: 50,
              height: 20,
              child: CustomPaint(painter: _SignaturePainter(sign)),
            ),
          ],
        ),
      ),
    );

    return FittedBox(
      child: SizedBox(
        width: _box,
        height: _box,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 14,
              top: 12,
              child: Transform.translate(
                offset: Offset(jumpX, 260 * (1 - enter) + jumpY),
                child: Transform.rotate(angle: turn * _deg, child: slip),
              ),
            ),
            if (stamp > 0)
              Positioned(
                left: 30,
                top: 94,
                width: 160,
                height: 44,
                child: Opacity(
                  opacity: stamp,
                  child: Transform.rotate(
                    angle: -6 * _deg,
                    child: Transform.scale(
                      scale: stampScale,
                      child: const CustomPaint(
                        painter: _InkStampPainter('RONDA TERMINADA'),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Enseña [child] de izquierda a derecha hasta [f] (de 0 a 1), como si se
/// escribiera, sin cambiar lo que ocupa.
class _Reveal extends StatelessWidget {
  const _Reveal({required this.f, required this.child});

  final double f;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (f >= 1) return child;
    if (f <= 0) return Opacity(opacity: 0, child: child);
    return ClipRect(clipper: _LeftClipper(f), child: child);
  }
}

class _LeftClipper extends CustomClipper<Rect> {
  const _LeftClipper(this.f);

  final double f;

  // Los rasgos de la letra a mano se salen un poco de su caja.
  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(-10, -20, -10 + (size.width + 20) * f, size.height + 20);

  @override
  bool shouldReclip(_LeftClipper old) => old.f != f;
}

/// Las rayas azules de la hoja.
class _RuledPainter extends CustomPainter {
  const _RuledPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = const Color(0xFFC9D3E6)
      ..strokeWidth = 1;
    for (var y = 43.5; y < size.height - 24; y += 14) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
  }

  @override
  bool shouldRepaint(_RuledPainter old) => false;
}

/// La firma del juez, que se va trazando hasta [progress] (de 0 a 1).
class _SignaturePainter extends CustomPainter {
  const _SignaturePainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    // Dibujada en 70 × 26.
    canvas.scale(size.width / 70, size.height / 26);
    final path = Path()
      ..moveTo(2, 18)
      ..cubicTo(8, 4, 12, 4, 12, 14)
      ..cubicTo(12, 22, 18, 6, 22, 6)
      ..cubicTo(26, 6, 22, 20, 28, 18)
      ..cubicTo(34, 16, 34, 8, 40, 10)
      ..cubicTo(46, 12, 40, 22, 48, 18)
      ..cubicTo(54, 15, 58, 12, 68, 14);
    final pen = Paint()
      ..color = _StampScene._pen
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final metric = path.computeMetrics().first;
    canvas.drawPath(metric.extractPath(0, metric.length * progress), pen);
  }

  @override
  bool shouldRepaint(_SignaturePainter old) => old.progress != progress;
}

/// Un sello de tinta: doble marco y el texto, con los huecos y las motas de
/// un tampón de verdad (siempre los mismos).
class _InkStampPainter extends CustomPainter {
  const _InkStampPainter(this.label);

  final String label;

  static const Color _ink = Color(0xFFE0262F);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    canvas.saveLayer((Offset.zero & size).inflate(4), Paint());
    final ink = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(3, 3, w - 6, h - 6),
        const Radius.circular(7),
      ),
      ink,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(11, 11, w - 22, h - 22),
        const Radius.circular(3),
      ),
      ink..strokeWidth = 1.6,
    );
    // El texto, estirado a lo ancho del marco de dentro.
    final text = TextPainter(
      text: TextSpan(
        text: label,
        style: withFont(
          'Barlow Condensed',
          const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: _ink,
            height: 1,
          ),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas
      ..save()
      ..translate(w / 2, h / 2)
      ..scale((w - 36) / text.width, 1);
    text.paint(canvas, Offset(-text.width / 2, -text.height / 2));
    canvas.restore();
    text.dispose();
    // Los huecos donde no cogió tinta.
    final rnd = Random(7);
    final hole = Paint()..blendMode = BlendMode.dstOut;
    for (var i = 0; i < 170; i++) {
      final r = 0.4 + pow(rnd.nextDouble(), 3) * 2.2;
      hole.color = Color.fromRGBO(0, 0, 0, 0.5 + rnd.nextDouble() * 0.5);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(rnd.nextDouble() * w, rnd.nextDouble() * h),
          width: r * 2 * (0.6 + rnd.nextDouble() * 0.8),
          height: r * 2,
        ),
        hole,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_InkStampPainter old) => old.label != label;
}

// ---------------------------------------------------------------------------
// Recreativa: una pantalla de 8 bits, todo a saltos.

class _ArcadeScene extends StatelessWidget {
  const _ArcadeScene({required this.t, this.lives});

  final double t;
  final (int, int)? lives;

  @override
  Widget build(BuildContext context) {
    // «TIME UP!» cae a saltos, como en las máquinas.
    const steps = [3.0, 2.2, 1.5, 1.1];
    final i = (t / 0.03).floor();
    final scale = i < steps.length ? steps[i] : 1.0;
    // «+5 TURNOS EXTRA» parpadea, como el «continue» de las máquinas, con las otras dos vibraciones.
    final blink = (t >= _buzz2 && t < 0.5) || t >= _buzz3;
    final lives = this.lives;
    return Stack(
      fit: StackFit.expand,
      children: [
        const CustomPaint(painter: _ScanlinesPainter(Color(0x33000000))),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Transform.scale(
              scale: scale,
              child: Text(
                'TIME\nUP!',
                textAlign: TextAlign.center,
                style: _pixel(
                  56,
                  const Color(0xFFFFD23F),
                  shadows: const [
                    Shadow(offset: Offset(4, 4), color: Color(0xFFD6336C)),
                    Shadow(offset: Offset(8, 8), color: Color(0xFF2B1A5A)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
            Opacity(
              opacity: t >= 0.15 ? 1 : 0,
              child: Text(
                lives == null
                    ? 'RONDA TERMINADA'
                    : 'TU ${lives.$1}   RIVAL ${lives.$2}',
                style: _pixel(15, const Color(0xFF7CE0FF)),
              ),
            ),
            const SizedBox(height: 22),
            Opacity(
              opacity: blink ? 1 : 0,
              child: Text('+5 TURNOS EXTRA', style: _pixel(14, Colors.white)),
            ),
          ],
        ),
      ],
    );
  }
}

/// Las rayas de las pantallas de tubo.
class _ScanlinesPainter extends CustomPainter {
  const _ScanlinesPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5;
    for (var y = 1.0; y < size.height; y += 4) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_ScanlinesPainter old) => old.color != color;
}

// ---------------------------------------------------------------------------
// Tele antigua: se enciende con la raya de luz, tiembla con cada vibración y
// se apaga hasta un punto.

class _CrtScene extends StatelessWidget {
  const _CrtScene({required this.t});

  final double t;

  @override
  Widget build(BuildContext context) {
    // Encendido: una raya que se abre. Apagado: se cierra en raya y luego en
    // punto.
    double sy = 1;
    double sx = 1;
    if (t < 0.05) {
      sy = 0.01;
    } else if (t < 0.11) {
      sy = 0.01 + 0.99 * _seg(t, 0.05, 0.11);
    } else if (t > _leave) {
      sy = 1 - 0.99 * _seg(t, _leave, 0.91);
      sx = 1 - _seg(t, 0.91, 1);
    }
    final flash = t < 0.11
        ? 0.85 * (1 - _seg(t, 0, 0.11))
        : t > _leave
        ? 0.85 * _seg(t, _leave, 0.91)
        : 0.0;
    // Interferencias con la segunda y la tercera vibración.
    double glitch(double a, double b) =>
        t >= a && t <= b ? sin(_seg(t, a, b) * pi) : 0;
    final g = max(glitch(0.34, 0.41), glitch(0.675, 0.745));
    final dx = sin(t * 260) * 6 * g;
    final glow = Shadow(
      color: const Color(0xFF4DFF9A),
      blurRadius: 8 * (1 - g),
    );
    final split = g > 0
        ? [
            Shadow(color: const Color(0xFFFF2A6A), offset: Offset(3 * g, 0)),
            Shadow(color: const Color(0xFF2AD4FF), offset: Offset(-3 * g, 0)),
          ]
        : <Shadow>[];
    final screen = ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [Color(0xFF1E4A33), Color(0xFF07120C)],
                radius: 0.9,
              ),
            ),
          ),
          Transform.translate(
            offset: Offset(dx, 0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'FIN DE\nRONDA',
                  textAlign: TextAlign.center,
                  style: _pixel(
                    28,
                    const Color(0xFFB6FFCF),
                    shadows: [glow, ...split],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  '0:00',
                  style: _pixel(
                    30,
                    const Color(0xFFFF6A5A),
                    shadows: [
                      const Shadow(color: Color(0xFFFF3A2A), blurRadius: 8),
                      ...split,
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '+5 TURNOS EXTRA',
                  style: _pixel(
                    13,
                    const Color(0xFFB6FFCF),
                    shadows: [glow, ...split],
                  ),
                ),
              ],
            ),
          ),
          const CustomPaint(painter: _ScanlinesPainter(Color(0x55000000))),
          // Viñeta del cristal abombado.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [Color(0x00000000), Color(0x99000000)],
                stops: [0.6, 1],
              ),
            ),
          ),
          if (flash > 0)
            ColoredBox(color: Colors.white.withValues(alpha: flash)),
        ],
      ),
    );
    return Center(
      child: Container(
        width: 330,
        height: 250,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF2B2520),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: const Color(0xFF453C33), width: 2),
          boxShadow: const [
            BoxShadow(color: Color(0xCC000000), blurRadius: 24),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.diagonal3Values(sx, sy, 1),
                  child: screen,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Los mandos.
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final size in const [30.0, 22.0]) ...[
                  Container(
                    width: size,
                    height: size,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        center: Alignment(-0.3, -0.3),
                        colors: [Color(0xFF8A7F72), Color(0xFF3A332C)],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                for (var i = 0; i < 4; i++)
                  Container(
                    width: 26,
                    height: 3,
                    margin: const EdgeInsets.only(bottom: 4),
                    color: const Color(0xFF1C1814),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// El gong del ring: la campana de boxeo de latón en su tabla. Con cada
// vibración el martillo la golpea, tiembla, sale una onda y un «¡DING!» de
// cómic; con la tercera entra una banda roja de cartel de combate.

class _BellScene extends StatelessWidget {
  const _BellScene({required this.t});

  final double t;

  // Se dibuja en un cuadro de 220 y se escala al de la escena.
  static const double _box = 220;
  static const double _deg = pi / 180;
  static const Offset _bellCenter = Offset(110, 80);
  static const double _bellSize = 96;

  /// Cuándo da el martillo: un poco después de empezar cada vibración.
  static const List<double> _hits = [0.03, 0.363, 0.696];

  /// Lo que dura la onda de cada golpe (un cuarto de segundo):
  /// la tercera tiene que acabar antes de que la escena esté entera (0,8),
  /// o con «No se va solo» se quedaba congelada a medio desvanecer.
  static const double _waveLength = 0.1;

  static const Color _yellow = Color(0xFFFFD23F);
  static const Color _red = Color(0xFFC81E1E);

  @override
  Widget build(BuildContext context) {
    final hammer = _keys(t, const [
      (0, -40),
      (0.03, 0),
      (0.09, -40),
      (0.30, -40),
      (0.363, 0),
      (0.42, -40),
      (0.636, -40),
      (0.696, 0),
      (0.76, -40),
    ]);
    // El temblor de la campana, un rato tras cada golpe.
    var shake = Offset.zero;
    for (final hit in _hits) {
      final x = _seg(t, hit, hit + 0.09);
      if (x > 0 && x < 1) {
        shake = Offset(3 * sin(x * pi * 5), sin(x * pi * 4)) * (1 - x);
      }
    }
    final band = _keys(t, const [(0.696, -280), (0.75, 10), (0.79, 0)]);

    return FittedBox(
      child: SizedBox(
        width: _box,
        height: _box,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // La tabla de madera.
            Positioned(
              left: 52,
              top: 16,
              width: 116,
              height: 132,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF6B4526), Color(0xFF3E2614)],
                  ),
                  border: Border.all(color: const Color(0xFF2A180B), width: 3),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0xBB000000),
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
              ),
            ),
            // Las ondas de cada golpe.
            for (final hit in _hits)
              if (t > hit && t < hit + _waveLength)
                _wave(_seg(t, hit, hit + _waveLength)),
            Positioned(
              left: _bellCenter.dx - _bellSize / 2 + shake.dx,
              top: _bellCenter.dy - _bellSize / 2 + shake.dy,
              width: _bellSize,
              height: _bellSize,
              child: const CustomPaint(painter: _GongPainter()),
            ),
            // El martillo, que gira sobre el extremo del mango.
            Positioned(
              left: 24,
              top: 100,
              width: 70,
              height: 60,
              child: Transform.rotate(
                angle: hammer * _deg,
                // El eje, en (6, 50) de los 70 × 60, desde el centro.
                origin: const Offset(6 - 35, 50 - 30),
                child: const CustomPaint(painter: _HammerPainter()),
              ),
            ),
            _ding(const Offset(4, 18), -12, 30, (0.03, 0.07, 0.14, 0.26)),
            _ding(const Offset(150, 24), 10, 30, (0.363, 0.40, 0.47, 0.59)),
            _ding(const Offset(0, 92), -8, 36, (0.695, 0.73, 0.79, 2)),
            if (t > 0.696)
              Positioned(
                left: -14,
                right: -14,
                top: 156,
                height: 50,
                child: Transform.translate(
                  offset: Offset(band, 0),
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.skewY(tan(-4 * _deg)),
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        color: _red,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0xAA000000),
                            blurRadius: 14,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _comic('FIN DE RONDA', 32, letterSpacing: 1),
                            const SizedBox(height: 2),
                            Text(
                              '+5 TURNOS EXTRA',
                              style: withFont(
                                'Barlow Condensed',
                                const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 3,
                                  height: 1,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Una onda que sale de la campana y se pierde.
  Widget _wave(double x) {
    final size = _bellSize * (1 + 1.1 * Curves.easeOut.transform(x));
    return Positioned(
      left: _bellCenter.dx - size / 2,
      top: _bellCenter.dy - size / 2,
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xFFFFD76A).withValues(alpha: 0.95 * (1 - x)),
            width: 3,
          ),
        ),
      ),
    );
  }

  /// Un «¡DING!» de cómic: sale de golpe en [times].$1, crece hasta .$2, se
  /// asienta en .$3 y se va en .$4 (más allá de 1, se queda).
  Widget _ding(
    Offset at,
    double degrees,
    double size,
    (double, double, double, double) times,
  ) {
    final (start, pop, settle, gone) = times;
    if (t < start) return const SizedBox.shrink();
    final scale = _keys(t, [(start, 0.3), (pop, 1.2), (settle, 1)]);
    final opacity = _seg(t, start, pop) * (1 - _seg(t, settle + 0.06, gone));
    if (opacity <= 0) return const SizedBox.shrink();
    return Positioned(
      left: at.dx,
      top: at.dy,
      child: Opacity(
        opacity: opacity,
        child: Transform.rotate(
          angle: degrees * _deg,
          child: Transform.scale(scale: scale, child: _comic('¡DING!', size)),
        ),
      ),
    );
  }

  /// Letras de cómic: amarillas, con el filo negro y la sombra roja.
  static Widget _comic(String text, double size, {double letterSpacing = 0}) {
    final base = withFont(
      'Barlow Condensed',
      TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w800,
        fontStyle: FontStyle.italic,
        letterSpacing: letterSpacing,
        height: 1,
      ),
    );
    return Stack(
      children: [
        Text(
          text,
          maxLines: 1,
          style: base.copyWith(
            shadows: const [Shadow(offset: Offset(3, 3), color: _red)],
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 4
              ..strokeJoin = StrokeJoin.round
              ..color = const Color(0xFF111111),
          ),
        ),
        Text(text, maxLines: 1, style: base.copyWith(color: _yellow)),
      ],
    );
  }
}

/// La campana de latón vista de frente, en 96 × 96.
class _GongPainter extends CustomPainter {
  const _GongPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 96);
    const c = Offset(48, 48);
    canvas.drawCircle(c, 47, Paint()..color = const Color(0xFF3A250C));
    canvas.drawCircle(
      c,
      44,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.24, -0.3),
          radius: 0.75,
          colors: [
            Color(0xFFFFF3C8),
            Color(0xFFE8B84A),
            Color(0xFFA87A24),
            Color(0xFF6E4C12),
          ],
          stops: [0, 0.35, 0.8, 1],
        ).createShader(Rect.fromCircle(center: c, radius: 44)),
    );
    final ring = Paint()..style = PaintingStyle.stroke;
    canvas.drawCircle(
      c,
      33,
      ring
        ..color = const Color(0xFF9A6D1E)
        ..strokeWidth = 2,
    );
    canvas.drawCircle(
      c,
      22,
      ring
        ..color = const Color(0xFFB78A2C)
        ..strokeWidth = 1.5,
    );
    canvas.drawCircle(c, 10, Paint()..color = const Color(0xFFFFF3C8));
    canvas.drawCircle(
      c,
      10,
      ring
        ..color = const Color(0xFF8A6420)
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_GongPainter old) => false;
}

/// El martillo: mango negro y cabeza roja, en 70 × 60.
class _HammerPainter extends CustomPainter {
  const _HammerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(
      const Offset(6, 50),
      const Offset(48, 16),
      Paint()
        ..color = const Color(0xFF2C2C2C)
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(
      const Offset(50, 14),
      10,
      Paint()..color = const Color(0xFFDD2222),
    );
    canvas.drawCircle(
      const Offset(50, 14),
      10,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFF111111),
    );
  }

  @override
  bool shouldRepaint(_HammerPainter old) => false;
}

// ---------------------------------------------------------------------------
// Contadores de tiempo: una carta con el borde antiguo, suspendida con tres
// contadores. Cada vibración quita uno; con el último, se lanza.

class _SuspendScene extends StatelessWidget {
  const _SuspendScene({required this.t, required this.look});

  final double t;
  final Look look;

  @override
  Widget build(BuildContext context) {
    final drop = Curves.easeOutCubic.transform(_seg(t, 0, 0.1));
    final cast = _seg(t, 0.69, 0.76);
    final glow = cast == 0 ? 0.0 : 0.7 + 0.3 * sin(cast * pi);
    const starts = [0.06, 0.35, 0.69];
    const dxs = [-46.0, 0.0, 46.0];
    Widget counter(int i) {
      final x = _seg(t, starts[i], starts[i] + 0.1);
      if (x >= 1) return const SizedBox(width: 30, height: 30);
      final up = _seg(x, 0, 0.35);
      final away = _seg(x, 0.35, 1);
      return Opacity(
        opacity: 1 - away,
        child: Transform.translate(
          offset: Offset(dxs[i] * away, -12 * up - 70 * away),
          child: Transform.rotate(
            angle: 0.7 * away,
            child: Transform.scale(
              scale: 1 + 0.25 * up - 0.75 * away,
              child: const _TimeCounter(),
            ),
          ),
        ),
      );
    }

    return Opacity(
      opacity: drop,
      child: Transform.translate(
        offset: Offset(0, -60 * (1 - drop)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _withKick(
              t,
              Stack(
                clipBehavior: Clip.none,
                children: [
                  _OldRoundCard(glow: glow),
                  // Los contadores, sobre la ilustración.
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 70,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < 3; i++) ...[
                          if (i > 0) const SizedBox(width: 6),
                          counter(i),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              turn: 0.02,
            ),
            const SizedBox(height: 10),
            Opacity(
              opacity: _seg(t, 0.69, 0.74),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '¡TIEMPO!',
                    style: withFont(
                      look.numberFont,
                      const TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '+5 turnos extra',
                    style: withFont(
                      look.numberFont,
                      const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Un contador de tiempo: una ficha dorada con un reloj de arena.
class _TimeCounter extends StatelessWidget {
  const _TimeCounter();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: Alignment(-0.3, -0.4),
          colors: [Color(0xFFFFF3C4), Color(0xFFD9A43A), Color(0xFF8A6420)],
          stops: [0, 0.6, 1],
        ),
        boxShadow: [BoxShadow(color: Color(0x99000000), blurRadius: 4)],
      ),
      child: const Icon(
        Icons.hourglass_bottom,
        size: 17,
        color: Color(0xFF5A3A0E),
      ),
    );
  }
}

/// La carta «Fin de ronda» con el borde antiguo: el marco azul de Ancestral
/// Recall y la caja de texto de Counterspell que ya lleva el Old Border.
class _OldRoundCard extends StatelessWidget {
  const _OldRoundCard({required this.glow});

  /// El brillo dorado al lanzarse, de 0 a 1.
  final double glow;

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF15100A);
    const title = TextStyle(
      color: Colors.white,
      fontSize: 13,
      fontWeight: FontWeight.w700,
      height: 1,
      shadows: [Shadow(offset: Offset(1, 1))],
    );
    Widget bevel(Widget child) => Container(
      decoration: BoxDecoration(
        color: const Color(0xFF07101B),
        border: Border.all(color: const Color(0x59CDE4FF)),
      ),
      padding: const EdgeInsets.all(2),
      child: child,
    );
    Widget pip(Color color, Widget child) => Container(
      width: 13,
      height: 13,
      margin: const EdgeInsets.only(left: 2),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: const [BoxShadow(offset: Offset(0.6, 1))],
      ),
      child: child,
    );
    return Container(
      width: 180,
      height: 252,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(9),
        boxShadow: [
          const BoxShadow(color: Color(0xCC000000), blurRadius: 18),
          if (glow > 0)
            BoxShadow(
              color: const Color(0xFFFFD76A).withValues(alpha: glow),
              blurRadius: 26 * glow,
              spreadRadius: 3 * glow,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/marcos/azul.jpg',
              fit: BoxFit.fitHeight,
              repeat: ImageRepeat.repeatX,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(7, 6, 7, 5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 16,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Fin de ronda',
                            style: withFont('Vollkorn', title),
                          ),
                        ),
                        pip(
                          const Color(0xFFCAC5C0),
                          Text(
                            '1',
                            style: withFont(
                              'Vollkorn',
                              const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: ink,
                                height: 1,
                              ),
                            ),
                          ),
                        ),
                        pip(
                          const Color(0xFFA9D2EE),
                          const Icon(Icons.water_drop, size: 9, color: ink),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 3),
                  Expanded(
                    flex: 11,
                    child: bevel(
                      const CustomPaint(painter: _ClockArtPainter()),
                    ),
                  ),
                  const SizedBox(height: 3),
                  SizedBox(
                    height: 15,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Conjuro',
                            style: withFont(
                              'Vollkorn',
                              title.copyWith(fontSize: 10.5),
                            ),
                          ),
                        ),
                        // El símbolo de expansión, en el morado de las
                        // cartas «timeshifted».
                        const Icon(
                          Icons.hourglass_full,
                          size: 13,
                          color: Color(0xFFB57BE0),
                          shadows: [Shadow(offset: Offset(0.6, 0.6))],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 3),
                  Expanded(
                    flex: 7,
                    child: bevel(
                      Stack(
                        fit: StackFit.expand,
                        children: [
                          RotatedBox(
                            quarterTurns: 1,
                            child: Image.asset(
                              'assets/images/marcos/caja_azul.jpg',
                              fit: BoxFit.fill,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(5, 4, 5, 3),
                            child: Text(
                              'Suspender 3. Cuando se quita el último '
                              'contador de tiempo, se acaba la ronda: termina '
                              'el turno en curso y jugad cinco más.',
                              style: withFont(
                                'Vollkorn',
                                const TextStyle(
                                  fontSize: 7.6,
                                  height: 1.2,
                                  color: ink,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Ilus. Contador de vidas',
                    style: withFont(
                      'Vollkorn',
                      const TextStyle(
                        fontSize: 6,
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// La ilustración de la carta: un reloj a las 12 en una espiral.
class _ClockArtPainter extends CustomPainter {
  const _ClockArtPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final c = rect.center;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const RadialGradient(
          colors: [
            Color(0xFFF4D27A),
            Color(0xFF8A5BD0),
            Color(0xFF2B2F7A),
            Color(0xFF080B22),
          ],
          stops: [0, 0.16, 0.55, 1],
          radius: 0.8,
        ).createShader(rect),
    );
    // Estrellas, siempre en el mismo sitio.
    final rnd = Random(7);
    final star = Paint();
    for (var i = 0; i < 40; i++) {
      star.color = Colors.white.withValues(alpha: 0.2 + rnd.nextDouble() * 0.6);
      canvas.drawCircle(
        Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height),
        0.6,
        star,
      );
    }
    final r0 = size.shortestSide * 0.42;
    final spiral = Paint()
      ..color = const Color(0x8CFFD778)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (var arm = 0; arm < 3; arm++) {
      final path = Path();
      for (var t = 0.0; t < 14; t += 0.08) {
        final r = r0 * 0.02 * exp(0.21 * t);
        final a = t + arm * 2.094;
        final p = c + Offset(r * cos(a), r * sin(a) * 0.82);
        t == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, spiral);
    }
    final ring = Paint()
      ..color = const Color(0xD9FFEBBE)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    final rc = r0 * 0.75;
    canvas.drawCircle(c, rc, ring);
    for (var i = 0; i < 12; i++) {
      final a = i * pi / 6;
      ring.strokeWidth = i % 3 == 0 ? 2.2 : 1;
      canvas.drawLine(
        c + Offset(cos(a), sin(a)) * rc * 0.86,
        c + Offset(cos(a), sin(a)) * rc,
        ring,
      );
    }
    ring.strokeWidth = 2.4;
    canvas.drawLine(c, c + Offset(0, -rc * 0.78), ring);
    ring.strokeWidth = 3.4;
    canvas.drawLine(c, c + Offset(1, -rc * 0.52), ring);
    canvas.drawCircle(c, 3, Paint()..color = const Color(0xFFFFE9B0));
  }

  @override
  bool shouldRepaint(_ClockArtPainter old) => false;
}

// ---------------------------------------------------------------------------
// AlicanteMTG: el esqueleto de la liga atraviesa un muro de letras, como en
// su camiseta. Primera vibración: cae el muro; segunda: se agrieta; tercera:
// el esqueleto lo rompe.

class _AlicanteScene extends StatelessWidget {
  const _AlicanteScene({required this.t});

  final double t;

  static const Color _blue = Color(0xFF3B9FDB);
  static const Color _side = Color(0xFF1C5A86);
  static const Color _crack = Color(0xFFA9E8F5);
  static const Offset _hole = Offset(186, 142);

  // Los trozos que saltan del muro: (dirección, giro, lado).
  static const _chunks = [
    (Offset(-1, -0.7), 2.0, 18.0),
    (Offset(1, -0.9), -2.6, 14.0),
    (Offset(-1.1, 0.3), 1.4, 12.0),
    (Offset(1.2, 0.2), -1.8, 20.0),
    (Offset(-0.4, -1.2), 3.0, 11.0),
    (Offset(0.5, 1), -2.2, 15.0),
  ];

  @override
  Widget build(BuildContext context) {
    final slam = Curves.easeOutBack.transform(_seg(t, 0, 0.12));
    final cracks = Curves.easeOut.transform(_seg(t, _buzz2, _buzz2 + 0.1));
    final burst = _seg(t, _buzz3, _buzz3 + 0.1);
    final pop = Curves.easeOutBack.transform(burst);
    // Acaban de volar antes de que la escena esté entera (0,8).
    final fly = _seg(t, _buzz3, 0.79);
    TextStyle block(double size) => withFont(
      'Barlow Condensed',
      TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w800,
        height: 0.92,
        color: _blue,
        shadows: const [
          Shadow(offset: Offset(3, 4), color: _side),
          Shadow(offset: Offset(6, 8), color: _side),
          Shadow(offset: Offset(8, 11), color: Color(0xFF123E5E)),
        ],
      ),
    );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // El muro.
        Positioned(
          left: 0,
          right: 0,
          top: 22,
          child: Opacity(
            opacity: _seg(t, 0, 0.04),
            child: Transform.scale(
              scale: 1.35 - 0.35 * slam,
              child: _withKick(
                t,
                Column(
                  children: [
                    FittedBox(
                      child: Text('FIN DE', style: block(104), maxLines: 1),
                    ),
                    FittedBox(
                      child: Text('RONDA', style: block(130), maxLines: 1),
                    ),
                  ],
                ),
                turn: 0.015,
              ),
            ),
          ),
        ),
        // Las grietas, desde donde saldrá el esqueleto.
        if (cracks > 0)
          Positioned.fill(
            child: CustomPaint(
              painter: _CracksPainter(
                center: _hole,
                progress: cracks,
                color: _crack,
              ),
            ),
          ),
        // Los trozos que salen volando.
        if (fly > 0 && fly < 1)
          for (final (dir, spin, side) in _chunks)
            Positioned(
              left: _hole.dx + dir.dx * 190 * fly - side / 2,
              top: _hole.dy + dir.dy * 150 * fly + 140 * fly * fly - side / 2,
              child: Opacity(
                opacity: 1 - fly,
                child: Transform.rotate(
                  angle: spin * fly * pi,
                  child: Container(
                    width: side,
                    height: side * 0.8,
                    decoration: const BoxDecoration(
                      color: _blue,
                      boxShadow: [
                        BoxShadow(color: _side, offset: Offset(3, 3)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        // El esqueleto, con el agujero negro, rompiendo el muro.
        if (burst > 0)
          Positioned(
            left: _hole.dx - 125,
            top: _hole.dy - 125,
            width: 250,
            height: 250,
            child: Transform.rotate(
              angle: -0.25 * (1 - pop),
              child: Transform.scale(
                scale: 0.2 + 0.8 * pop,
                child: Image.asset(
                  'assets/images/avisos/esqueleto_alicante.png',
                  filterQuality: FilterQuality.medium,
                ),
              ),
            ),
          ),
        // Lo que dice, entero y legible.
        Positioned(
          left: 0,
          right: 0,
          bottom: 4,
          child: Opacity(
            opacity: _seg(t, 0.7, 0.77),
            child: Column(
              children: [
                Text(
                  'RONDA FINALIZADA',
                  style: withFont(
                    'Barlow Condensed',
                    const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 3,
                      height: 1,
                      shadows: [Shadow(blurRadius: 6)],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '+5 TURNOS EXTRA',
                  style: withFont(
                    'Barlow Condensed',
                    const TextStyle(
                      color: _blue,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 6,
                      height: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Las grietas del muro: unas cuantas líneas quebradas que salen de [center]
/// y crecen con [progress], con alguna rama.
class _CracksPainter extends CustomPainter {
  const _CracksPainter({
    required this.center,
    required this.progress,
    required this.color,
  });

  final Offset center;
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = Random(11);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    const count = 11;
    for (var i = 0; i < count; i++) {
      final angle = i * 2 * pi / count + rnd.nextDouble() * 0.4;
      final length = 55 + rnd.nextDouble() * 55;
      final path = Path();
      var p = center + Offset(cos(angle), sin(angle)) * 60;
      path.moveTo(p.dx, p.dy);
      const steps = 5;
      final reach = (steps * progress).ceil();
      for (var s = 1; s <= reach; s++) {
        final f = s == reach ? steps * progress - (s - 1) : 1.0;
        final jitter = (rnd.nextDouble() - 0.5) * 0.9;
        final step = length / steps * f;
        p += Offset(cos(angle + jitter), sin(angle + jitter)) * step;
        path.lineTo(p.dx, p.dy);
        // Una rama corta de vez en cuando.
        if (s == 2 && f == 1 && i.isEven) {
          final b = p + Offset(cos(angle + 0.9), sin(angle + 0.9)) * 22;
          canvas.drawLine(p, b, paint..strokeWidth = 2);
          paint.strokeWidth = 3;
        }
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_CracksPainter old) => old.progress != progress;
}

// ---------------------------------------------------------------------------
// Full Tapped: la portada de Tapeados. Con cada vibración sale una cara y una
// palabra de la franja, que tapa la de «TAPEADOS»: «FIN», «DE» y «R↻NDA»,
// con la flecha de Full Tapped de «O». Al final se escribe el título, como en
// los episodios.

class _FullTappedScene extends StatelessWidget {
  const _FullTappedScene({required this.t, required this.minutes});

  /// Lo que duraba la ronda: hace de número de episodio en el título.
  final int minutes;

  final double t;

  static const Color _red = Color(0xFFF03B3B);

  // La portada recortada mide 1000 × 514; la franja va del 35,4 % al 62,8 %
  // de su alto y las caras, por tercios.
  static const double _width = 360;
  static const double _height = _width * 514 / 1000;
  static const double _bandTop = _height * 0.345;
  static const double _bandHeight = _height * 0.29;
  static const _faces = [(0.0, 0.385), (0.385, 0.665), (0.665, 1.0)];

  @override
  Widget build(BuildContext context) {
    double reveal(int i) => _seg(t, i / 3, i / 3 + 0.05);
    Widget word(String text, int i) {
      final x = reveal(i);
      return Opacity(
        opacity: x,
        child: Transform.scale(scale: 1.4 - 0.4 * x, child: _redText(text)),
      );
    }

    String typed(String text, double a, double b) =>
        text.substring(0, (text.length * _seg(t, a, b)).floor());
    final line = _pixel(12, Colors.white);
    return Column(
      children: [
        const SizedBox(height: 24),
        _withKick(
          t,
          SizedBox(
            width: _width,
            height: _height,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image.asset(
                    'assets/images/avisos/tapeados_caras.jpg',
                    fit: BoxFit.fill,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
                // Las caras que aún no han salido, tapadas de negro.
                for (var i = 0; i < 3; i++)
                  if (reveal(i) < 1)
                    Positioned(
                      left: _width * _faces[i].$1,
                      width: _width * (_faces[i].$2 - _faces[i].$1),
                      top: 0,
                      bottom: 0,
                      child: ColoredBox(
                        color: Colors.black.withValues(alpha: 1 - reveal(i)),
                      ),
                    ),
                // La franja, con «FIN DE R↻NDA» en vez de «TAPEADOS».
                Positioned(
                  left: 0,
                  right: 0,
                  top: _bandTop,
                  height: _bandHeight,
                  child: ColoredBox(
                    color: Colors.black,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: FittedBox(
                        child: Row(
                          children: [
                            word('FIN', 0),
                            const SizedBox(width: 14),
                            word('DE', 1),
                            const SizedBox(width: 14),
                            Opacity(
                              opacity: reveal(2),
                              child: Transform.scale(
                                scale: 1.4 - 0.4 * reveal(2),
                                child: Row(
                                  children: [
                                    _redText('R'),
                                    // La «O» es la flecha de la portada, de
                                    // pie como allí: 1,1 veces la altura de
                                    // las mayúsculas, un poco por encima de
                                    // ellas y bajando algo de la línea.
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        4,
                                        0,
                                        4,
                                        2,
                                      ),
                                      child: Image.asset(
                                        'assets/images/avisos/'
                                        'flecha_tapeados.png',
                                        height: 54,
                                      ),
                                    ),
                                    _redText('NDA'),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          turn: 0.02,
        ),
        const SizedBox(height: 26),
        // El título, como el de los episodios, que se escribe solo.
        SizedBox(
          width: _width,
          child: Column(
            children: [
              Text(
                typed('$minutes."SE ACABÓ LA RONDA"', 0.67, 0.74),
                style: line,
                maxLines: 1,
              ),
              const SizedBox(height: 14),
              Text(
                typed('+5: TURNOS EXTRA', 0.72, 0.78),
                style: line,
                maxLines: 1,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _redText(String text) {
    const style = TextStyle(
      fontSize: 56,
      fontWeight: FontWeight.w900,
      height: 1,
      letterSpacing: 1,
    );
    return Stack(
      children: [
        Text(
          text,
          style: withFont(
            'Montserrat',
            style.copyWith(
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 5
                ..color = Colors.white,
            ),
          ),
        ),
        Text(text, style: withFont('Montserrat', style.copyWith(color: _red))),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Old School MTG Channel: cae la carta del Chaos Orb dando vueltas, con la
// boina puesta en el Orb del dibujo y la navaja cerrada encima; con la
// tercera vibración la navaja se abre de golpe y sale «FIN DE RONDA».

class _OldSchoolScene extends StatelessWidget {
  const _OldSchoolScene({required this.t, required this.look});

  final double t;
  final Look look;

  // Se dibuja en un cuadro de 220 y se escala al de la escena.
  static const double _box = 220;

  // La carta, de 672 × 936, y lo que lleva encima, en su sitio.
  static const double _cardWidth = 100;
  static const double _cardHeight = 140;
  static const Offset _cardAt = Offset(60, 58);

  // La boina (461 × 237), sobre la cabeza del Orb.
  static const double _beretWidth = 46;
  static const Offset _beretAt = Offset(27, 1);

  // La navaja recortada mide 669 × 371; el eje de la hoja, en el recazo.
  static const double _knifeWidth = 112;
  static const double _knifeScale = _knifeWidth / 669;
  static const Offset _knifeAt = Offset(30, 100);
  static const Offset _pivot = Offset(265 * _knifeScale, 75 * _knifeScale);

  static const Color _gold = Color(0xFFFFD76A);
  static const double _deg = pi / 180;

  @override
  Widget build(BuildContext context) {
    // 1.ª vibración: cae dando vueltas; con la 2.ª aterriza y se aplasta un
    // poco.
    final fall = const Cubic(0.45, 0, 1, 0.6).transform(_seg(t, 0, 0.31));
    final squash = _seg(t, 0.31, 0.335) - _seg(t, 0.335, 0.37);
    final cardScale = 0.6 + 0.4 * fall;
    // La boina da un saltito al aterrizar y otro al abrirse la navaja.
    final beretAngle = _keys(t, const [
      (0.32, -10),
      (0.38, -22),
      (0.44, -6),
      (0.47, -10),
      (0.666, -10),
      (0.70, -14),
      (0.74, -10),
    ]);
    final beretUp = _keys(t, const [
      (0.32, 0),
      (0.38, -14),
      (0.44, 0),
      (0.666, 0),
      (0.70, -6),
      (0.74, 0),
    ]);
    // 3.ª: la navaja se abre de golpe, ¡clac!, y sale el título.
    final blade = _keys(t, const [(_buzz3, -97), (0.70, 9), (0.73, 0)]);
    final clac = _keys(t, const [(_buzz3, 0), (0.69, 1), (0.74, 1), (0.79, 0)]);
    final clacScale = _keys(t, const [(_buzz3, 0.5), (0.69, 1.15), (0.76, 1)]);
    final title = _seg(t, 0.66, 0.71);
    final titleScale = _keys(t, const [(0.66, 1.6), (0.71, 0.94), (0.75, 1)]);
    final sub = _seg(t, 0.70, 0.78);
    final shadow = _seg(t, 0, 0.30);

    final knife = SizedBox(
      width: _knifeWidth,
      height: 371 * _knifeScale,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Transform(
              origin: _pivot,
              transform: Matrix4.rotationZ(blade * _deg),
              child: Image.asset('assets/images/avisos/navaja_hoja.png'),
            ),
          ),
          Positioned.fill(
            child: Image.asset('assets/images/avisos/navaja_mango.png'),
          ),
          if (clac > 0)
            Positioned(
              left: -6,
              top: -24,
              child: Opacity(
                opacity: clac,
                child: Transform.scale(
                  scale: clacScale,
                  child: Text(
                    '¡CLAC!',
                    style: withFont(
                      'Barlow Condensed',
                      const TextStyle(
                        color: _gold,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                        shadows: [Shadow(offset: Offset(0, 2))],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    final card = SizedBox(
      width: _cardWidth,
      height: _cardHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0xDD000000),
                    blurRadius: 18,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: Image.asset(
                  'assets/images/avisos/chaos_orb.jpg',
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          Positioned(
            left: _beretAt.dx,
            top: _beretAt.dy + beretUp,
            width: _beretWidth,
            child: Transform.rotate(
              angle: beretAngle * _deg,
              child: Image.asset('assets/images/avisos/boina.png'),
            ),
          ),
          Positioned(
            left: _knifeAt.dx,
            top: _knifeAt.dy,
            child: Transform.rotate(angle: -8 * _deg, child: knife),
          ),
        ],
      ),
    );

    TextStyle vollkorn(double size, Color color, double blur) => withFont(
      'Vollkorn',
      TextStyle(
        color: color,
        fontSize: size,
        fontWeight: FontWeight.w900,
        height: 1.15,
        shadows: [
          const Shadow(offset: Offset(0, 2)),
          Shadow(blurRadius: blur),
        ],
      ),
    );

    return FittedBox(
      child: SizedBox(
        width: _box,
        height: _box,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // La sombra en la mesa, que crece mientras cae.
            Positioned(
              left: 50,
              top: _cardAt.dy + _cardHeight - 12,
              width: 120,
              height: 16,
              child: Opacity(
                opacity: shadow,
                child: Transform.scale(
                  scale: 0.2 + 0.8 * shadow,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [Color(0xCC000000), Color(0x00000000)],
                        stops: [0, 0.7],
                      ),
                      borderRadius: BorderRadius.all(Radius.elliptical(60, 8)),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: _cardAt.dx,
              top: _cardAt.dy,
              child: Transform.translate(
                offset: Offset(0, -300 * (1 - fall)),
                child: Transform.rotate(
                  angle: (-160 + 156 * fall) * _deg,
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.diagonal3Values(
                      cardScale * (1 + 0.06 * squash),
                      cardScale * (1 - 0.08 * squash),
                      1,
                    ),
                    child: card,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: Opacity(
                opacity: title,
                child: Transform.scale(
                  scale: titleScale,
                  child: Text(
                    'FIN DE RONDA',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    style: vollkorn(25, Colors.white, 12),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 30,
              child: Opacity(
                opacity: sub,
                child: Transform.translate(
                  offset: Offset(0, 8 * (1 - sub)),
                  child: Text(
                    '+5 turnos extra\ny lanzamiento de Chaos Orb',
                    textAlign: TextAlign.center,
                    style: vollkorn(11, _gold, 8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// El valor en [t] de una animación por fotogramas clave `(momento, valor)`:
/// antes del primero vale lo del primero, después del último lo del último y
/// entre dos va suave.
double _keys(double t, List<(double, double)> keys) {
  if (t <= keys.first.$1) return keys.first.$2;
  for (var i = 1; i < keys.length; i++) {
    final (b, vb) = keys[i];
    if (t <= b) {
      final (a, va) = keys[i - 1];
      return va + (vb - va) * Curves.easeInOut.transform(_seg(t, a, b));
    }
  }
  return keys.last.$2;
}
