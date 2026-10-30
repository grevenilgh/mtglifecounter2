import 'package:flutter/widgets.dart';

/// Pinta la imagen de fondo como si ocupara toda la pantalla, pero solo el
/// trozo que cae debajo de este widget. Así, con «una imagen para toda la
/// pantalla», los dos paneles enseñan una imagen continua, y derecha aunque el
/// panel de arriba esté girado.
///
/// [screenKey] marca el widget que ocupa la pantalla entera.
class ScreenAlignedImage extends LeafRenderObjectWidget {
  const ScreenAlignedImage({
    super.key,
    required this.image,
    required this.opacity,
    required this.screenKey,
  });

  final ImageProvider image;
  final double opacity;
  final GlobalKey screenKey;

  @override
  RenderObject createRenderObject(BuildContext context) => RenderScreenImage(
    image: image,
    opacity: opacity,
    screenKey: screenKey,
    configuration: createLocalImageConfiguration(context),
  );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderScreenImage renderObject,
  ) {
    renderObject
      ..image = image
      ..opacity = opacity
      ..screenKey = screenKey
      ..configuration = createLocalImageConfiguration(context);
  }
}

/// El [RenderBox] de [ScreenAlignedImage].
class RenderScreenImage extends RenderBox {
  RenderScreenImage({
    required ImageProvider image,
    required double opacity,
    required this.screenKey,
    required this.configuration,
  }) : _image = image,
       _opacity = opacity;

  ImageProvider _image;
  double _opacity;
  GlobalKey screenKey;
  ImageConfiguration configuration;
  DecorationImagePainter? _painter;

  set image(ImageProvider value) {
    if (value == _image) return;
    _image = value;
    _resetPainter();
  }

  set opacity(double value) {
    if (value == _opacity) return;
    _opacity = value;
    _resetPainter();
  }

  void _resetPainter() {
    _painter?.dispose();
    _painter = null;
    markNeedsPaint();
  }

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  @override
  void paint(PaintingContext context, Offset offset) {
    final screen = screenKey.currentContext?.findRenderObject();
    if (screen is! RenderBox || !screen.hasSize || _opacity <= 0) return;
    // De las coordenadas de este widget a las de la pantalla, y al revés.
    final toLocal = Matrix4.tryInvert(getTransformTo(screen));
    if (toLocal == null) return;
    final canvas = context.canvas;
    canvas
      ..save()
      ..clipRect(offset & size)
      ..translate(offset.dx, offset.dy)
      ..transform(toLocal.storage);
    _painter ??= DecorationImage(
      image: _image,
      fit: BoxFit.cover,
      opacity: _opacity,
    ).createPainter(markNeedsPaint);
    _painter!.paint(
      canvas,
      Offset.zero & screen.size,
      null,
      configuration.copyWith(size: screen.size),
    );
    canvas.restore();
  }

  @override
  void detach() {
    _painter?.dispose();
    _painter = null;
    super.detach();
  }
}
