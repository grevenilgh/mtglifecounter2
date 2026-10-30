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
  });

  final Look look;

  /// Color de la barra de la skin (en el borde antiguo, el cuero, salvo en la
  /// personalizada).
  final Color color;

  /// Opacidad de marcos y barra, de 0 a 1.
  final double alpha;
  final List<BarAction> leading;
  final List<BarAction> trailing;

  /// La cantidad por toque (− 1 +), si está activada en Ajustes. Recibe el
  /// color del texto y si debe ser la versión pequeña.
  final Widget Function(Color color, bool compact)? stepper;

  @override
  Widget build(BuildContext context) {
    return switch (look.theme) {
      AppTheme.original => _original(),
      AppTheme.modern => _floating(),
      AppTheme.classic => _leather(),
    };
  }

  List<Widget> _items(Widget Function(BarAction) button, Widget? step) => [
    for (final a in leading) button(a),
    ?step,
    for (final a in trailing) button(a),
  ];

  // De lado a lado y gris, como la app de siempre.
  Widget _original() {
    return Container(
      height: 78,
      color: color.withValues(alpha: alpha < 0.97 ? 0.97 : alpha),
      child: LayoutBuilder(
        builder: (context, constraints) => FittedBox(
          // Si la pantalla es muy estrecha la barra se encoge en vez de
          // desbordarse.
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: constraints.maxWidth < 340 ? 340 : constraints.maxWidth,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: _items(
                (a) => IconButton(
                  icon: Icon(a.icon, color: Colors.white, size: 28),
                  tooltip: a.tooltip,
                  visualDensity: VisualDensity.compact,
                  onPressed: a.onPressed,
                ),
                stepper?.call(Colors.white, false),
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
        : color.withValues(alpha: alpha < 0.94 ? 0.94 : alpha);
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
            BoxShadow(color: Color(0x66000000), offset: Offset(0, 10), blurRadius: 30),
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
                      child: stepper!(Colors.white, true),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  // Borde antiguo: tira de cuero jaspeado con botones de pergamino.
  Widget _leather() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Container(
        height: 58,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [
            BoxShadow(color: Color(0xFF0B0705), spreadRadius: 3),
            BoxShadow(color: Color(0xBF000000), offset: Offset(0, 10), blurRadius: 24),
          ],
        ),
        child: Mottled(
          color: color,
          alpha: alpha,
          borderRadius: BorderRadius.circular(10),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
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
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: kParchmentPip,
                            child: Icon(a.icon, color: kInk, size: 20),
                          ),
                        ),
                      ),
                    ),
                  ),
                  stepper == null
                      ? null
                      : Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(19),
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0xFFF2E8CF), Color(0xFFDFCDA3)],
                            ),
                            boxShadow: const [
                              BoxShadow(color: Color(0xFF0B0705), offset: Offset(0, 2)),
                            ],
                          ),
                          child: stepper!(kInk, true),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
