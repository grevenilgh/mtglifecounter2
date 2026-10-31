import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Los tres temas de la app. Se diseñaron sobre el prototipo
/// https://claude.ai/artifact/QrwGhQdK3j9fqTt5Ed5pdU.
enum AppTheme {
  /// La app tal como era: paneles de color sobre la imagen y barra gris.
  original('De siempre'),

  /// Borde nuevo: imagen grande, número blanco y barra flotante.
  modern('Borde nuevo'),

  /// Borde antiguo: cada panel es una carta de 1993/94 tumbada, con el marco
  /// de una carta de verdad.
  classic('Old Border');

  const AppTheme(this.label);

  final String label;

  static AppTheme fromName(String? name) =>
      values.firstWhere((t) => t.name == name, orElse: () => original);
}

/// Variantes del borde nuevo.
enum ModernVariant {
  /// Paneles de lado a lado con la barra flotando encima.
  glass('Cristal'),

  /// Dos tarjetas redondeadas que brillan con su color; la barra va entre ellas.
  cards('Tarjetas');

  const ModernVariant(this.label);

  final String label;

  static ModernVariant fromName(String? name) =>
      values.firstWhere((v) => v.name == name, orElse: () => glass);
}

/// Cómo se reparte la imagen de fondo.
enum BackgroundMode {
  /// Una sola imagen para toda la pantalla; cada panel enseña su trozo.
  screen('Una para toda la pantalla'),

  /// Cada panel enseña la imagen entera, derecha para su jugador.
  perPlayer('Una para cada jugador');

  const BackgroundMode(this.label);

  final String label;

  static BackgroundMode fromName(String? name) =>
      values.firstWhere((m) => m.name == name, orElse: () => screen);
}

/// Cómo se distingue la mitad del panel que suma de la que resta.
enum ZoneMarks {
  /// La de arriba algo más clara y la de abajo algo más oscura.
  soft('Tono suave'),

  /// Lo mismo, bastante más marcado.
  strong('Tono marcado'),

  /// La de arriba teñida de verde y la de abajo de rojo.
  color('Verde y rojo'),

  /// Una línea discontinua en medio.
  line('Línea'),

  /// Tono suave y línea.
  both('Tono y línea'),

  /// Nada: el panel entero igual. Arriba sigue sumando y abajo restando.
  none('Nada');

  const ZoneMarks(this.label);

  final String label;

  bool get hasLine => this == line || this == both;

  static ZoneMarks fromName(String? name) =>
      values.firstWhere((m) => m.name == name, orElse: () => both);
}

/// Cómo se pinta el color del jugador encima de la imagen.
enum TintMode {
  /// Una capa uniforme del color.
  veil,

  /// La imagen limpia; el color solo en el borde del panel.
  edge,
}

/// Marco de carta de Alpha del borde antiguo. No es un color liso sino una
/// textura (`assets/images/marcos/`), pintada a 1 dp por unidad.
enum CardFrame {
  azul,
  blanco,
  negro,
  rojo,
  verde,
  artefacto,
  tierra,

  /// Multicolor: el dorado de las cartas de varios colores de Legends.
  oro;

  String get asset => 'assets/images/marcos/$name.jpg';

  /// Tira horizontal para las franjas de arriba y abajo, si la textura tiene
  /// dirección. El verde de Alpha y el oro de Legends van en bandas
  /// horizontales: girar la tira del lado las convertía en rayas verticales
  /// que parecían cortes.
  String? get horizontalAsset => switch (this) {
    verde || oro => 'assets/images/marcos/${name}_h.jpg',
    _ => null,
  };

  /// Ancho entre alto de [horizontalAsset].
  double get horizontalAspect => this == oro ? 290 / 35 : 450 / 33;

  /// Si su caja de texto es oscura (el rojo y la madera del verde): ahí el
  /// historial va en tinta clara y la caja se oscurece un poco para que se
  /// lea.
  bool get darkTextBox => this == rojo || this == verde;

  /// La caja de texto de una carta de ese color, de pie: es el fondo del
  /// historial.
  String get textBoxAsset => 'assets/images/marcos/caja_$name.jpg';

  /// Los marcos que mejor van con [color], del mejor al peor.
  static List<CardFrame> rankFor(Color color) {
    final hsv = HSVColor.fromColor(color);
    final h = hsv.hue, s = hsv.saturation, v = hsv.value;
    // Poco color: blanco si es claro, negro si es casi negro y, si no,
    // artefacto (la berenjena de Full Tapped, por ejemplo).
    if (s < 0.35 || v < 0.3) {
      if (v > 0.75) return const [blanco, tierra, artefacto];
      if (v < 0.15) return const [negro, tierra, artefacto];
      return const [artefacto, tierra, negro];
    }
    if (h < 20 || h >= 330) return const [rojo, artefacto, negro];
    // Naranjas y marrones: artefacto. Amarillos y dorados: multicolor.
    if (h < 40) return const [artefacto, rojo, oro];
    if (h < 70) return const [oro, artefacto, blanco];
    if (h < 170) return const [verde, azul, tierra];
    if (h < 250) return const [azul, verde, negro];
    // Morados y lilas: en Magic el negro tira a morado.
    return const [negro, azul, tierra];
  }

  /// Un marco para cada jugador, nunca el mismo: si coinciden, el de abajo
  /// se queda con su siguiente opción.
  static (CardFrame, CardFrame) forPlayers(Color top, Color bottom) {
    final first = rankFor(top).first;
    final second = rankFor(bottom).firstWhere((f) => f != first);
    return (first, second);
  }
}

/// Lo que cambia de un tema a otro, ya resuelto para pintar.
class Look {
  const Look._({
    required this.theme,
    required this.variant,
    required this.numberFont,
    required this.numberScale,
    required this.veil,
    required this.tintMode,
    required this.focusByDefault,
  });

  factory Look.of(AppTheme theme, ModernVariant variant) => switch (theme) {
    AppTheme.original => Look._(
      theme: theme,
      variant: variant,
      numberFont: null,
      numberScale: 1,
      veil: 0.82,
      tintMode: TintMode.veil,
      focusByDefault: false,
    ),
    AppTheme.modern => Look._(
      theme: theme,
      variant: variant,
      numberFont: variant == ModernVariant.glass
          ? 'Barlow Condensed'
          : 'Outfit',
      numberScale: variant == ModernVariant.glass ? 1.15 : 1,
      veil: 0.2,
      tintMode: variant == ModernVariant.cards ? TintMode.edge : TintMode.veil,
      focusByDefault: variant == ModernVariant.cards,
    ),
    AppTheme.classic => Look._(
      theme: theme,
      variant: variant,
      numberFont: 'Vollkorn',
      numberScale: 1,
      veil: 0.2,
      tintMode: TintMode.veil,
      focusByDefault: true,
    ),
  };

  final AppTheme theme;
  final ModernVariant variant;

  /// Fuente de Google Fonts para el número; `null` es la del sistema.
  final String? numberFont;

  /// Las fuentes estrechas caben más grandes en el mismo hueco.
  final double numberScale;

  /// Cuánto color del jugador va encima de la imagen con [TintMode.veil].
  final double veil;
  final TintMode tintMode;

  /// Si «Foco en el número» empieza activado con este tema.
  final bool focusByDefault;

  bool get isClassic => theme == AppTheme.classic;
  bool get isCards =>
      theme == AppTheme.modern && variant == ModernVariant.cards;
  bool get isGlass =>
      theme == AppTheme.modern && variant == ModernVariant.glass;

  /// Hueco entre los dos paneles: la barra va en él sin tapar nada.
  /// Con 0 la barra flota encima de los paneles.
  double get barGap => switch (theme) {
    AppTheme.original => 78,
    AppTheme.modern => isCards ? 74 : 0,
    AppTheme.classic => 66,
  };

  /// Opacidad de la barra central si no se cambia en Ajustes.
  int get defaultBarOpacity => switch (theme) {
    AppTheme.original => 97,
    AppTheme.modern => isCards ? 92 : 94,
    AppTheme.classic => 92,
  };

  /// Opacidad del fondo del historial si no se cambia en Ajustes.
  int get defaultHistoryOpacity => switch (theme) {
    AppTheme.original => 50,
    AppTheme.modern => 30,
    AppTheme.classic => 80,
  };

  /// Color claro del texto del número.
  Color get numberColor => isClassic ? const Color(0xFFF6EDD5) : Colors.white;

  /// Estilo del número de vidas con la fuente del tema.
  TextStyle numberStyle(double fontSize) {
    final base = TextStyle(
      fontSize: fontSize,
      fontWeight: isClassic ? FontWeight.w900 : FontWeight.w700,
      color: numberColor,
      height: 1,
      fontFeatures: kNumberFeatures,
    );
    return withFont(numberFont, base);
  }
}

/// Números de altura fija y mismo ancho: Vollkorn los trae de estilo antiguo
/// (el 1 parece una I) si no se piden así.
const List<FontFeature> kNumberFeatures = [
  FontFeature.liningFigures(),
  FontFeature.tabularFigures(),
];

/// En los tests no hay red: ahí la fuente se pide solo por su nombre y se usa
/// la que el test haya cargado con ese nombre (o la de por defecto).
bool useGoogleFonts = true;

/// Aplica una fuente de Google Fonts a [style], o lo deja igual si no hay.
TextStyle withFont(String? font, TextStyle style) {
  if (font == null) return style;
  if (!useGoogleFonts) return style.copyWith(fontFamily: font);
  return GoogleFonts.getFont(font, textStyle: style);
}

/// Aclara (f > 1) u oscurece (f < 1) un color, como en el prototipo.
Color shade(Color c, double f) {
  int ch(double v) => (v * 255 * f).round().clamp(0, 255);
  return Color.fromARGB(255, ch(c.r), ch(c.g), ch(c.b));
}

/// El marco jaspeado de las cartas antiguas: el color con manchas de luz y
/// sombra. Son varias capas porque una caja solo admite un degradado.
List<Decoration> mottled(Color color, double alpha) => [
  BoxDecoration(
    gradient: LinearGradient(
      begin: const Alignment(-0.6, -1),
      end: const Alignment(0.6, 1),
      colors: [
        shade(color, 1.12).withValues(alpha: alpha),
        shade(color, 0.68).withValues(alpha: alpha),
      ],
    ),
  ),
  const BoxDecoration(
    gradient: RadialGradient(
      center: Alignment(-0.64, -0.56),
      radius: 0.8,
      colors: [Color(0x38FFFFFF), Color(0x00FFFFFF)],
    ),
  ),
  const BoxDecoration(
    gradient: RadialGradient(
      center: Alignment(0.64, 0.4),
      radius: 0.9,
      colors: [Color(0x61000000), Color(0x00000000)],
    ),
  ),
  const BoxDecoration(
    gradient: RadialGradient(
      center: Alignment(0.16, -0.84),
      radius: 0.6,
      colors: [Color(0x38000000), Color(0x00000000)],
    ),
  ),
  const BoxDecoration(
    gradient: RadialGradient(
      center: Alignment(-0.44, 0.84),
      radius: 0.7,
      colors: [Color(0x24FFFFFF), Color(0x00FFFFFF)],
    ),
  ),
];

/// Pinta [mottled] detrás de [child].
class Mottled extends StatelessWidget {
  const Mottled({
    super.key,
    required this.color,
    this.alpha = 1,
    this.borderRadius = BorderRadius.zero,
    required this.child,
  });

  final Color color;
  final double alpha;
  final BorderRadius borderRadius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    Widget result = child;
    for (final layer in mottled(color, alpha).reversed) {
      result = DecoratedBox(decoration: layer, child: result);
    }
    return ClipRRect(borderRadius: borderRadius, child: result);
  }
}

/// Pergamino de las cajas de texto y los botones del borde antiguo.
const Color kParchmentLight = Color(0xFFFBF4DE);
const Color kParchment = Color(0xFFDCC89C);
const Color kParchmentDark = Color(0xFFA88D5C);
const Color kInk = Color(0xFF2A1D10);

/// Botón redondo de pergamino, como un símbolo de maná.
const BoxDecoration kParchmentPip = BoxDecoration(
  shape: BoxShape.circle,
  gradient: RadialGradient(
    center: Alignment(-0.3, -0.4),
    colors: [kParchmentLight, kParchment, kParchmentDark],
    stops: [0, 0.65, 1],
  ),
  boxShadow: [
    BoxShadow(color: Color(0xFF0B0705), spreadRadius: 2),
    BoxShadow(color: Color(0x99000000), offset: Offset(0, 3), blurRadius: 8),
  ],
);
