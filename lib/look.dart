import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Los tres temas de la app. Se diseñaron sobre el prototipo
/// https://claude.ai/artifact/QrwGhQdK3j9fqTt5Ed5pdU.
enum AppTheme {
  /// La app tal como era: paneles de color sobre la imagen y barra gris.
  original('Original'),

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

  /// Nada: el panel entero igual. Arriba sigue sumando y abajo restando. Es
  /// lo de por defecto.
  none('Nada');

  const ZoneMarks(this.label);

  final String label;

  bool get hasLine => this == line || this == both;

  static ZoneMarks fromName(String? name) =>
      values.firstWhere((m) => m.name == name, orElse: () => none);
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

  /// El tono pálido de ese color en la caja de texto de las tierras dobles de
  /// Unlimited (anillos de los dos colores alternados). El oro y el artefacto
  /// no salen en ninguna doble: van en dorado y en marrón claro.
  Color get dualTint => switch (this) {
    // Medidos en las dobles de Unlimited de Scryfall. El verde sale verde
    // amarillento; aquí, un poco más verde.
    azul => const Color(0xFFADB7BB),
    blanco => const Color(0xFFE3CFA6),
    negro => const Color(0xFF909290),
    rojo => const Color(0xFFD98E7A),
    verde => const Color(0xFFADBF6E),
    // Sin doble de verdad: marrón grisáceo, que no se confunda con el rojo
    // ni con el oro (el marrón claro de antes casi no se distinguía).
    artefacto => const Color(0xFFB3A79A),
    tierra => const Color(0xFFB8AC98),
    oro => const Color(0xFFD9BC5E),
  };

  /// El mismo color, fuerte y oscuro: el de la línea del reborde de la caja
  /// de texto de las dobles (una de cada color, la de fuera y la de dentro).
  Color get dualRim => switch (this) {
    azul => const Color(0xFF2F7FB0),
    blanco => const Color(0xFFD3D9D4),
    negro => const Color(0xFF4E5560),
    rojo => const Color(0xFFA63340),
    verde => const Color(0xFF8FA24A),
    artefacto => const Color(0xFF6B5D50),
    tierra => const Color(0xFF6E6252),
    oro => const Color(0xFF94701E),
  };

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

  /// Cómo es la caja de texto de la tierra doble de [top] y [bottom], medido
  /// en las diez de Revised: el reborde son tres líneas finas (de fuera,
  /// del medio y otra vez la de fuera) y los cuadrados empiezan por [band].
  /// Ninguna regla saca las diez (el rojo siempre va fuera, pero el resto
  /// cambia de carta a carta), así que van en una tabla. Las parejas que no
  /// existen (con oro, artefacto o el mismo color) llevan fuera el de arriba.
  static ({CardFrame line, CardFrame middle, CardFrame band, CardFrame other})
  dual(CardFrame top, CardFrame bottom) {
    ({CardFrame line, CardFrame middle, CardFrame band, CardFrame other}) of(
      CardFrame line,
      CardFrame middle,
      CardFrame band,
    ) => (
      line: line,
      middle: middle,
      band: band,
      other: band == line ? middle : line,
    );
    final pair = {top, bottom};
    bool pairOf(CardFrame a, CardFrame b) =>
        pair.length == 2 && pair.contains(a) && pair.contains(b);
    if (pairOf(blanco, azul)) return of(blanco, azul, blanco); // Tundra
    if (pairOf(azul, negro)) return of(azul, negro, negro); // Underground Sea
    if (pairOf(negro, rojo)) return of(rojo, negro, rojo); // Badlands
    if (pairOf(rojo, verde)) return of(rojo, verde, rojo); // Taiga
    if (pairOf(verde, blanco)) return of(verde, blanco, blanco); // Savannah
    if (pairOf(blanco, negro)) return of(negro, blanco, negro); // Scrubland
    if (pairOf(azul, rojo)) return of(rojo, azul, rojo); // Volcanic Island
    if (pairOf(negro, verde)) return of(verde, negro, negro); // Bayou
    if (pairOf(rojo, blanco)) return of(rojo, blanco, rojo); // Plateau
    if (pairOf(verde, azul)) return of(verde, azul, azul); // Tropical Island
    return of(top, bottom, top);
  }

  /// El marco de la barra central. Ningún jugador lo lleva, elija el color
  /// que elija, para que la barra no se confunda con un panel.
  static const CardFrame bar = tierra;

  /// Un marco para cada jugador, nunca el mismo ni el de la barra: si
  /// coinciden, el de abajo se queda con su siguiente opción.
  static (CardFrame, CardFrame) forPlayers(Color top, Color bottom) {
    final first = rankFor(top).firstWhere((f) => f != bar);
    final second = rankFor(bottom).firstWhere((f) => f != first && f != bar);
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
      // Antes 0.82: el fondo apenas se veía. La sombra del número lo despega.
      veil: 0.66,
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
      // En cristal el fondo va casi limpio: sin foco, las partes claras de
      // la imagen se comían el número.
      focusByDefault: true,
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
    // La barra es una carta tumbada con su marco: 76 de alto.
    AppTheme.classic => 78,
  };

  /// Opacidad de la barra central si no se cambia en Ajustes.
  int get defaultBarOpacity => switch (theme) {
    AppTheme.original => 97,
    AppTheme.modern => isCards ? 92 : 94,
    // La carta dorada deja ver el fondo por detrás.
    AppTheme.classic => 65,
  };

  /// Opacidad del fondo del historial si no se cambia en Ajustes.
  int get defaultHistoryOpacity => switch (theme) {
    AppTheme.original => 50,
    AppTheme.modern => 30,
    // La caja de texto, igual: con 80 tapaba el fondo del todo.
    AppTheme.classic => 60,
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

/// Tinta oscura del borde antiguo, sobre el pergamino.
const Color kInk = Color(0xFF2A1D10);

/// Los botones del borde antiguo, como un símbolo de coste de maná
/// genérico: el redondel gris de las cartas, con el dibujo en [kManaInk] y
/// la sombra negra desplazada abajo a la izquierda de la impresión.
/// Lo que mide un símbolo de maná de la barra del borde antiguo: con su
/// sombra cabe en la caja de la tierra doble sin tocar el reborde.
const double kManaPipSize = 32;

/// Lo mismo, alargado: el reloj y la cantidad por toque de esa barra.
const BoxDecoration kManaPill = BoxDecoration(
  color: kManaGray,
  borderRadius: BorderRadius.all(Radius.circular(kManaPipSize / 2)),
  border: Border.fromBorderSide(BorderSide(color: Color(0x66000000))),
  boxShadow: [BoxShadow(color: Color(0xFF0B0705), offset: Offset(-1.5, 2.5))],
);

const BoxDecoration kManaPip = BoxDecoration(
  shape: BoxShape.circle,
  color: kManaGray,
  border: Border.fromBorderSide(BorderSide(color: Color(0x66000000))),
  boxShadow: [BoxShadow(color: Color(0xFF0B0705), offset: Offset(-1.5, 2.5))],
);

/// El gris del maná genérico y la tinta de los símbolos.
const Color kManaGray = Color(0xFFCAC5C0);
const Color kManaInk = Color(0xFF0D0F0F);
