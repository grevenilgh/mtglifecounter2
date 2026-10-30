import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Los tres temas de la app. Se diseñaron sobre el prototipo
/// https://claude.ai/artifact/QrwGhQdK3j9fqTt5Ed5pdU.
enum AppTheme {
  /// La app tal como era: paneles de color sobre la imagen y barra gris.
  original('De siempre'),

  /// Borde nuevo: imagen grande, número blanco y barra flotante.
  modern('Borde nuevo'),

  /// Borde antiguo («Jaspe fino»): marco jaspeado de carta de 1993/94.
  classic('Borde antiguo');

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

/// Cómo se pinta el color del jugador encima de la imagen.
enum TintMode {
  /// Una capa uniforme del color.
  veil,

  /// La imagen limpia; el color solo en el borde del panel.
  edge,
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
      numberFont: variant == ModernVariant.glass ? 'Barlow Condensed' : 'Outfit',
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
  bool get isCards => theme == AppTheme.modern && variant == ModernVariant.cards;
  bool get isGlass => theme == AppTheme.modern && variant == ModernVariant.glass;

  /// Hueco entre los dos paneles: la barra va en él sin tapar nada.
  /// Con 0 la barra flota encima de los paneles.
  double get barGap => switch (theme) {
    AppTheme.original => 78,
    AppTheme.modern => isCards ? 74 : 0,
    AppTheme.classic => 66,
  };

  /// Color claro del texto del número.
  Color get numberColor =>
      isClassic ? const Color(0xFFF6EDD5) : Colors.white;

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

/// En los tests no hay red: ahí se usa la fuente del sistema.
bool useGoogleFonts = true;

/// Aplica una fuente de Google Fonts a [style], o lo deja igual si no hay.
TextStyle withFont(String? font, TextStyle style) {
  if (font == null || !useGoogleFonts) return style;
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
