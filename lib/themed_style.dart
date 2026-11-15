import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:mtglifecounter/look.dart';
import 'package:mtglifecounter/skin.dart';

/// Rojo de lo que no tiene vuelta atrás (el mismo del reloj al acabar).
const Color kDangerRed = Color(0xFFDC2626);

/// De qué tipo es un botón de [ThemedStyle.button].
enum ButtonKind {
  /// El normal: cancelar, reiniciar el reloj...
  plain,

  /// El principal: iniciar, restablecer...
  accent,

  /// El principal cuando no tiene vuelta atrás: va en rojo.
  danger,
}

/// Cómo se visten los avisos y las hojas en cada tema: el marco, las letras,
/// los botones, el selector y los botones redondos. Lo usan los diálogos de
/// confirmación ([showThemedConfirm]) y la hoja del reloj.
///
/// - Original: el gris de la barra, como la app de siempre.
/// - Cristal: un panel translúcido que desenfoca lo de detrás (solo mientras
///   está abierto) y la letra estrecha del tema.
/// - Tarjetas: una tarjeta oscura con una franja de los colores de los dos
///   jugadores.
/// - Old Border: una carta antigua ([OldCard]) con el marco de las tierras y
///   la caja de texto de pergamino, Vollkorn en tinta y botones de maná.
class ThemedStyle {
  ThemedStyle._({
    required this.look,
    required this.frame,
    required this.ink,
    required this.muted,
    required this.warnInk,
    required this.dangerInk,
    required this.font,
    required this.titleSize,
    required Color accentFill,
    required Color accentInk,
    required Color plainFill,
    required Color plainInk,
    required this.plainBorder,
    required this.radius,
    required this.buttonShadow,
    required this.dangerFill,
    required this.badgeFill,
    required this.badgeInk,
    required this.badgeDangerFill,
    required this.badgeDangerInk,
    required this.badgeShape,
  }) : _accentFill = accentFill,
       _accentInk = accentInk,
       _plainFill = plainFill,
       _plainInk = plainInk;

  factory ThemedStyle.of(Look look, Skin skin) {
    if (look.isClassic) return ThemedStyle._oldBorder(look);
    if (look.isGlass) return ThemedStyle._glass(look, skin);
    if (look.isCards) return ThemedStyle._cards(look, skin);
    return ThemedStyle._original(look, skin);
  }

  final Look look;

  /// El fondo con su marco, alrededor de lo que se le pase.
  final Widget Function(Widget content) frame;

  /// Color del texto, del texto secundario y de los números en aviso (ámbar)
  /// y acabados (rojo), legibles sobre el fondo del tema.
  final Color ink;
  final Color muted;
  final Color warnInk;
  final Color dangerInk;

  /// Letra de los títulos y los números (null, la del sistema).
  final String? font;
  final double titleSize;

  final Color _accentFill;

  /// El color de lo principal (el botón de iniciar, la opción elegida): para
  /// resaltar lo que está activo, como el jugador al que le toca.
  Color get accent => _accentFill;
  final Color _accentInk;
  final Color _plainFill;
  final Color _plainInk;
  final Color? plainBorder;
  final double radius;
  final List<BoxShadow>? buttonShadow;
  final Color dangerFill;
  final Color badgeFill;
  final Color badgeInk;
  final Color badgeDangerFill;
  final Color badgeDangerInk;
  final BoxDecoration Function(Color fill) badgeShape;

  TextStyle get titleStyle => withFont(
    font,
    TextStyle(
      color: ink,
      fontSize: titleSize,
      fontWeight: FontWeight.w700,
      height: 1.1,
    ),
  );

  TextStyle get bodyStyle => look.isClassic
      ? withFont(font, TextStyle(color: ink, fontSize: 15.5, height: 1.35))
      : TextStyle(color: muted, fontSize: 15, height: 1.35);

  /// Los números grandes (el tiempo del reloj).
  TextStyle numberStyle(double size, Color color) => withFont(
    font,
    TextStyle(
      color: color,
      fontSize: size,
      fontWeight: FontWeight.w700,
      height: 1.1,
      fontFeatures: kNumberFeatures,
    ),
  );

  /// El icono de arriba de un aviso.
  Widget badge(IconData icon, {bool danger = false}) => Container(
    width: 56,
    height: 56,
    decoration: badgeShape(danger ? badgeDangerFill : badgeFill),
    child: Icon(icon, color: danger ? badgeDangerInk : badgeInk, size: 30),
  );

  /// Un botón con forma de pastilla. Sin [onTap], apagado.
  Widget button(
    String label, {
    required ButtonKind kind,
    required VoidCallback? onTap,
  }) {
    final (fill, labelInk, border) = switch (kind) {
      ButtonKind.plain => (_plainFill, _plainInk, plainBorder),
      ButtonKind.accent => (_accentFill, _accentInk, null),
      ButtonKind.danger => (
        dangerFill,
        look.isClassic ? kManaInk : Colors.white,
        null,
      ),
    };
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: _Pill(
        fill: fill,
        border: look.isClassic ? const Color(0x66000000) : border,
        radius: radius,
        shadow: enabled ? buttonShadow : null,
        onTap: onTap,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: withFont(
            font,
            TextStyle(
              color: labelInk,
              fontSize: look.isGlass ? 18 : 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  /// Un selector de opciones (como el de cuenta atrás o cronómetro): la
  /// elegida, como el botón principal. Sin icono (null), solo el texto.
  Widget selector<T>({
    required List<(T, IconData?, String)> options,
    required T selected,
    required ValueChanged<T> onSelected,
  }) {
    return Row(
      children: [
        for (final (i, (value, icon, label)) in options.indexed) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: Semantics(
              selected: value == selected,
              button: true,
              child: _Pill(
                fill: value == selected ? _accentFill : _plainFill,
                border: look.isClassic
                    ? const Color(0x66000000)
                    : (value == selected ? null : plainBorder),
                radius: radius,
                shadow: value == selected ? buttonShadow : null,
                onTap: () => onSelected(value),
                sidePadding: options.length > 2 ? 6 : 14,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(
                          icon,
                          size: 18,
                          color: value == selected ? _accentInk : _plainInk,
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        label,
                        // Con tres opciones, todas un poco más pequeñas
                        // y del mismo tamaño (si no, el FittedBox encoge
                        // más las largas).
                        style: withFont(
                          font,
                          TextStyle(
                            color: value == selected ? _accentInk : _plainInk,
                            fontSize:
                                (look.isGlass ? 17 : 15) -
                                (options.length > 2 ? 2 : 0),
                            fontWeight: FontWeight.w700,
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
      ],
    );
  }

  /// Un botón redondo con un icono (los − y + de la duración). En el Old
  /// Border, un símbolo de maná.
  Widget roundButton(IconData icon, {required VoidCallback? onTap}) {
    final enabled = onTap != null;
    final decoration = look.isClassic
        ? kManaPip
        : BoxDecoration(
            shape: BoxShape.circle,
            color: _plainFill,
            border: Border.all(
              color: plainBorder ?? Colors.white.withValues(alpha: 0.18),
            ),
          );
    return Opacity(
      opacity: enabled ? 1 : 0.35,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Container(
            width: 46,
            height: 46,
            decoration: decoration,
            child: Icon(
              icon,
              color: look.isClassic ? kManaInk : _plainInk,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }

  static BoxDecoration _circle(Color fill) =>
      BoxDecoration(color: fill, shape: BoxShape.circle);

  // Original: el gris de la barra, como la app de siempre.
  factory ThemedStyle._original(Look look, Skin skin) {
    final background = Color.alphaBlend(
      Colors.black.withValues(alpha: 0.35),
      skin.bar,
    );
    return ThemedStyle._(
      look: look,
      frame: (content) => Container(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          boxShadow: const [
            BoxShadow(color: Color(0x99000000), blurRadius: 28),
          ],
        ),
        child: content,
      ),
      ink: Colors.white,
      muted: const Color(0xCCFFFFFF),
      warnInk: const Color(0xFFFBBF24),
      dangerInk: const Color(0xFFF87171),
      font: null,
      titleSize: 21,
      accentFill: Colors.white,
      accentInk: const Color(0xFF141414),
      plainFill: Colors.transparent,
      plainInk: Colors.white,
      plainBorder: Colors.white.withValues(alpha: 0.35),
      radius: 12,
      buttonShadow: null,
      dangerFill: kDangerRed,
      badgeFill: Colors.white.withValues(alpha: 0.1),
      badgeInk: Colors.white,
      badgeDangerFill: kDangerRed.withValues(alpha: 0.18),
      badgeDangerInk: const Color(0xFFF87171),
      badgeShape: _circle,
    );
  }

  // Cristal: un panel translúcido que deja ver la partida desenfocada.
  factory ThemedStyle._glass(Look look, Skin skin) {
    const radius = 26.0;
    return ThemedStyle._(
      look: look,
      frame: (content) => ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.alphaBlend(
                    Colors.white.withValues(alpha: 0.16),
                    skin.bar.withValues(alpha: 0.6),
                  ),
                  skin.bar.withValues(alpha: 0.45),
                ],
              ),
            ),
            child: content,
          ),
        ),
      ),
      ink: Colors.white,
      muted: const Color(0xE6FFFFFF),
      warnInk: const Color(0xFFFCD34D),
      dangerInk: const Color(0xFFFCA5A5),
      font: look.numberFont,
      titleSize: 28,
      accentFill: Colors.white.withValues(alpha: 0.92),
      accentInk: const Color(0xFF111111),
      plainFill: Colors.white.withValues(alpha: 0.1),
      plainInk: Colors.white,
      plainBorder: Colors.white.withValues(alpha: 0.4),
      radius: 24,
      buttonShadow: null,
      dangerFill: kDangerRed.withValues(alpha: 0.9),
      badgeFill: Colors.white.withValues(alpha: 0.14),
      badgeInk: Colors.white,
      badgeDangerFill: Colors.white.withValues(alpha: 0.14),
      badgeDangerInk: const Color(0xFFFCA5A5),
      badgeShape: (fill) => BoxDecoration(
        shape: BoxShape.circle,
        color: fill,
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
      ),
    );
  }

  // Tarjetas: una tarjeta oscura como los paneles, con una franja de los
  // colores de los dos jugadores arriba.
  factory ThemedStyle._cards(Look look, Skin skin) {
    const radius = 22.0;
    return ThemedStyle._(
      look: look,
      frame: (content) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF141416),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x99000000),
              offset: Offset(0, 14),
              blurRadius: 34,
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 6,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: ColoredBox(color: shade(skin.top, 1.3))),
                  Expanded(child: ColoredBox(color: shade(skin.bottom, 1.3))),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
              child: content,
            ),
          ],
        ),
      ),
      ink: Colors.white,
      muted: const Color(0xFFA1A1AA),
      warnInk: const Color(0xFFFBBF24),
      dangerInk: const Color(0xFFF87171),
      font: look.numberFont,
      titleSize: 22,
      accentFill: shade(skin.top, 1.1),
      accentInk: Colors.white,
      plainFill: const Color(0xFF26262A),
      plainInk: Colors.white,
      plainBorder: null,
      radius: 16,
      buttonShadow: null,
      dangerFill: kDangerRed,
      badgeFill: shade(skin.top, 1.0),
      badgeInk: Colors.white,
      badgeDangerFill: kDangerRed,
      badgeDangerInk: Colors.white,
      badgeShape: (fill) => BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [shade(fill, 1.25), shade(fill, 0.75)],
        ),
      ),
    );
  }

  // Old Border: una carta antigua, Vollkorn en tinta y botones de maná: el
  // gris del maná genérico, el verde del maná verde para lo principal y el
  // rojo del maná rojo para lo que no tiene vuelta.
  factory ThemedStyle._oldBorder(Look look) {
    const manaRed = Color(0xFFF2A07E);
    const manaGreen = Color(0xFFA7C79A);
    const shadow = [
      BoxShadow(color: Color(0xFF0B0705), offset: Offset(-1.5, 2.5)),
    ];
    return ThemedStyle._(
      look: look,
      frame: (content) => OldCard(child: content),
      ink: kInk,
      muted: const Color(0xFF5E4A33),
      warnInk: const Color(0xFF8A4B00),
      dangerInk: const Color(0xFF9B1C1C),
      font: 'Vollkorn',
      titleSize: 23,
      accentFill: manaGreen,
      accentInk: kManaInk,
      plainFill: kManaGray,
      plainInk: kManaInk,
      plainBorder: null,
      radius: 24,
      buttonShadow: shadow,
      dangerFill: manaRed,
      badgeFill: kManaGray,
      badgeInk: kManaInk,
      badgeDangerFill: manaRed,
      badgeDangerInk: kManaInk,
      badgeShape: (fill) => kManaPip.copyWith(color: fill),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.fill,
    required this.border,
    required this.radius,
    required this.shadow,
    required this.onTap,
    required this.child,
    this.sidePadding = 14,
  });

  final Color fill;
  final Color? border;
  final double radius;
  final List<BoxShadow>? shadow;
  final VoidCallback? onTap;
  final Widget child;

  /// El relleno de los lados: menos en el selector, donde van tres juntas.
  final double sidePadding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: shadow,
      ),
      child: Material(
        color: fill,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: border == null ? BorderSide.none : BorderSide(color: border!),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: sidePadding,
                  vertical: 10,
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// La carta del Old Border para avisos y hojas: borde negro, el marco de las
/// tierras (las tiras de `doble.jpg`, con el filo claro hacia fuera y las
/// esquinas en inglete, ver [MitreClipper]) y la caja de texto de la tierra,
/// hundida.
class OldCard extends StatelessWidget {
  const OldCard({super.key, required this.child});

  final Widget child;

  static const String _strip = 'assets/images/marcos/doble.jpg';
  static const String _textBox = 'assets/images/marcos/caja_tierra.jpg';
  static const double _frame = 14;

  Widget _side({bool flip = false, int turns = 0}) {
    Widget image = Image.asset(
      _strip,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
    );
    if (flip) image = Transform.flip(flipX: true, child: image);
    return turns == 0 ? image : RotatedBox(quarterTurns: turns, child: image);
  }

  // Arriba y abajo, la tira tumbada, repetida y en espejo una sí y otra no.
  Widget _band({required int turns}) {
    const length = 806 * _frame / 30;
    return LayoutBuilder(
      builder: (context, constraints) {
        final copies = (constraints.maxWidth / length).ceil().clamp(1, 20);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < copies; i++)
              Expanded(
                child: i.isOdd
                    ? Transform.flip(flipX: true, child: _side(turns: turns))
                    : _side(turns: turns),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0xCC000000),
            offset: Offset(0, 12),
            blurRadius: 30,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          children: [
            Positioned.fill(
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: _frame,
                    child: _side(flip: true),
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    width: _frame,
                    child: _side(),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    height: _frame,
                    child: ClipPath(
                      clipper: const MitreClipper(
                        left: _frame,
                        right: _frame,
                        top: true,
                      ),
                      child: _band(turns: 3),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: _frame,
                    child: ClipPath(
                      clipper: const MitreClipper(
                        left: _frame,
                        right: _frame,
                        top: false,
                      ),
                      child: _band(turns: 1),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(_frame),
              child: DecoratedBox(
                position: DecorationPosition.foreground,
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Color(0xA6000000), width: 2),
                    left: BorderSide(color: Color(0xA6000000), width: 2),
                    right: BorderSide(color: Color(0x73FFF0D2), width: 2),
                    bottom: BorderSide(color: Color(0x73FFF0D2), width: 2),
                  ),
                ),
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage(_textBox),
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
                    child: child,
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
