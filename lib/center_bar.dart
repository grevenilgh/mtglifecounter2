import 'package:flutter/material.dart';
import 'package:mtglifecounter/look.dart';

/// Un botón de la barra central.
class BarAction {
  const BarAction(this.icon, this.tooltip, this.onPressed);

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
}

/// La barra entre los dos jugadores, con el aspecto de cada tema.
class CenterBar extends StatelessWidget {
  const CenterBar({
    super.key,
    required this.look,
    required this.color,
    required this.alpha,
    required this.leading,
    required this.trailing,
    this.stepper,
    this.timer,
    this.players,
  });

  final Look look;

  /// Color de la barra de la skin (el borde antiguo no lo usa).
  final Color color;

  /// Opacidad de la barra, de 0 a 1.
  final double alpha;
  final List<BarAction> leading;
  final List<BarAction> trailing;

  /// La cantidad por toque (− 1 +), si está activada en Ajustes. Recibe el
  /// color del texto, si debe ser la versión pequeña y si va como símbolo
  /// de maná (la del borde antiguo).
  final Widget Function(Color color, bool compact, bool mana)? stepper;

  /// El reloj de ronda, si está activado en Ajustes.
  final Widget? timer;

  /// Los marcos de los dos jugadores (arriba, abajo). En el borde antiguo la
  /// barra es una tierra doble de esos dos colores.
  final (CardFrame, CardFrame)? players;

  @override
  Widget build(BuildContext context) {
    // La barra tiene alto fijo y se encoge entera si no cabe: con la letra
    // del sistema muy grande, el reloj la ensanchaba tanto que los botones
    // se quedaban diminutos.
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: switch (look.theme) {
        AppTheme.original => _original(),
        AppTheme.modern => _floating(),
        AppTheme.classic => _leather(),
      },
    );
  }

  List<Widget> _items(Widget Function(BarAction) button, Widget? step) => [
    for (final a in leading) button(a),
    ?step,
    ?timer,
    for (final a in trailing) button(a),
  ];

  // De lado a lado y gris, como la app de siempre.
  Widget _original() {
    return Container(
      height: 78,
      color: color.withValues(alpha: alpha),
      child: LayoutBuilder(
        builder: (context, constraints) => FittedBox(
          // Si los botones no caben (pantalla estrecha, cantidad por toque y
          // reloj a la vez) la barra se encoge en vez de desbordarse; si
          // sobra sitio, se reparten a lo ancho.
          fit: BoxFit.scaleDown,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: _items(
                (a) => IconButton(
                  icon: Icon(a.icon, color: Colors.white, size: 28),
                  tooltip: a.tooltip,
                  visualDensity: VisualDensity.compact,
                  onPressed: a.onPressed,
                ),
                stepper?.call(Colors.white, false, false),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Borde nuevo: una pastilla que flota (cristal) o va entre las tarjetas.
  Widget _floating() {
    final cards = look.isCards;
    final background = cards
        ? const Color(0xFF141416).withValues(alpha: alpha)
        : color.withValues(alpha: alpha);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: cards ? 18 : 10),
      child: Container(
        height: cards ? 60 : 62,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(cards ? 30 : 22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000),
              offset: Offset(0, 10),
              blurRadius: 30,
            ),
          ],
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            children: _items(
              (a) => IconButton(
                icon: Icon(a.icon, color: Colors.white, size: 22),
                tooltip: a.tooltip,
                onPressed: a.onPressed,
              ),
              stepper == null
                  ? null
                  : Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.09),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: stepper!(Colors.white, true, false),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  // La carta de la barra del borde antiguo: una tierra doble de Unlimited.
  // Su marco es el de las tierras (recortado de Bayou, doble.jpg) y su
  // caja de texto se pinta con los colores de los jugadores. Si no se saben,
  // va la caja de la tierra de los paneles ([CardFrame.bar]).
  static const CardFrame _barFrame = CardFrame.bar;
  static const String _barStrip = 'assets/images/marcos/doble.jpg';

  // Grosor de su marco, en dp.
  static const double _frameWidth = 13;
  static const Animation<double> _opaque = AlwaysStoppedAnimation(1);

  // Una tira del marco: el borde derecho de la carta, con su filo exterior
  // (la línea clara) a la derecha. [turns] la gira de 90 en 90.
  Widget _frameStrip(
    Animation<double> opacity, {
    int turns = 0,
    bool flip = false,
  }) {
    Widget image = Image.asset(
      _barStrip,
      fit: BoxFit.cover,
      opacity: opacity,
      filterQuality: FilterQuality.medium,
    );
    if (flip) image = Transform.flip(flipX: true, child: image);
    return turns == 0 ? image : RotatedBox(quarterTurns: turns, child: image);
  }

  // Franja de arriba o de abajo: la tira tumbada, puesta las veces que haga
  // falta y una sí y otra no en espejo, para que no se note la unión.
  Widget _frameBand(Animation<double> opacity, {required int turns}) {
    // La tira mide 30 × 806: tumbada y a [_frameWidth] de alto, cada copia
    // ocupa esto de largo.
    const length = 806 * _frameWidth / 30;
    return LayoutBuilder(
      builder: (context, constraints) {
        final copies = (constraints.maxWidth / length).ceil().clamp(1, 20);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < copies; i++)
              Expanded(
                child: i.isOdd
                    ? Transform.flip(
                        flipX: true,
                        child: _frameStrip(opacity, turns: turns),
                      )
                    : _frameStrip(opacity, turns: turns),
              ),
          ],
        );
      },
    );
  }

  // Borde antiguo: una carta tumbada ([_barFrame]), de lado a lado como los
  // paneles. Borde negro, su marco (el mismo que llevan los paneles con ese
  // marco) y, dentro, su caja de texto hundida con los botones de maná.
  Widget _leather() {
    final opacity = AlwaysStoppedAnimation(alpha);
    const bevel = BoxDecoration(
      border: Border(
        top: BorderSide(color: Color(0xA6000000), width: 2),
        left: BorderSide(color: Color(0xA6000000), width: 2),
        right: BorderSide(color: Color(0x73FFF0D2), width: 2),
        bottom: BorderSide(color: Color(0x73FFF0D2), width: 2),
      ),
    );
    return Container(
      height: 76,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: alpha),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.75 * alpha),
            offset: const Offset(0, 8),
            blurRadius: 18,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // El marco: las dos tiras de los lados y, encima, las franjas de
            // arriba y abajo, con el filo claro siempre hacia fuera. Se pinta
            // opaco y se transparenta entero de una vez: transparentando cada
            // tira, en las esquinas se juntaban dos y salían de otro tono.
            Positioned.fill(
              child: Opacity(
                opacity: alpha,
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: _frameWidth,
                      child: _frameStrip(_opaque, flip: true),
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      width: _frameWidth,
                      child: _frameStrip(_opaque),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      height: _frameWidth,
                      child: _frameBand(_opaque, turns: 3),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: _frameWidth,
                      child: _frameBand(_opaque, turns: 1),
                    ),
                  ],
                ),
              ),
            ),
            // La caja de texto: la de una tierra doble de Revised con los
            // colores de los dos jugadores, o la de la tierra si no se saben.
            Padding(
              padding: const EdgeInsets.all(_frameWidth),
              child: DecoratedBox(
                position: DecorationPosition.foreground,
                decoration: bevel,
                child: switch (players) {
                  (final top, final bottom) => CustomPaint(
                    painter: _DualTextBox(CardFrame.dual(top, bottom), alpha),
                  ),
                  null => RotatedBox(
                    quarterTurns: 1,
                    child: Image.asset(
                      _barFrame.textBoxAsset,
                      fit: BoxFit.cover,
                      opacity: opacity,
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
                },
              ),
            ),
            // Los botones van dentro de la caja: si no caben (con la cantidad
            // por toque, por ejemplo) se encogen ahí, sin pisar el marco.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: _frameWidth + 2),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                // Abajo, lo que baja la sombra de los símbolos: así quedan
                // centrados en la caja, sin pisar el reborde de abajo.
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 2.5),
                  child: Row(
                    children: _items(
                      (a) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Tooltip(
                          message: a.tooltip,
                          child: Material(
                            type: MaterialType.transparency,
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: a.onPressed,
                              child: _ManaSymbol.forAction(a.icon),
                            ),
                          ),
                        ),
                      ),
                      stepper == null
                          ? null
                          : Container(
                              height: kManaPipSize,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 2,
                              ),
                              decoration: kManaPill,
                              child: stepper!(kManaInk, true, true),
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
}

/// Los botones de la barra del borde antiguo, como los símbolos de coste de
/// las cartas ([kManaPip]), con su icono en negro. Reiniciar lleva el de
/// volver a empezar.
class _ManaSymbol extends StatelessWidget {
  const _ManaSymbol(this.icon);

  factory _ManaSymbol.forAction(IconData icon) =>
      _ManaSymbol(icon == Icons.refresh ? Icons.restart_alt : icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: kManaPipSize,
      height: kManaPipSize,
      decoration: kManaPip,
      child: Icon(icon, color: kManaInk, size: 18),
    );
  }
}

/// La caja de texto de las tierras dobles de Alpha a Revised ([CardFrame.dual]):
/// un reborde de un filo oscuro y tres líneas finas (la de fuera, la del
/// medio y otra vez la de fuera) y, dentro, cuadrados uno dentro de otro, del
/// mismo grosor y de los dos colores uno sí y otro no, hasta que no cabe
/// ninguno más. Los botones van encima.
class _DualTextBox extends CustomPainter {
  _DualTextBox(this.dual, this.alpha);

  final ({CardFrame line, CardFrame middle, CardFrame band, CardFrame other})
  dual;
  final double alpha;

  // El grosor de cada cuadrado, de cada línea del reborde y de su filo.
  static const double _band = 5;
  static const double _line = 1.3;
  static const double _edge = 0.8;

  @override
  void paint(Canvas canvas, Size size) {
    // Va casi opaca aunque la barra se transparente: si no, se perdía.
    final strength = 0.4 + 0.6 * alpha;
    final paint = Paint();
    var rect = Offset.zero & size;
    void layer(Color color, double width) {
      canvas.drawRect(rect, paint..color = color.withValues(alpha: strength));
      rect = rect.deflate(width);
    }

    final edge = shade(dual.line.dualRim, 0.45);
    layer(edge, _edge);
    layer(dual.line.dualRim, _line);
    layer(dual.middle.dualRim, _line);
    layer(dual.line.dualRim, _line);
    layer(edge, _edge);
    // El último cuadrado es el que ya no deja sitio a otro entero: una tira
    // más fina que dos bandas no se pinta, se queda el de fuera.
    for (var i = 0; rect.shortestSide >= 2 * _band || i == 0; i++) {
      layer((i.isEven ? dual.band : dual.other).dualTint, _band);
    }
  }

  @override
  bool shouldRepaint(_DualTextBox old) =>
      old.dual != dual || old.alpha != alpha;
}
