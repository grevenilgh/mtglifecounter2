import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mtglifecounter/look.dart';
import 'package:mtglifecounter/settings_page.dart';

// Los tres sorteos de la barra: moneda, dado D20 y duelo de piedra, papel o
// tijera. Están portados del contador de mtgtournament (site.js y site.css).
// Cada uno ocupa la pantalla: el resultado sale en las dos mitades, la de
// arriba girada si el jugador de arriba está enfrente.

final Random _random = Random();

/// Abre un sorteo a pantalla completa. Se cierra solo con su botón: tocar
/// fuera no lo cierra, para no perder el resultado por un toque sin querer.
Future<void> _showDraw(BuildContext context, Widget child) {
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: false,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, _) => FadeTransition(
        opacity: animation,
        child: Material(
          color: const Color(0xE6080809),
          child: SafeArea(child: child),
        ),
      ),
    ),
  );
}

Future<void> showCoinFlip(BuildContext context, {required bool flipTop}) =>
    _showDraw(context, _CoinDraw(flipTop: flipTop));

Future<void> showDiceRoll(BuildContext context, {required bool flipTop}) =>
    _showDraw(context, _DiceDraw(flipTop: flipTop));

Future<void> showDuel(BuildContext context, {required bool flipTop}) =>
    _showDraw(context, _DuelDraw(flipTop: flipTop));

/// Las dos mitades con el rótulo del resultado y, en medio, el sorteo y sus
/// botones.
class _DrawLayout extends StatelessWidget {
  const _DrawLayout({
    required this.flipTop,
    required this.label,
    required this.visible,
    required this.center,
    required this.again,
    required this.againLabel,
  });

  final bool flipTop;
  final String label;
  final bool visible;
  final Widget center;
  final VoidCallback again;
  final String againLabel;

  @override
  Widget build(BuildContext context) {
    Widget half(bool top) {
      final text = AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 300),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: withFont(
            'Barlow Condensed',
            const TextStyle(
              color: kAccent,
              fontSize: 40,
              fontWeight: FontWeight.w700,
              letterSpacing: 6,
            ),
          ),
        ),
      );
      return Expanded(
        child: Center(
          child: top && flipTop
              ? RotatedBox(quarterTurns: 2, child: text)
              : text,
        ),
      );
    }

    return Column(
      children: [
        half(true),
        center,
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: _Buttons(again: again, againLabel: againLabel),
        ),
        half(false),
      ],
    );
  }
}

class _Buttons extends StatelessWidget {
  const _Buttons({required this.again, required this.againLabel});

  final VoidCallback again;
  final String againLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 140,
          child: FilledButton.tonal(
            onPressed: again,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            child: Text(againLabel),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 140,
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            style: FilledButton.styleFrom(
              backgroundColor: kAccent,
              foregroundColor: const Color(0xFF1A1306),
              minimumSize: const Size.fromHeight(48),
            ),
            child: const Text('Cerrar'),
          ),
        ),
      ],
    );
  }
}

// --- La moneda ----------------------------------------------------------

/// Cara es el Chaos Orb y cruz el Ankh of Mishra. El ángulo final decide la
/// cara: un múltiplo de una vuelta acaba de cara y media vuelta más, de cruz,
/// así que la moneda se posa en la que ha salido sin ningún salto.
class _CoinDraw extends StatefulWidget {
  const _CoinDraw({required this.flipTop});

  final bool flipTop;

  @override
  State<_CoinDraw> createState() => _CoinDrawState();
}

/// Un lanzamiento de verdad: la moneda se encoge un poco al impulsarla, sube
/// girando hacia el que mira, cae, da dos botes cada vez más bajos y se
/// asienta bamboleándose. Al girar se ve su canto y le pasa un brillo.
class _CoinDrawState extends State<_CoinDraw>
    with SingleTickerProviderStateMixin {
  static const int _ms = 1900;

  // Tramos del tiempo total: impulso, vuelo y botes.
  static const double _lift = 0.06;
  static const double _land = 0.72;

  // Altura del vuelo, en dp.
  static const double _height = 190;

  // Lo que queda echada hacia atrás en la mesa, en radianes.
  static const double _rest = -0.5;

  late final AnimationController _c =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: _ms),
      )..addStatusListener((s) {
        if (s == AnimationStatus.completed) setState(() => _shown = true);
      });
  bool _heads = true;
  bool _shown = false;

  // Medias vueltas desde la posición de partida, de dónde sale la tirada y
  // dónde acaba: un número par enseña la cara y uno impar la cruz.
  int _fromHalf = 0;
  int _toHalf = 0;

  // Inclinación lateral del lanzamiento, distinta en cada tirada.
  double _tilt = 0;
  int _throwId = 0;

  @override
  void initState() {
    super.initState();
    _throw();
  }

  // Las dos caras se cargan ya: si no, la primera tirada vuela sin dibujo.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    for (final face in const ['moneda-cara', 'moneda-cruz']) {
      precacheImage(AssetImage('assets/images/sorteos/$face.jpg'), context);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _throw() {
    final heads = _random.nextBool();
    final id = ++_throwId;
    setState(() {
      _heads = heads;
      _shown = false;
      // Sale de donde quedó la anterior y da entre 14 y 19 medias vueltas.
      _fromHalf = _toHalf;
      _toHalf =
          _fromHalf +
          2 * (7 + _random.nextInt(3)) +
          ((heads ? 0 : 1) + _fromHalf) % 2;
      _tilt = (_random.nextDouble() * 2 - 1) * 0.22;
    });
    _c.forward(from: 0);
    HapticFeedback.lightImpact();
    // Un toque al caer y en cada bote.
    for (final at in [_land, _land + 0.45 * (1 - _land)]) {
      Future<void>.delayed(Duration(milliseconds: (at * _ms).round()), () {
        if (mounted && id == _throwId) HapticFeedback.selectionClick();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _DrawLayout(
      flipTop: widget.flipTop,
      label: _heads ? 'Cara' : 'Cruz',
      visible: _shown,
      again: _throw,
      againLabel: 'Lanzar',
      center: SizedBox(
        height: 300,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = _c.value;
            final start = _fromHalf * pi;
            final end = _toHalf * pi;
            double height; // dp sobre la mesa
            double angle; // giro sobre el eje horizontal, sin la inclinación
            double press = 0; // aplastado del impulso
            double tilt; // inclinación lateral
            if (t < _lift) {
              press = sin(pi * t / _lift);
              height = 0;
              angle = start;
              tilt = 0;
            } else if (t < _land) {
              final p = (t - _lift) / (_land - _lift);
              // Parábola: sube y cae. El giro frena un poco al final.
              height = 4 * p * (1 - p) * _height;
              angle = start + (end - start) * Curves.easeOutSine.transform(p);
              tilt = _tilt * sin(pi * p);
            } else {
              final q = (t - _land) / (1 - _land);
              // Dos botes cada vez más bajos y luego quieta.
              height = q < 0.45
                  ? 22 * sin(pi * q / 0.45)
                  : q < 0.72
                  ? 7 * sin(pi * (q - 0.45) / 0.27)
                  : 0;
              // Se asienta bamboleándose.
              final settle = pow(1 - q, 2).toDouble();
              angle = end + 0.42 * settle * sin(q * pi * 5);
              tilt = _tilt * 0.4 * settle * sin(q * pi * 3);
            }
            // En la mesa queda algo echada hacia atrás, como vista desde la
            // silla: así se le ve el grosor aunque esté quieta.
            angle += _rest;
            final h = height / _height;
            return Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // Sombra en la mesa: más pequeña y clara cuanto más alta.
                Positioned(
                  bottom: 26,
                  child: Opacity(
                    opacity: (0.85 - 0.6 * h).clamp(0, 1),
                    child: Transform.scale(
                      scale: 1 - 0.5 * h,
                      child: Container(
                        width: 160,
                        height: 24,
                        decoration: const BoxDecoration(
                          gradient: RadialGradient(
                            colors: [Color(0xD9000000), Color(0x00000000)],
                          ),
                          borderRadius: BorderRadius.all(
                            Radius.elliptical(80, 12),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Transform.translate(
                  offset: Offset(0, -height + 5 * press),
                  child: Transform.scale(
                    // Más grande cuanto más cerca de quien mira.
                    scale: (1 + 0.38 * h) * (1 - 0.04 * press),
                    child: Transform.rotate(
                      angle: tilt,
                      child: _Coin3D(angle: angle),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// La moneda como un disco de verdad: la cara delante, la cruz detrás y, entre
/// las dos, el canto hecho de láminas finas. Todo con la misma perspectiva,
/// así que el grosor se ve bien en cualquier giro. Se pinta de lo más lejano
/// a lo más cercano.
class _Coin3D extends StatelessWidget {
  const _Coin3D({required this.angle});

  /// Giro sobre el eje horizontal: 0 enseña la cara y pi la cruz.
  final double angle;

  static const double _size = 200;
  static const double _thickness = 18;
  static const int _slices = 16;

  Matrix4 _at(double z, {bool back = false}) {
    final m = Matrix4.identity()
      ..setEntry(3, 2, 0.0011)
      ..rotateX(angle)
      ..translateByDouble(0, 0, z, 1);
    // La cruz mira hacia atrás.
    if (back) m.rotateX(pi);
    return m;
  }

  @override
  Widget build(BuildContext context) {
    // Cuánto mira cada cara hacia quien la ve: de lado se oscurece.
    final facing = cos(angle).abs();
    final glint = (angle / (2 * pi)) % 1;
    final heads = Transform(
      alignment: Alignment.center,
      transform: _at(-_thickness / 2),
      child: _CoinFace(heads: true, glint: glint, facing: facing),
    );
    final tails = Transform(
      alignment: Alignment.center,
      transform: _at(_thickness / 2, back: true),
      child: _CoinFace(heads: false, glint: 1 - glint, facing: facing),
    );
    final rim = [
      for (var i = 0; i <= _slices; i++)
        Transform(
          alignment: Alignment.center,
          transform: _at(-_thickness / 2 + _thickness * i / _slices),
          child: Container(
            width: _size,
            height: _size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              // Estrías del canto: una lámina clara y otra oscura, y luz de
              // arriba.
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: i.isEven
                    ? const [Color(0xFFD5DADF), Color(0xFF6E7378)]
                    : const [Color(0xFFA9AFB5), Color(0xFF4C5054)],
              ),
            ),
          ),
        ),
    ];
    // La cara está delante (más cerca) mientras el coseno es positivo.
    final headsNear = cos(angle) >= 0;
    return Stack(
      alignment: Alignment.center,
      children: headsNear
          ? [tails, ...rim.reversed, heads]
          : [heads, ...rim, tails],
    );
  }
}

class _CoinFace extends StatelessWidget {
  const _CoinFace({
    required this.heads,
    required this.glint,
    required this.facing,
  });

  final bool heads;

  /// Dónde va el brillo que cruza la cara al girar, de 0 a 1.
  final double glint;

  /// 1 si mira de frente y 0 si está de canto.
  final double facing;

  @override
  Widget build(BuildContext context) {
    final g = glint * 3 - 1.5;
    return Container(
      width: 200,
      height: 200,
      padding: const EdgeInsets.all(7),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment(-0.6, -1),
          end: Alignment(0.6, 1),
          colors: [Color(0xFFE6EAEE), Color(0xFF9AA0A6), Color(0xFF5C6166)],
          stops: [0, 0.45, 1],
        ),
      ),
      child: ClipOval(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              heads
                  ? 'assets/images/sorteos/moneda-cara.jpg'
                  : 'assets/images/sorteos/moneda-cruz.jpg',
              fit: BoxFit.cover,
            ),
            // Brillo que cruza la cara.
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment(-1, g - 0.6),
                  end: Alignment(1, g + 0.6),
                  colors: const [
                    Color(0x00FFFFFF),
                    Color(0x55FFFFFF),
                    Color(0x00FFFFFF),
                  ],
                ),
              ),
            ),
            // Sombra al ponerse de canto.
            ColoredBox(
              color: Colors.black.withValues(alpha: 0.5 * (1 - facing)),
            ),
          ],
        ),
      ),
    );
  }
}

// --- El dado D20 ----------------------------------------------------------

class _DiceDraw extends StatefulWidget {
  const _DiceDraw({required this.flipTop});

  final bool flipTop;

  @override
  State<_DiceDraw> createState() => _DiceDrawState();
}

class _DiceDrawState extends State<_DiceDraw>
    with SingleTickerProviderStateMixin {
  final _D20 _dice = _D20();
  late final AnimationController _c =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 950),
      )..addStatusListener((s) {
        if (s == AnimationStatus.completed) {
          _dice.settle();
          setState(() => _shown = true);
        }
      });
  int _value = 20;
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    _roll();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _roll() {
    _dice.settle();
    setState(() {
      _value = _dice.roll();
      _shown = false;
    });
    _c.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return _DrawLayout(
      flipTop: widget.flipTop,
      label: 'Ha salido $_value',
      visible: _shown,
      again: _roll,
      againLabel: 'Tirar',
      center: SizedBox(
        width: 240,
        height: 300,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => CustomPaint(
            painter: _D20Painter(_dice, _c.isAnimating ? _c.value : 1),
          ),
        ),
      ),
    );
  }
}

typedef _V = List<double>;
typedef _Q = List<double>;

/// El icosaedro del dado y su lanzamiento, con cuaterniones.
class _D20 {
  _D20() {
    for (var i = 0, n = 1; i < 20; i++) {
      if (nums[i] != 0) continue;
      nums[i] = n;
      nums[_opposite[i]] = 21 - n;
      n++;
    }
    face = nums.indexOf(20);
    turn = _bring(_normals[face], _rest);
  }

  static final double _phi = (1 + sqrt(5)) / 2;
  static _V _unit(_V v) {
    final d = sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2]);
    return [v[0] / d, v[1] / d, v[2] / d];
  }

  static double _dot(_V a, _V b) => a[0] * b[0] + a[1] * b[1] + a[2] * b[2];

  static final List<_V> vertices = <_V>[
    [-1.0, _phi, 0],
    [1.0, _phi, 0],
    [-1.0, -_phi, 0],
    [1.0, -_phi, 0],
    [0.0, -1, _phi],
    [0.0, 1, _phi],
    [0.0, -1, -_phi],
    [0.0, 1, -_phi],
    [_phi, 0, -1],
    [_phi, 0, 1],
    [-_phi, 0, -1],
    [-_phi, 0, 1],
  ].map(_unit).toList();

  static const List<List<int>> faces = [
    [0, 11, 5],
    [0, 5, 1],
    [0, 1, 7],
    [0, 7, 10],
    [0, 10, 11],
    [1, 5, 9],
    [5, 11, 4],
    [11, 10, 2],
    [10, 7, 6],
    [7, 1, 8],
    [3, 9, 4],
    [3, 4, 2],
    [3, 2, 6],
    [3, 6, 8],
    [3, 8, 9],
    [4, 9, 5],
    [2, 4, 11],
    [6, 2, 10],
    [8, 6, 7],
    [9, 8, 1],
  ];

  static final List<_V> _normals = faces.map((c) {
    final a = vertices[c[0]], b = vertices[c[1]], d = vertices[c[2]];
    return _unit([a[0] + b[0] + d[0], a[1] + b[1] + d[1], a[2] + b[2] + d[2]]);
  }).toList();

  static final List<int> _opposite = List.generate(20, (i) {
    var best = -1;
    var min = 0.0;
    for (var j = 0; j < 20; j++) {
      final d = _dot(_normals[i], _normals[j]);
      if (j != i && d < min) {
        min = d;
        best = j;
      }
    }
    return best;
  });

  /// Hacia dónde mira la cara de arriba en reposo: un poco inclinada para que
  /// se vea el volumen.
  static final _V _rest = _unit([0, 0.22, 0.975]);

  static _Q _axis(_V e, double angle) {
    final s = sin(angle / 2);
    return [cos(angle / 2), e[0] * s, e[1] * s, e[2] * s];
  }

  static _Q _mul(_Q a, _Q b) => [
    a[0] * b[0] - a[1] * b[1] - a[2] * b[2] - a[3] * b[3],
    a[0] * b[1] + a[1] * b[0] + a[2] * b[3] - a[3] * b[2],
    a[0] * b[2] - a[1] * b[3] + a[2] * b[0] + a[3] * b[1],
    a[0] * b[3] + a[1] * b[2] - a[2] * b[1] + a[3] * b[0],
  ];

  static _V rotate(_Q q, _V v) {
    final w = q[0], x = q[1], y = q[2], z = q[3];
    final tx = 2 * (y * v[2] - z * v[1]);
    final ty = 2 * (z * v[0] - x * v[2]);
    final tz = 2 * (x * v[1] - y * v[0]);
    return [
      v[0] + w * tx + (y * tz - z * ty),
      v[1] + w * ty + (z * tx - x * tz),
      v[2] + w * tz + (x * ty - y * tx),
    ];
  }

  static _V _randomAxis() {
    final z = _random.nextDouble() * 2 - 1;
    final a = _random.nextDouble() * pi * 2;
    final r = sqrt(1 - z * z);
    return [r * cos(a), r * sin(a), z];
  }

  /// El giro que lleva el vector [a] hasta [b].
  static _Q _bring(_V a, _V b) {
    final d = _dot(a, b).clamp(-1.0, 1.0);
    if (d > 0.99999) return [1, 0, 0, 0];
    final axis = [
      a[1] * b[2] - a[2] * b[1],
      a[2] * b[0] - a[0] * b[2],
      a[0] * b[1] - a[1] * b[0],
    ];
    final m = sqrt(_dot(axis, axis));
    if (m < 1e-6) return _axis([1, 0, 0], pi);
    return _axis([axis[0] / m, axis[1] / m, axis[2] / m], acos(d));
  }

  static List<_V> get normals => _normals;

  final List<int> nums = List.filled(20, 0);
  late int face;
  late _Q turn;
  _Q Function(double)? _path;

  /// Cuánto se resalta la cara que ha salido, de 0 a 1.
  double highlight = 1;

  /// El número de la cara [cara] pasa a ser [value], y su opuesta suma 21.
  void _label(int cara, int value) {
    final where = nums.indexOf(value);
    if (where == cara) return;
    final had = nums[cara];
    nums[cara] = value;
    nums[_opposite[cara]] = 21 - value;
    nums[where] = had;
    nums[_opposite[where]] = 21 - had;
  }

  /// Decide el resultado y prepara el recorrido de la animación.
  int roll() {
    final result = 1 + _random.nextInt(20);
    final start = turn;
    final axisA = _randomAxis(),
        angleA = pi * 2 * (2.5 + _random.nextDouble() * 1.5);
    final axisB = _randomAxis(),
        angleB = pi * 2 * (0.5 + _random.nextDouble() * 0.5);
    _Q free(double e) =>
        _mul(start, _mul(_axis(axisA, angleA * e), _axis(axisB, angleB * e)));
    final raw = free(1);
    var best = 0;
    var max = -2.0;
    for (var i = 0; i < 20; i++) {
      final z = rotate(raw, _normals[i])[2];
      if (z > max) {
        max = z;
        best = i;
      }
    }
    _label(best, result);
    face = best;
    // Al final se corrige el giro para que la cara quede mirando de frente.
    final end = _bring(rotate(raw, _normals[best]), _rest);
    final s = sqrt(end[1] * end[1] + end[2] * end[2] + end[3] * end[3]);
    final angleC = 2 * atan2(s, end[0]);
    final axisC = s < 1e-9
        ? [0.0, 0.0, 1.0]
        : [end[1] / s, end[2] / s, end[3] / s];
    _path = (e) => _mul(_axis(axisC, angleC * e), free(e));
    highlight = 0;
    return result;
  }

  /// Deja el dado en reposo en la cara que ha salido.
  void settle() {
    final path = _path;
    if (path == null) return;
    turn = path(1);
    _path = null;
    highlight = 1;
  }

  /// El giro en el instante [t] (de 0 a 1) de la animación.
  _Q at(double t) {
    final path = _path;
    if (path == null) return turn;
    highlight = ((t - 0.74) / 0.26).clamp(0.0, 1.0);
    return path(1 - pow(1 - t, 2.4).toDouble());
  }

  /// Altura del dado: cae y da tres botes cada vez más bajos.
  static double height(double t) {
    if (t < 0.46) {
      final u = t / 0.46;
      return -(1 - u * u);
    }
    for (final s in const [
      [0.46, 0.74, 0.28],
      [0.74, 0.90, 0.11],
      [0.90, 1.0, 0.04],
    ]) {
      if (t <= s[1]) {
        final u = (t - s[0]) / (s[1] - s[0]);
        return -s[2] * 4 * u * (1 - u);
      }
    }
    return 0;
  }
}

class _D20Painter extends CustomPainter {
  _D20Painter(this.dice, this.t);

  final _D20 dice;
  final double t;

  static const _shadow = [70, 58, 42];
  static const _light = [246, 238, 218];
  static final _V _lamp = _D20._unit([-0.42, 0.72, 0.55]);
  static const double _rise = 1.5;

  Color _mix(double k) => Color.fromARGB(
    255,
    (_shadow[0] + (_light[0] - _shadow[0]) * k).round(),
    (_shadow[1] + (_light[1] - _shadow[1]) * k).round(),
    (_shadow[2] + (_light[2] - _shadow[2]) * k).round(),
  );

  @override
  void paint(Canvas canvas, Size size) {
    final q = dice.at(t);
    final lift = t < 1 ? _D20.height(t) : 0.0;
    final radius = min(size.width / 2, size.height / (2.4 + _rise)) * 0.94;
    final cx = size.width / 2;
    final cy =
        radius * (1 + _rise) + (size.height - radius * (2.4 + _rise)) / 2;

    // La sombra se encoge y se aclara cuando el dado sube.
    final h = min(1.0, -lift);
    final rx = radius * (0.92 - h * 0.3);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, cy + radius * 1.22),
        width: rx * 2,
        height: rx * 0.4,
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.6 * (1 - h * 0.62))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    final shift = lift * radius * _rise;
    final verts = _D20.vertices.map((v) => _D20.rotate(q, v)).toList();
    Offset point(_V v) =>
        Offset(cx + v[0] * radius, cy - v[1] * radius + shift);
    final order = List.generate(20, (i) => i)
      ..sort(
        (a, b) => _D20
            .rotate(q, _D20.normals[a])[2]
            .compareTo(_D20.rotate(q, _D20.normals[b])[2]),
      );
    final stroke = max(1.0, radius * 0.015);
    final highlight = dice.highlight;

    for (final i in order) {
      final n = _D20.rotate(q, _D20.normals[i]);
      if (n[2] <= 0.02) continue;
      final wins = i == dice.face && highlight > 0.001;
      final c = _D20.faces[i];
      final path = Path()
        ..moveTo(point(verts[c[0]]).dx, point(verts[c[0]]).dy)
        ..lineTo(point(verts[c[1]]).dx, point(verts[c[1]]).dy)
        ..lineTo(point(verts[c[2]]).dx, point(verts[c[2]]).dy)
        ..close();
      var light = 0.16 + 0.84 * max(0.0, _D20._dot(n, _lamp));
      if (wins) light = min(1.0, light + 0.4 * highlight);
      canvas.drawPath(path, Paint()..color = _mix(light));
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = stroke * (wins ? 1 + 1.3 * highlight : 1)
          ..color = wins ? const Color(0xF21C160E) : const Color(0x80261E14),
      );
    }

    for (final i in order) {
      final n = _D20.rotate(q, _D20.normals[i]);
      final wins = i == dice.face;
      if (n[2] <= 0.28 && !wins) continue;
      final c = _D20.faces[i];
      final center = [
        (verts[c[0]][0] + verts[c[1]][0] + verts[c[2]][0]) / 3,
        (verts[c[0]][1] + verts[c[1]][1] + verts[c[2]][1]) / 3,
        (verts[c[0]][2] + verts[c[1]][2] + verts[c[2]][2]) / 3,
      ];
      final seen = pow(max(0.0, n[2]), 1.7).toDouble();
      final alpha = wins ? max(seen, highlight) : seen * (1 - 0.85 * highlight);
      if (alpha < 0.01) continue;
      final fontSize =
          radius *
          0.32 *
          (0.5 + 0.5 * n[2]) *
          (wins ? 1 + 0.26 * highlight : 1);
      final text = TextPainter(
        text: TextSpan(
          text: '${dice.nums[i]}',
          style: TextStyle(
            color: const Color(
              0xFF241D12,
            ).withValues(alpha: alpha.clamp(0.0, 1.0)),
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            shadows: wins && highlight > 0.01
                ? [
                    Shadow(
                      color: const Color(0x80180E0A),
                      blurRadius: radius * 0.3 * highlight,
                    ),
                  ]
                : null,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final p = point(center);
      text.paint(
        canvas,
        p - Offset(text.width / 2, text.height / 2 - fontSize * 0.06),
      );
    }
  }

  @override
  bool shouldRepaint(_D20Painter old) => true;
}

// --- El duelo ---------------------------------------------------------------

/// Piedra, papel o tijera con las tres cartas de Unglued. Cada una dice a
/// quién gana: «Rock Lobster» a «Scissors Lizard», este a «Paper Tiger» y
/// este a «Rock Lobster».
enum _Gesture {
  rock('Piedra', 'piedra'),
  paper('Papel', 'papel'),
  scissors('Tijera', 'tijeras');

  const _Gesture(this.label, this.file);

  final String label;
  final String file;

  _Gesture get beats => switch (this) {
    rock => scissors,
    paper => rock,
    scissors => paper,
  };
}

class _DuelDraw extends StatefulWidget {
  const _DuelDraw({required this.flipTop});

  final bool flipTop;

  @override
  State<_DuelDraw> createState() => _DuelDrawState();
}

class _DuelDrawState extends State<_DuelDraw>
    with SingleTickerProviderStateMixin {
  // El reparto se ve un momento boca abajo antes de girar, y la corona sale a
  // mitad del giro, en cuanto la cara empieza a verse.
  static const int _dealMs = 380;
  static const int _flipMs = 620;
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _dealMs + _flipMs),
  );
  late _Gesture _top;
  late _Gesture _bottom;

  @override
  void initState() {
    super.initState();
    _dealCards();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _dealCards() {
    final all = List.of(_Gesture.values);
    final first = all.removeAt(_random.nextInt(3));
    setState(() {
      _top = first;
      _bottom = all[_random.nextInt(2)];
    });
    _c.forward(from: 0);
  }

  bool get _topWins => _top.beats == _bottom;

  @override
  Widget build(BuildContext context) {
    Widget side(_Gesture card, bool wins, bool top) {
      final content = AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final ms = _c.value * (_dealMs + _flipMs);
          final turn = ((ms - _dealMs) / _flipMs).clamp(0.0, 1.0);
          final eased = Curves.easeOutCubic.transform(turn);
          final angle = pi * (1 - eased);
          final shown = ms >= _dealMs + _flipMs / 2;
          // La carta ocupa todo el sitio: el aviso de quién gana va encima
          // de ella, no aparte, y la que pierde se apaga un poco.
          return Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                AnimatedOpacity(
                  opacity: shown && !wins ? 0.55 : 1,
                  duration: const Duration(milliseconds: 300),
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001)
                      ..rotateY(angle),
                    child: _DuelCard(gesture: card, faceUp: angle < pi / 2),
                  ),
                ),
                Positioned(
                  top: -20,
                  child: AnimatedOpacity(
                    opacity: shown && wins ? 1 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(12, 4, 16, 4),
                      decoration: BoxDecoration(
                        color: kAccent,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: const [
                          BoxShadow(color: Color(0x99000000), blurRadius: 10),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.emoji_events,
                            color: Color(0xFF1A1306),
                            size: 24,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'GANA',
                            style: withFont(
                              'Barlow Condensed',
                              const TextStyle(
                                color: Color(0xFF1A1306),
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
      // Sin Center: con él la caja solo encogía la carta, nunca la agrandaba,
      // y se quedaba en su tamaño base aunque sobrara sitio.
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: FittedBox(
            child: top && widget.flipTop
                ? RotatedBox(quarterTurns: 2, child: content)
                : content,
          ),
        ),
      );
    }

    return Column(
      children: [
        side(_top, _topWins, true),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: _Buttons(again: _dealCards, againLabel: 'Repartir'),
        ),
        side(_bottom, !_topWins, false),
      ],
    );
  }
}

class _DuelCard extends StatelessWidget {
  const _DuelCard({required this.gesture, required this.faceUp});

  final _Gesture gesture;
  final bool faceUp;

  @override
  Widget build(BuildContext context) {
    final image = faceUp
        ? 'assets/images/sorteos/${gesture.file}.jpg'
        : 'assets/images/sorteos/dorso.jpg';
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        Container(
          width: 176,
          height: 246,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            boxShadow: const [
              BoxShadow(
                color: Color(0xE6000000),
                offset: Offset(0, 12),
                blurRadius: 26,
                spreadRadius: -8,
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          // Boca abajo el dorso se pinta del revés: el giro lo endereza.
          child: Transform(
            alignment: Alignment.center,
            transform: faceUp
                ? Matrix4.identity()
                : (Matrix4.identity()..rotateY(pi)),
            child: Image.asset(image, fit: BoxFit.cover),
          ),
        ),
        if (faceUp)
          Positioned(
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF0D0D0D),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                gesture.label.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
