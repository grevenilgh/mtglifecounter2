import 'package:flutter/material.dart';

/// Imagen de fondo que puede llevar una skin.
enum SkinBackground {
  alicante('assets/images/BackgroundBW.png', 'AlicanteMTG'),
  fullTapped('assets/images/tap.png', 'Full Tapped'),
  oldSchool(
    'assets/images/oldschool.png',
    'Old School',
    screenAsset: 'assets/images/oldschool_pantalla.png',
  ),
  none(null, 'Sin imagen'),

  /// Una foto elegida por el usuario. Sus bytes los guarda [AppSettings].
  photo(null, 'Tu imagen');

  const SkinBackground(this.asset, this.label, {this.screenAsset});

  final String? asset;
  final String label;

  /// La versión para «una imagen para toda la pantalla», si la forma de
  /// [asset] no va con la de un móvil. El logo de Old School es casi
  /// cuadrado: al cubrir la pantalla perdía medio rótulo por los lados, así
  /// que esta lo lleva algo estirado de alto y con margen arriba y abajo.
  final String? screenAsset;

  static SkinBackground fromName(String? name) =>
      values.firstWhere((b) => b.name == name, orElse: () => none);
}

/// Colores y fondo del contador. Los valores de las skins publicadas están
/// documentados en `branding/README.md`: si cambias uno, actualiza la tabla.
class Skin {
  const Skin({
    required this.id,
    required this.name,
    required this.top,
    required this.bottom,
    required this.bar,
    required this.background,
  });

  final String id;
  final String name;
  final Color top;
  final Color bottom;
  final Color bar;
  final SkinBackground background;

  static const alicante = Skin(
    id: 'alicante',
    name: 'AlicanteMTG',
    top: Color(0xFF673AB7), // Colors.deepPurple
    bottom: Color(0xFF4CAF50), // Colors.green
    bar: Color(0xFF424242), // Colors.grey[800]
    background: SkinBackground.alicante,
  );

  static const fullTapped = Skin(
    id: 'fulltapped',
    name: 'Full Tapped',
    top: Color(0xFF9B1D20), // granate
    bottom: Color(0xFF3D2B3D), // berenjena
    bar: Color(0xFF424242),
    background: SkinBackground.fullTapped,
  );

  /// La de Old School MTG Channel (oldschoolmtgchannel.com): el azul de la
  /// cabecera de su web, el gris carbón de su logo y el casi negro de sus
  /// textos para la barra. De fondo, su logo con la gorra y el micro.
  static const oldSchool = Skin(
    id: 'oldschool',
    name: 'Old School',
    top: Color(0xFF006AA9), // azul de la web
    bottom: Color(0xFF484848), // gris carbón del logo
    bar: Color(0xFF1F2020), // casi negro de los textos
    background: SkinBackground.oldSchool,
  );

  /// Punto de partida de la skin personalizada: los colores del contador de
  /// mtgtournament (azul y burdeos con la barra en gris cálido).
  static const customDefault = Skin(
    id: 'custom',
    name: 'Personalizada',
    top: Color(0xFF1E3A5F),
    bottom: Color(0xFF8C2B34),
    bar: Color(0xFF37342D),
    background: SkinBackground.none,
  );

  static const presets = [alicante, fullTapped, oldSchool];

  // Los paneles y la barra son semitransparentes para que se vea el fondo.
  Color get topPanel => top.withAlpha(225);
  Color get bottomPanel => bottom.withAlpha(225);
  Color get barColor => bar.withAlpha(248);

  Skin copyWith({
    Color? top,
    Color? bottom,
    Color? bar,
    SkinBackground? background,
  }) {
    return Skin(
      id: id,
      name: name,
      top: top ?? this.top,
      bottom: bottom ?? this.bottom,
      bar: bar ?? this.bar,
      background: background ?? this.background,
    );
  }

  Map<String, dynamic> toJson() => {
    'top': top.toARGB32(),
    'bottom': bottom.toARGB32(),
    'bar': bar.toARGB32(),
    'background': background.name,
  };

  /// Reconstruye la skin personalizada guardada. Lo que falte o esté mal
  /// sale de [customDefault].
  static Skin customFromJson(Map<String, dynamic> json) {
    Color? color(String key) =>
        json[key] is int ? Color(json[key] as int) : null;
    return customDefault.copyWith(
      top: color('top'),
      bottom: color('bottom'),
      bar: color('bar'),
      background: SkinBackground.fromName(json['background'] as String?),
    );
  }
}
