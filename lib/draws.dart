import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mtglifecounter/hand_motion.dart';
import 'package:mtglifecounter/look.dart';
import 'package:mtglifecounter/settings_page.dart';

// Los tres sorteos de la barra: moneda, dado D20 y duelo de piedra, papel o
// tijera. Están portados del contador de mtgtournament (site.js y site.css).
// Van en una pantalla completa con una pestaña para cada uno. El resultado
// sale una sola vez, derecho para quien tiene el móvil: la moneda y el dado
// se leen desde los dos lados. Solo el duelo gira la carta de arriba si el
// jugador de arriba está enfrente.

final Random _random = Random();

/// Los sorteos, en el orden de las pestañas.
enum DrawKind {
  coin('Moneda', Icons.toll_outlined),
  dice('Dado', Icons.casino_outlined),
  duel('Duelo', Icons.style_outlined);

  const DrawKind(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// Abre los sorteos a pantalla completa, en [initial] (el dado si no se dice
/// otro). Se cierra solo con su botón: tocar fuera no lo cierra, para no
/// perder el resultado por un toque sin querer.
Future<void> showDraws(
  BuildContext context, {
  required bool flipTop,
  DrawKind initial = DrawKind.dice,
}) {
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: false,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, _) => FadeTransition(
        opacity: animation,
        child: Material(
          color: const Color(0xE6080809),
          child: SafeArea(
            child: _DrawsScreen(flipTop: flipTop, initial: initial),
          ),
        ),
      ),
    ),
  );
}

/// Las pestañas arriba y debajo el sorteo elegido. Al cambiar de pestaña el
/// sorteo nuevo se lanza solo, como al abrirlo.
class _DrawsScreen extends StatefulWidget {
  const _DrawsScreen({required this.flipTop, required this.initial});

  final bool flipTop;
  final DrawKind initial;

  @override
  State<_DrawsScreen> createState() => _DrawsScreenState();
}

class _DrawsScreenState extends State<_DrawsScreen> {
  late DrawKind _kind = widget.initial;

  @override
  Widget build(BuildContext context) {
    final draw = switch (_kind) {
      DrawKind.coin => const _CoinDraw(),
      DrawKind.dice => const _DiceDraw(),
      DrawKind.duel => _DuelDraw(flipTop: widget.flipTop),
    };
    return Column(
      children: [
        _DrawTabs(
          selected: _kind,
          onSelect: (kind) {
            if (kind != _kind) setState(() => _kind = kind);
          },
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: KeyedSubtree(key: ValueKey(_kind), child: draw),
          ),
        ),
      ],
    );
  }
}

class _DrawTabs extends StatelessWidget {
  const _DrawTabs({required this.selected, required this.onSelect});

  final DrawKind selected;
  final ValueChanged<DrawKind> onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(20),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          children: [
            for (final kind in DrawKind.values)
              Expanded(
                child: _DrawTab(
                  kind: kind,
                  selected: kind == selected,
                  onTap: () => onSelect(kind),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DrawTab extends StatelessWidget {
  const _DrawTab({
    required this.kind,
    required this.selected,
    required this.onTap,
  });

  final DrawKind kind;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFF1A1306) : Colors.white70;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 44,
          decoration: BoxDecoration(
            color: selected ? kAccent : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(kind.icon, color: color, size: 20),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  kind.label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// El sitio del sorteo, el rótulo del resultado y los botones.
class _DrawLayout extends StatelessWidget {
  const _DrawLayout({
    required this.label,
    required this.visible,
    required this.center,
    required this.again,
    required this.againLabel,
    this.hint,
  });

  final String label;
  final bool visible;

  /// Ocupa todo el sitio que queda encima del rótulo.
  final Widget center;
  final VoidCallback again;
  final String againLabel;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: center),
        AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 300),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: withFont(
                  'Barlow Condensed',
                  const TextStyle(
                    color: kAccent,
                    fontSize: 48,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 6,
                  ),
                ),
              ),
            ),
          ),
        ),
        _Footer(again: again, againLabel: againLabel, hint: hint),
      ],
    );
  }
}

/// Los botones y la línea de ayuda. Ocupa lo mismo en los tres sorteos, con
/// ayuda o sin ella, para que los botones no salten al cambiar de pestaña.
class _Footer extends StatelessWidget {
  const _Footer({required this.again, required this.againLabel, this.hint});

  final VoidCallback again;
  final String againLabel;

  /// Una línea bajo los botones, para contar que también se lanza moviendo
  /// el móvil.
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: _Buttons(again: again, againLabel: againLabel),
        ),
        AnimatedOpacity(
          opacity: hint == null ? 0 : 1,
          duration: const Duration(milliseconds: 400),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.vibration, color: Colors.white54, size: 16),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  hint ?? '',
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
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
    // Encogen si la pantalla no llega para los dos de 140.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: SizedBox(
              width: 140,
              child: FilledButton.tonal(
                onPressed: again,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: Text(againLabel),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: SizedBox(
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
          ),
        ],
      ),
    );
  }
}

// --- La moneda ----------------------------------------------------------

/// Cara es el Chaos Orb y cruz el Ankh of Mishra. El ángulo final decide la
/// cara: un múltiplo de una vuelta acaba de cara y media vuelta más, de cruz,
/// así que la moneda se posa en la que ha salido sin ningún salto.
class _CoinDraw extends StatefulWidget {
  const _CoinDraw();

  @override
  State<_CoinDraw> createState() => _CoinDrawState();
}

/// Un lanzamiento de verdad: la moneda se encoge un poco al impulsarla, sube
/// girando hacia el que mira, cae, da dos botes cada vez más bajos y se
/// asienta bamboleándose. Al girar se ve su canto y le pasa un brillo.
///
/// También se lanza con un golpe de muñeca de arriba abajo: cuanto más fuerte,
/// más sube y más vueltas da. El vuelo dura lo que tardaría en caer desde esa
/// altura (crece con la raíz de la altura), como una moneda de verdad.
class _CoinDrawState extends State<_CoinDraw>
    with SingleTickerProviderStateMixin {
  // Fuerza del botón: la del lanzamiento de siempre.
  static const double _buttonStrength = 0.45;

  // El impulso y los botes, en ms; el vuelo depende de la altura.
  static const int _liftMs = 114;
  static const int _bounceMs = 532;

  // Lo que queda echada hacia atrás en la mesa, en radianes.
  static const double _rest = -0.5;

  late final AnimationController _c = AnimationController(vsync: this)
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        setState(() {
          _shown = true;
          _label = _heads ? 'Cara' : 'Cruz';
        });
      }
    });
  late final HandMotion _motion = HandMotion(_onMotion);
  late final FlickDetector _flick = FlickDetector((strength) {
    // Mientras vuela no se le puede volver a dar.
    if (mounted && !_c.isAnimating) _throw(strength: strength);
  });
  bool _sensing = false;
  bool _heads = true;

  // El rótulo cambia al acabar la tirada, no al empezar: si no, mientras se
  // desvanece enseñaría el resultado antes de tiempo.
  String _label = 'Cara';
  bool _shown = false;

  // Duración total, tramos del tiempo total (impulso, vuelo y botes) y altura
  // del vuelo en dp. Cambian con la fuerza de cada tirada.
  int _ms = 1900;
  double _lift = 0.06;
  double _land = 0.72;
  double _height = 190;

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
    _motion.start();
    _throw();
  }

  void _onMotion(HandSample sample) {
    // La primera lectura dice que hay sensor: entonces se cuenta el gesto.
    if (!_sensing && mounted) setState(() => _sensing = true);
    _flick.add(sample);
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
    _motion.stop();
    _c.dispose();
    super.dispose();
  }

  /// Lanza la moneda con una fuerza de 0 a 1.
  void _throw({double strength = _buttonStrength}) {
    final heads = _random.nextBool();
    final id = ++_throwId;
    // De 120 a 270 dp de altura; el vuelo, como una caída libre.
    final height = 120 + 150 * strength;
    final flightMs = 91 * sqrt(height);
    final ms = (_liftMs + flightMs + _bounceMs * sqrt(height / 190)).round();
    setState(() {
      _heads = heads;
      _shown = false;
      _height = height;
      _ms = ms;
      _lift = _liftMs / ms;
      _land = (_liftMs + flightMs) / ms;
      // Sale de donde quedó la anterior y da más medias vueltas cuanto más
      // fuerte: de 10 a 27.
      _fromHalf = _toHalf;
      _toHalf =
          _fromHalf +
          2 * (5 + (6 * strength).round() + _random.nextInt(3)) +
          ((heads ? 0 : 1) + _fromHalf) % 2;
      _tilt = (_random.nextDouble() * 2 - 1) * (0.14 + 0.16 * strength);
    });
    _c.duration = Duration(milliseconds: ms);
    _c.forward(from: 0);
    if (strength > 0.7) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact();
    }
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
      label: _label,
      visible: _shown,
      again: _throw,
      againLabel: 'Lanzar',
      hint: _sensing ? 'O lánzala con un golpe de muñeca' : null,
      // Abajo, para que suba por todo el sitio libre de encima.
      center: Align(
        alignment: Alignment.bottomCenter,
        child: SizedBox(
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
                final drop = _height / 190;
                height = q < 0.45
                    ? 22 * drop * sin(pi * q / 0.45)
                    : q < 0.72
                    ? 7 * drop * sin(pi * (q - 0.45) / 0.27)
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
  const _DiceDraw();

  @override
  State<_DiceDraw> createState() => _DiceDrawState();
}

/// El dado se tira con el botón o agitando el móvil como un cubilete, y usa
/// toda la pantalla. Al tirarlo entra desde el borde de uno de los jugadores,
/// choca con una pared y se para en medio. Agitándolo corre por la pantalla
/// empujado por la mano y rebota en los bordes; al parar la mano sale rodando
/// desde donde esté, con más vueltas cuanto más se ha agitado.
class _DiceDrawState extends State<_DiceDraw>
    with SingleTickerProviderStateMixin {
  // Fuerza del botón.
  static const double _buttonStrength = 0.5;

  // Instantes de los botes, como fracción de la tirada (ver [_D20.height]).
  static const List<double> _bounces = [0.46, 0.74, 0.90];

  static const double _radius = 80;

  // Cuándo acaba el recorrido por la mesa: después solo bota en su sitio.
  static const double _arrive = 0.92;

  // Cubilete: cuánto empuja la mano (dp/s² por m/s²), lo que frena la mesa
  // (lo que queda de velocidad tras un segundo), lo que rebota en los bordes
  // y la velocidad máxima.
  static const double _push = 2600;
  static const double _friction = 0.25;
  static const double _bounce = 0.65;
  static const double _maxSpeed = 2600;

  final _D20 _dice = _D20();
  final GlobalKey _areaKey = GlobalKey();
  final GlobalKey _slotKey = GlobalKey();
  late final AnimationController _c = AnimationController(vsync: this)
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        _dice.settle();
        setState(() {
          _shown = true;
          _shownValue = _value;
        });
      }
    });
  late final HandMotion _motion = HandMotion(_onMotion);
  late final ShakeDetector _shake = ShakeDetector(
    onShake: _rattle,
    // Cada sacudida lo hace saltar un poco.
    onStroke: () => _hop = 1,
    onRelease: (strength) => _roll(strength: 0.3 + 0.7 * strength),
  );
  int _value = 20;

  // Lo que dice el rótulo: cambia al acabar la tirada (ver [_CoinDrawState]).
  int _shownValue = 20;
  bool _shown = false;
  bool _sensing = false;
  int _rollId = 0;

  // La pantalla y el centro del hueco donde se para el dado, medidos al
  // pintar. Las posiciones del dado van relativas a ese centro.
  Size _area = Size.zero;
  Offset? _rest;

  // El recorrido de la tirada: de dónde sale y la pared en que choca.
  Offset _from = Offset.zero;
  Offset _wall = Offset.zero;

  // Dentro del cubilete: posición, velocidad (dp/s) y el salto que le queda.
  bool _inCup = false;
  Offset _pos = Offset.zero;
  Offset _vel = Offset.zero;
  double _hop = 0;
  DateTime _lastSample = DateTime(0);
  DateTime _lastKnock = DateTime(0);

  @override
  void initState() {
    super.initState();
    _motion.start();
    // La primera tirada espera a saber cuánto mide la pantalla.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _measure();
      _roll();
    });
    _D20Painter.loadTexture().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _motion.stop();
    _c.dispose();
    super.dispose();
  }

  void _measure() {
    final area = _areaKey.currentContext?.findRenderObject() as RenderBox?;
    final slot = _slotKey.currentContext?.findRenderObject() as RenderBox?;
    if (area == null || slot == null || !area.hasSize || !slot.hasSize) return;
    final rest = area.globalToLocal(
      slot.localToGlobal(slot.size.center(Offset.zero)),
    );
    if (rest != _rest || area.size != _area) {
      setState(() {
        _rest = rest;
        _area = area.size;
      });
    }
  }

  /// Hasta dónde puede ir el centro del dado sin salirse, relativo al hueco.
  Rect get _bounds {
    final rest = _rest ?? Offset.zero;
    return Rect.fromLTRB(
      _radius - rest.dx,
      _radius * 1.2 - rest.dy,
      _area.width - _radius - rest.dx,
      _area.height - _radius * 1.4 - rest.dy,
    );
  }

  void _onMotion(HandSample sample) {
    if (!mounted) return;
    if (!_sensing) setState(() => _sensing = true);
    _shake.add(sample);
  }

  /// Dónde va el dado en el instante [t] de la tirada: frena como si rozara
  /// la mesa, de [_from] a [_wall] y de ahí al hueco.
  Offset _travel(double t) {
    final first = (_wall - _from).distance;
    final total = max(1.0, first + _wall.distance);
    final u = min(1.0, t / _arrive);
    final s = (1 - pow(1 - u, 2.2)) * total;
    return s < first
        ? Offset.lerp(_from, _wall, s / first)!
        : Offset.lerp(_wall, Offset.zero, (s - first) / (total - first))!;
  }

  /// El instante de la tirada en que llega a la pared.
  double get _wallTime {
    final first = (_wall - _from).distance;
    final e = first / max(1.0, first + _wall.distance);
    return _arrive * (1 - pow(1 - e, 1 / 2.2));
  }

  /// El dado dentro del cubilete: la mano lo empuja (se queda atrás cuando
  /// acelera), la mesa lo frena, rueda lo que avanza y rebota en los bordes.
  void _rattle(HandSample s) {
    final now = DateTime.now();
    if (!_inCup) {
      // Si estaba rodando, se recoge donde esté.
      _pos = _c.isAnimating ? _travel(_c.value) : Offset.zero;
      _vel = Offset.zero;
      _dice.hold(_c.isAnimating ? _c.value : 1);
      _c.stop();
      _rollId++;
      _inCup = true;
      _shown = false;
      _lastSample = now;
    }
    final dt = (now.difference(_lastSample).inMicroseconds / 1e6).clamp(
      0.0,
      0.05,
    );
    _lastSample = now;
    var vel = _vel + Offset(-s.x, s.y) * (_push * dt);
    vel *= pow(_friction, dt).toDouble();
    if (vel.distance > _maxSpeed) vel = vel / vel.distance * _maxSpeed;
    var pos = _pos + vel * dt;
    final b = _bounds;
    var knock = false;
    if (pos.dx < b.left || pos.dx > b.right) {
      pos = Offset(pos.dx.clamp(b.left, b.right), pos.dy);
      vel = Offset(-vel.dx * _bounce, vel.dy);
      knock = true;
    }
    if (pos.dy < b.top || pos.dy > b.bottom) {
      pos = Offset(pos.dx, pos.dy.clamp(b.top, b.bottom));
      vel = Offset(vel.dx, -vel.dy * _bounce);
      knock = true;
    }
    // Rueda: gira lo que avanza dividido por su radio.
    _dice.spin((pos - _pos).distance / _radius);
    if (knock &&
        vel.distance > 150 &&
        now.difference(_lastKnock).inMilliseconds > 70) {
      // Golpe contra el borde.
      _lastKnock = now;
      HapticFeedback.selectionClick();
      _dice.spin(0.6 + _random.nextDouble());
    }
    setState(() {
      _pos = pos;
      _vel = vel;
      _hop = max(0.0, _hop - dt * 4);
    });
  }

  void _roll({double strength = _buttonStrength}) {
    final id = ++_rollId;
    final b = _bounds;
    // Del cubilete sale desde donde esté y hacia donde iba; con el botón, del
    // borde de uno de los dos jugadores.
    final from = _inCup
        ? _pos
        : Offset(
            ui.lerpDouble(b.left, b.right, _random.nextDouble())!,
            _random.nextBool() ? b.bottom : b.top,
          );
    final right = _inCup && _vel.dx.abs() > 50
        ? _vel.dx > 0
        : _random.nextBool();
    final wall = Offset(
      right ? b.right : b.left,
      ui.lerpDouble(b.top * 0.6, b.bottom * 0.6, _random.nextDouble())!,
    );
    _dice.settle();
    final ms = (900 + 600 * strength).round();
    setState(() {
      _value = _dice.roll(strength: strength);
      _shown = false;
      _inCup = false;
      _hop = 0;
      _from = from;
      _wall = wall;
    });
    _c.duration = Duration(milliseconds: ms);
    _c.forward(from: 0);
    // Un golpe seco contra la pared y en cada bote contra la mesa.
    for (final at in [_wallTime, ..._bounces]) {
      Future<void>.delayed(Duration(milliseconds: (at * ms).round()), () {
        if (mounted && id == _rollId) HapticFeedback.selectionClick();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Si cambia el tamaño (o al principio), se vuelve a medir tras pintar.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _measure();
    });
    final rest = _rest;
    return Stack(
      key: _areaKey,
      children: [
        _DrawLayout(
          label: 'Ha salido $_shownValue',
          visible: _shown,
          again: _roll,
          againLabel: 'Tirar',
          hint: _sensing ? 'O agita el móvil como un cubilete' : null,
          // El hueco donde se para; el dado se pinta encima, sobre toda la
          // pantalla, para que pueda recorrerla.
          center: Center(
            child: SizedBox(key: _slotKey, width: 240, height: 240),
          ),
        ),
        if (rest != null)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _c,
                builder: (context, _) {
                  final rolling = _c.isAnimating;
                  final t = rolling ? _c.value : 1.0;
                  final Offset at;
                  final double lift;
                  if (rolling) {
                    at = _travel(t);
                    lift = -_D20.height(t);
                  } else if (_inCup) {
                    at = _pos;
                    lift = 0.35 * _hop;
                  } else {
                    at = Offset.zero;
                    lift = 0;
                  }
                  return CustomPaint(
                    painter: _D20Painter(
                      _dice,
                      t,
                      center: rest + at,
                      radius: _radius,
                      lift: lift,
                    ),
                  );
                },
              ),
            ),
          ),
      ],
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
    final front = _bring(_normals[face], _rest);
    turn = _mul(_straighten(front, face), front);
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

  /// El giro sobre la dirección de reposo que endereza el número de la cara
  /// [cara] cuando el dado está en [q] con esa cara de frente. El número mira
  /// hacia el primer vértice de su cara (ver [_D20Painter]), y ese vértice
  /// tiene que quedar arriba en la pantalla.
  static _Q _straighten(_Q q, int cara) {
    final v = vertices[faces[cara][0]];
    final n = _normals[cara];
    final d = _dot(v, n);
    final u = rotate(q, [v[0] - d * n[0], v[1] - d * n[1], v[2] - d * n[2]]);
    final r = _rest;
    // «Arriba» de la pantalla, sobre el plano de la cara en reposo.
    final w = [-r[1] * r[0], 1 - r[1] * r[1], -r[1] * r[2]];
    final cross = [
      u[1] * w[2] - u[2] * w[1],
      u[2] * w[0] - u[0] * w[2],
      u[0] * w[1] - u[1] * w[0],
    ];
    return _axis(r, atan2(_dot(cross, r), _dot(u, w)));
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
  int roll({double strength = 0.5}) {
    final result = 1 + _random.nextInt(20);
    final start = turn;
    // Más fuerza, más vueltas: de 1,5 a 5,5.
    final axisA = _randomAxis(),
        angleA = pi * 2 * (1.5 + 2.5 * strength + _random.nextDouble() * 1.5);
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
    // Al final se corrige el giro para que la cara quede mirando de frente
    // y con el número derecho.
    final front = _bring(rotate(raw, _normals[best]), _rest);
    final end = _mul(_straighten(_mul(front, raw), best), front);
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

  /// Para el dado donde esté en el instante [t] de la tirada, sin resultado.
  void hold(double t) {
    turn = at(t);
    _path = null;
    highlight = 0;
  }

  /// Lo gira [angle] radianes sobre un eje al azar, como al chocar dentro del
  /// cubilete.
  void spin(double angle) {
    turn = _mul(_axis(_randomAxis(), angle), turn);
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

/// Pinta el dado como uno de resina: cada cara lleva su trozo de una textura
/// jaspeada, se sombrea según mira a la luz y, la que la refleja hacia quien
/// mira, brilla. Las aristas, redondeadas como las de un dado de verdad,
/// cogen luz, y los números van grabados en dorado sobre el plano de su cara,
/// así que se ven torcidos y en escorzo cuando la cara se inclina.
class _D20Painter extends CustomPainter {
  _D20Painter(
    this.dice,
    this.t, {
    required this.center,
    required this.radius,
    this.lift = 0,
  });

  final _D20 dice;
  final double t;

  /// Dónde está el dado sobre la mesa (el sitio de su sombra) y su radio.
  final Offset center;
  final double radius;

  /// Lo alto que va, de 0 (en la mesa) a 1 (lo más alto de la tirada).
  final double lift;

  static final _V _lamp = _D20._unit([-0.42, 0.72, 0.55]);
  static const double _rise = 1.5;

  // Píxeles de la textura y de los números por unidad del dado (el radio).
  static const double _px = 160;
  static const int _texSize = 256;

  static const Color _resin = Color(0xFF7A1824);
  static const Color _ink = Color(0xFFE9C772);

  static ui.Image? _texture;
  static Future<void>? _loading;

  /// Genera la textura la primera vez; luego la deja guardada.
  static Future<void> loadTexture() =>
      _loading ??= _makeTexture().then((image) => _texture = image);

  /// Resina granate jaspeada: un ruido fractal que retuerce unas vetas, con
  /// remolinos más claros, vetas oscuras y alguna chispa de purpurina. Se
  /// repite sin costuras para poder cubrir cualquier cara.
  static Future<ui.Image> _makeTexture() {
    const n = _texSize;
    final rnd = Random(20);
    const grid = 64;
    final lattice = List.generate(grid * grid, (_) => rnd.nextDouble());
    double smooth(double x) => x * x * (3 - 2 * x);
    double noise(double x, double y, int period) {
      final x0 = x.floor(), y0 = y.floor();
      final fx = smooth(x - x0), fy = smooth(y - y0);
      double at(int i, int j) => lattice[(j % period) * grid + (i % period)];
      final a = at(x0, y0), b = at(x0 + 1, y0);
      final c = at(x0, y0 + 1), d = at(x0 + 1, y0 + 1);
      return a + (b - a) * fx + (c - a) * fy + (a - b - c + d) * fx * fy;
    }

    // Cuatro octavas que se repiten cada 1 en u y en v.
    double fbm(double u, double v) {
      var sum = 0.0, amp = 0.5;
      for (var f = 4; f <= 32; f *= 2) {
        sum += amp * noise(u * f, v * f, f);
        amp /= 2;
      }
      return sum / 0.9375;
    }

    Color mix(Color a, Color b, num k) =>
        Color.lerp(a, b, k.toDouble().clamp(0.0, 1.0))!;
    const deep = Color(0xFF3E0A12);
    const mid = Color(0xFF8E1F2B);
    const swirl = Color(0xFFD25A47);
    const vein = Color(0xFF1A0407);
    const fleck = Color(0xFFF2D68A);

    final pixels = Uint8List(n * n * 4);
    for (var y = 0; y < n; y++) {
      for (var x = 0; x < n; x++) {
        final u = x / n, v = y / n;
        final f = fbm(u, v);
        final stripe = sin(2 * pi * (2 * u + v + 2.4 * f));
        var color = mix(deep, mid, smooth(f.clamp(0.0, 1.0)) * 1.3 - 0.1);
        color = mix(color, swirl, 0.75 * pow((stripe + 1) / 2, 4));
        color = mix(color, vein, 0.7 * pow(1 - stripe.abs(), 14));
        if (rnd.nextDouble() < 0.003) color = mix(color, fleck, 0.85);
        final grain = (rnd.nextDouble() - 0.5) * 10;
        final o = (y * n + x) * 4;
        pixels[o] = (color.r * 255 + grain).round().clamp(0, 255);
        pixels[o + 1] = (color.g * 255 + grain).round().clamp(0, 255);
        pixels[o + 2] = (color.b * 255 + grain).round().clamp(0, 255);
        pixels[o + 3] = 255;
      }
    }
    final done = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      pixels,
      n,
      n,
      ui.PixelFormat.rgba8888,
      done.complete,
    );
    return done.future;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final q = dice.at(t);

    // La sombra se queda en la mesa y se encoge y se aclara cuando el dado
    // sube; el dado sube y crece un poco, como si se acercara.
    final h = lift.clamp(0.0, 1.0);
    final rx = this.radius * (0.92 - h * 0.3);
    canvas.drawOval(
      Rect.fromCenter(
        center: center + Offset(0, this.radius * 1.1),
        width: rx * 2,
        height: rx * 0.4,
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.6 * (1 - h * 0.62))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    final radius = this.radius * (1 + 0.2 * h);
    final cx = center.dx;
    final cy = center.dy - h * this.radius * _rise;
    final verts = _D20.vertices.map((v) => _D20.rotate(q, v)).toList();
    Offset point(_V v) => Offset(cx + v[0] * radius, cy - v[1] * radius);
    final stroke = max(1.0, radius * 0.015);
    final highlight = dice.highlight;
    final texture = _texture;
    final k = radius / _px;

    for (var i = 0; i < 20; i++) {
      final n = _D20.rotate(q, _D20.normals[i]);
      // Un dado es convexo: con quitar las caras de detrás basta, no hay que
      // ordenarlas.
      if (n[2] <= 0.02) continue;
      final wins = i == dice.face && highlight > 0.001;
      final c = _D20.faces[i];
      final a = verts[c[0]], b = verts[c[1]], d = verts[c[2]];
      final path = Path()
        ..moveTo(point(a).dx, point(a).dy)
        ..lineTo(point(b).dx, point(b).dy)
        ..lineTo(point(d).dx, point(d).dy)
        ..close();

      // El plano de la cara: «arriba» apunta a su primer vértice, como en los
      // dados de verdad, y «derecha» sale de arriba y de la normal. [frame]
      // lleva un punto de ese plano, en píxeles de textura, a la pantalla.
      final center = [
        (a[0] + b[0] + d[0]) / 3,
        (a[1] + b[1] + d[1]) / 3,
        (a[2] + b[2] + d[2]) / 3,
      ];
      final up = _D20._unit([
        a[0] - center[0],
        a[1] - center[1],
        a[2] - center[2],
      ]);
      final right = [
        up[1] * n[2] - up[2] * n[1],
        up[2] * n[0] - up[0] * n[2],
        up[0] * n[1] - up[1] * n[0],
      ];
      final origin = point(center);
      final frame = Matrix4(
        k * right[0],
        -k * right[1],
        0,
        0, //
        -k * up[0],
        k * up[1],
        0,
        0, //
        0,
        0,
        1,
        0, //
        origin.dx,
        origin.dy,
        0,
        1,
      );

      // La resina, cada cara con su trozo de textura.
      final fill = Paint()..color = _resin;
      if (texture != null) {
        final from = Matrix4.copy(frame)
          ..translateByDouble(
            -((i * 73) % _texSize).toDouble(),
            -((i * 151) % _texSize).toDouble(),
            0,
            1,
          );
        fill.shader = ImageShader(
          texture,
          TileMode.repeated,
          TileMode.repeated,
          from.storage,
          filterQuality: FilterQuality.medium,
        );
      }
      canvas.drawPath(path, fill);

      // Luz y sombra según mira a la lámpara; la que ha salido se aclara.
      final facing = _D20._dot(n, _lamp);
      var light = 0.2 + 0.8 * max(0.0, facing);
      if (wins) light = min(1.0, light + 0.3 * highlight);
      canvas.drawPath(
        path,
        Paint()..color = Colors.black.withValues(alpha: 0.78 * (1 - light)),
      );

      // Brillo: el reflejo de la lámpara visto desde delante.
      final reflect = 2 * facing * n[2] - _lamp[2];
      final spec = pow(max(0.0, reflect), 22).toDouble();
      if (spec > 0.01) {
        canvas.drawPath(
          path,
          Paint()
            ..shader = ui.Gradient.linear(
              point(a),
              Offset.lerp(point(b), point(d), 0.5)!,
              [
                Colors.white.withValues(alpha: 0.75 * spec),
                Colors.white.withValues(alpha: 0.2 * spec),
              ],
            ),
        );
      }

      // Aristas: una junta fina y oscura y, encima, el bisel que coge luz.
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = stroke * 1.6
          ..color = const Color(0x8C12030A),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = stroke * 0.8
          ..color = Colors.white.withValues(
            alpha: 0.08 + 0.32 * pow(max(0.0, facing), 2),
          ),
      );
      if (wins) {
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeJoin = StrokeJoin.round
            ..strokeWidth = stroke * 2.4
            ..color = kAccent.withValues(alpha: 0.9 * highlight),
        );
      }

      // El número, grabado: una sombra arriba, una luz abajo y la tinta.
      if (n[2] < 0.12 && !wins) continue;
      final value = dice.nums[i];
      final alpha = wins
          ? 1.0
          : (min(1.0, (n[2] - 0.12) * 3) * (1 - 0.4 * highlight)).clamp(
              0.0,
              1.0,
            );
      final grow = wins ? 1 + 0.12 * highlight : 1.0;
      TextPainter label(Color color, {List<Shadow>? shadows}) => TextPainter(
        text: TextSpan(
          text: '$value',
          style: withFont(
            'Vollkorn',
            TextStyle(
              color: color.withValues(alpha: color.a * alpha),
              fontSize: _px * 0.36 * grow,
              fontWeight: FontWeight.w800,
              height: 1,
              shadows: shadows,
            ),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final ink = label(
        _ink,
        shadows: wins && highlight > 0.01
            ? [
                Shadow(
                  color: kAccent.withValues(alpha: highlight),
                  blurRadius: 18 * highlight,
                ),
              ]
            : null,
      );
      final at = Offset(-ink.width / 2, -ink.height / 2);
      canvas.save();
      canvas.transform(frame.storage);
      label(const Color(0xB3000000)).paint(canvas, at + const Offset(-1, -1.6));
      label(const Color(0x40FFFFFF)).paint(canvas, at + const Offset(1, 1.6));
      ink.paint(canvas, at);
      // El 6 y el 9 van subrayados para no confundirlos.
      if (value == 6 || value == 9) {
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(0, ink.height * 0.55),
            width: ink.width * 0.8,
            height: _px * 0.03,
          ),
          Paint()..color = _ink.withValues(alpha: alpha),
        );
      }
      canvas.restore();
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

class _DuelDrawState extends State<_DuelDraw> with TickerProviderStateMixin {
  // El reparto se ve un momento boca abajo antes de girar, y el aura y el
  // trofeo salen a mitad del giro, en cuanto la cara empieza a verse.
  static const int _dealMs = 380;
  static const int _flipMs = 620;
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _dealMs + _flipMs),
  );
  // El latido del aura de la carta que gana.
  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
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
    _glow.dispose();
    super.dispose();
  }

  void _dealCards() {
    final all = List.of(_Gesture.values);
    final first = all.removeAt(_random.nextInt(3));
    setState(() {
      _top = first;
      _bottom = all[_random.nextInt(2)];
    });
    _glow.value = 0;
    _c.forward(from: 0).then((_) {
      if (mounted) _glow.repeat(reverse: true);
    });
  }

  bool get _topWins => _top.beats == _bottom;

  @override
  Widget build(BuildContext context) {
    Widget side(_Gesture card, bool wins, bool top) {
      final content = AnimatedBuilder(
        animation: Listenable.merge([_c, _glow]),
        builder: (context, _) {
          final ms = _c.value * (_dealMs + _flipMs);
          final turn = ((ms - _dealMs) / _flipMs).clamp(0.0, 1.0);
          final eased = Curves.easeOutCubic.transform(turn);
          final angle = pi * (1 - eased);
          final shown = ms >= _dealMs + _flipMs / 2;
          final crowned = shown && wins;
          final pulse = Curves.easeInOut.transform(_glow.value);
          // La carta ocupa todo el sitio. La que gana se rodea de un aura
          // dorada que late y lleva un trofeo pequeño en la esquina, que tapa
          // poco del dibujo; la que pierde se apaga un poco. El margen deja
          // sitio al aura y al trofeo dentro de la caja que se escala.
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                AnimatedOpacity(
                  opacity: crowned ? 1 : 0,
                  duration: const Duration(milliseconds: 350),
                  child: Container(
                    width: _DuelCard.width,
                    height: _DuelCard.height,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: kAccent.withValues(alpha: 0.55 + 0.3 * pulse),
                          blurRadius: 22 + 16 * pulse,
                          spreadRadius: 5 + 7 * pulse,
                        ),
                        BoxShadow(
                          color: const Color(
                            0xFFFFF1C4,
                          ).withValues(alpha: 0.35 + 0.25 * pulse),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
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
                // Filo dorado sobre el borde de la carta.
                AnimatedOpacity(
                  opacity: crowned ? 1 : 0,
                  duration: const Duration(milliseconds: 350),
                  child: Container(
                    width: _DuelCard.width,
                    height: _DuelCard.height,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Color.lerp(
                          kAccent,
                          const Color(0xFFFFF1C4),
                          0.5 * pulse,
                        )!,
                        width: 3,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: -16,
                  right: -16,
                  child: AnimatedScale(
                    scale: crowned ? 1 : 0.3,
                    curve: Curves.easeOutBack,
                    duration: const Duration(milliseconds: 400),
                    child: AnimatedOpacity(
                      opacity: crowned ? 1 : 0,
                      duration: const Duration(milliseconds: 250),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          color: kAccent,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Color(0x99000000), blurRadius: 10),
                          ],
                        ),
                        child: const Icon(
                          Icons.emoji_events,
                          color: Color(0xFF1A1306),
                          size: 26,
                        ),
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
          padding: const EdgeInsets.symmetric(horizontal: 4),
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
        side(_bottom, !_topWins, false),
        // El aura y el trofeo ya dicen quién gana, así que no lleva rótulo.
        _Footer(again: _dealCards, againLabel: 'Repartir'),
      ],
    );
  }
}

class _DuelCard extends StatelessWidget {
  const _DuelCard({required this.gesture, required this.faceUp});

  final _Gesture gesture;
  final bool faceUp;

  static const double width = 176;
  static const double height = 246;

  @override
  Widget build(BuildContext context) {
    final image = faceUp
        ? 'assets/images/sorteos/${gesture.file}.jpg'
        : 'assets/images/sorteos/dorso.jpg';
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        Container(
          width: width,
          height: height,
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
