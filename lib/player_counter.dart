import 'dart:async';
import 'dart:math';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:mtglifecounter/game_state.dart';
import 'package:mtglifecounter/look.dart';
import 'package:mtglifecounter/screen_image.dart';
import 'package:mtglifecounter/skin.dart';

/// Lo que el panel necesita saber del aspecto elegido en Ajustes.
class PanelStyle {
  const PanelStyle({
    required this.look,
    required this.background,
    required this.backgroundMode,
    required this.imageOpacity,
    required this.frameOpacity,
    required this.historyOpacity,
    this.showHistory = true,
    required this.zoneMarks,
    required this.focus,
    required this.animations,
    required this.screenKey,
  });

  final Look look;

  /// La imagen de fondo de la skin, o `null` si no lleva.
  final ImageProvider? background;
  final BackgroundMode backgroundMode;

  /// De 0 a 1.
  final double imageOpacity;

  /// De 0 a 1: el marco del borde antiguo.
  final double frameOpacity;

  /// De 0 a 1: el fondo del historial.
  final double historyOpacity;

  /// Sin historial el número se centra en todo el panel y, en el borde
  /// antiguo, la carta pierde la caja de texto y la línea de tipo.
  final bool showHistory;

  /// Cómo se distingue la mitad que suma de la que resta.
  final ZoneMarks zoneMarks;
  final bool focus;
  final bool animations;

  /// El widget que ocupa toda la pantalla, para [ScreenAlignedImage].
  final GlobalKey screenKey;
}

class PlayerCounter extends StatefulWidget {
  final PlayerState player;
  final Color color;

  /// El marco de carta del jugador en el borde antiguo.
  final CardFrame frame;
  final PanelStyle style;
  final int lifeChangeAmount;
  final VoidCallback onLifeChanged;

  const PlayerCounter({
    super.key,
    required this.player,
    required this.color,
    required this.frame,
    required this.style,
    required this.lifeChangeAmount,
    required this.onLifeChanged,
  });

  @override
  State<PlayerCounter> createState() => _PlayerCounterState();
}

class _PlayerCounterState extends State<PlayerCounter>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();

  // Efecto «golpe»: al perder el número se sacude y el borde se tiñe de
  // rojo; al ganar el número crece un poco y el borde brilla en verde.
  late final AnimationController _hit = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );
  bool _gained = true;
  late int _lastLife;

  // Variables para la lógica de debounce
  Timer? _debounceTimer;
  int _historyLength = 0;

  @override
  void initState() {
    super.initState();
    _historyLength = widget.player.history.length;
    _lastLife = widget.player.life;
    widget.player.addListener(_onPlayerChanged);
    // Si la partida se ha recuperado, el historial empieza mostrando lo último.
    _showLatest();
  }

  @override
  void didUpdateWidget(PlayerCounter old) {
    super.didUpdateWidget(old);
    // Al volver a enseñar el historial, también desde lo último.
    if (widget.style.showHistory && !old.style.showHistory) _showLatest();
  }

  void _showLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    widget.player.removeListener(_onPlayerChanged);
    _scrollController.dispose();
    _debounceTimer?.cancel();
    _hit.dispose();
    super.dispose();
  }

  void _onPlayerChanged() {
    final life = widget.player.life;
    final length = widget.player.history.length;
    if (length < _historyLength) {
      // Se ha reiniciado la partida: lo que estuviera agrupándose ya no vale.
      _debounceTimer?.cancel();
    } else if (life != _lastLife && widget.style.animations) {
      _gained = life > _lastLife;
      _hit.forward(from: 0);
    }
    if (length > _historyLength) {
      // Realizamos el scroll al final del historial
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) return;
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
    _lastLife = life;
    _historyLength = length;
  }

  void _onTap(TapDownDetails details) {
    final width = context.size!.width;
    final height = context.size!.height;
    final tapX = details.localPosition.dx;
    final tapY = details.localPosition.dy;
    if (tapX >= width - _historyReserve(widget.style)) return;

    // La mitad de arriba suma y la de abajo resta.
    final change = tapY < height / 2
        ? widget.lifeChangeAmount
        : -widget.lifeChangeAmount;
    if (widget.player.change(change)) {
      widget.onLifeChanged();
    }

    // Los toques seguidos se agrupan: 750 ms después del último se apunta
    // una sola entrada en el historial.
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 750), _finalizeTap);
  }

  void _finalizeTap() {
    if (widget.player.pending == 0) return;
    widget.player.commit();
    widget.onLifeChanged();
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style;
    final look = style.look;
    final zone = _Zone(
      player: widget.player,
      color: widget.color,
      frame: widget.frame,
      style: style,
      hit: _hit,
      gained: () => _gained,
      scrollController: _scrollController,
    );
    return GestureDetector(
      onTapDown: _onTap,
      behavior: HitTestBehavior.opaque,
      child: switch (look.theme) {
        AppTheme.original => zone,
        AppTheme.modern when look.isCards => _CardFrame(
          color: widget.color,
          child: zone,
        ),
        AppTheme.modern => zone,
        AppTheme.classic => _ClassicFrame(
          alpha: style.frameOpacity,
          child: zone,
        ),
      },
    );
  }
}

/// Ancho que ocupa el historial a la derecha del panel: ahí los toques no
/// cuentan. Sin historial, todo el panel cuenta.
double _historyReserve(PanelStyle style) => !style.showHistory
    ? 0
    : switch (style.look.theme) {
        AppTheme.original => 76,
        AppTheme.modern => 72,
        AppTheme.classic => _kFrame + _kTextBox + _kTypeBand,
      };

/// Margen que deja el número a la derecha para no pisar el historial. Sin
/// historial, el mismo que a la izquierda, para que quede centrado (en el
/// borde antiguo, solo el marco).
double _numberInset(PanelStyle style) => !style.showHistory
    ? (style.look.isClassic ? _kFrame : 0)
    : switch (style.look.theme) {
        AppTheme.original => 76,
        AppTheme.modern => 72,
        AppTheme.classic => _kFrame + _kTextBox + _kTypeBand,
      };

// Medidas de la carta tumbada del borde antiguo, en dp: el marco de arriba,
// abajo y a la derecha, la franja del nombre a la izquierda, la de la línea
// de tipo entre las dos ventanas y el ancho de la caja de texto (el
// historial).
const double _kFrame = 16;
const double _kNameBand = 24;
const double _kTypeBand = 14;
const double _kTextBox = 64;

/// Tarjeta redondeada con el borde y el brillo del color del jugador.
class _CardFrame extends StatelessWidget {
  const _CardFrame({required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: color, width: 2),
        boxShadow: [
          BoxShadow(
            color: shade(color, 1.3).withValues(alpha: 0.6),
            blurRadius: 30,
            spreadRadius: -4,
          ),
        ],
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(26), child: child),
    );
  }
}

/// Borde negro de la carta antigua. El marco de color lo pintan las franjas
/// de [_CardBands] dentro del panel.
class _ClassicFrame extends StatelessWidget {
  const _ClassicFrame({required this.alpha, required this.child});

  final double alpha;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: alpha),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0xB3000000),
            offset: Offset(0, 8),
            blurRadius: 18,
          ),
        ],
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(6), child: child),
    );
  }
}

/// El marco de una carta antigua tumbada: la franja del nombre a la
/// izquierda, la de la línea de tipo entre la ilustración (el número) y la
/// caja de texto (el historial), y los bordes. Todo sale de la tira de marco
/// de una carta de verdad ([CardFrame]), girada en las franjas horizontales.
class _CardBands extends StatelessWidget {
  const _CardBands({
    required this.frame,
    required this.alpha,
    required this.textBox,
  });

  final CardFrame frame;
  final double alpha;

  /// Con historial la carta lleva caja de texto y la línea de tipo que la
  /// separa de la ilustración; sin él, solo el marco de fuera.
  final bool textBox;

  // La tira es el borde derecho de la carta: su filo exterior (con la línea
  // clara) queda a la derecha. [turns] la gira de 90 en 90 grados.
  Widget _strip({int turns = 0, bool flip = false}) {
    Widget image = Image.asset(
      frame.asset,
      fit: BoxFit.cover,
      opacity: AlwaysStoppedAnimation(alpha),
      filterQuality: FilterQuality.medium,
    );
    if (flip) image = Transform.flip(flipX: true, child: image);
    return turns == 0 ? image : RotatedBox(quarterTurns: turns, child: image);
  }

  // Franja de arriba o de abajo. Si el marco tiene tira horizontal, se pone
  // las veces que haga falta, una sí y otra no en espejo para que no se note
  // la unión; si no, se gira la del lado.
  Widget _horizontal({required int turns}) {
    final asset = frame.horizontalAsset;
    if (asset == null) return _strip(turns: turns);
    final length = frame.horizontalAspect * _kFrame;
    Widget half({bool mirror = false}) {
      final image = Image.asset(
        asset,
        fit: BoxFit.cover,
        opacity: AlwaysStoppedAnimation(alpha),
        filterQuality: FilterQuality.medium,
      );
      return Expanded(
        child: mirror ? Transform.flip(flipX: true, child: image) : image,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final copies = max(2, (constraints.maxWidth / length).ceil());
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [for (var i = 0; i < copies; i++) half(mirror: i.isOdd)],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const bevel = BoxDecoration(
      border: Border(
        top: BorderSide(color: Color(0xA6000000), width: 2),
        left: BorderSide(color: Color(0xA6000000), width: 2),
        right: BorderSide(color: Color(0x73FFF0D2), width: 2),
        bottom: BorderSide(color: Color(0x73FFF0D2), width: 2),
      ),
    );
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: _kNameBand,
            child: _strip(flip: true),
          ),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: _kFrame,
            child: _strip(),
          ),
          if (textBox)
            Positioned(
              right: _kFrame + _kTextBox,
              top: 0,
              bottom: 0,
              width: _kTypeBand,
              child: _strip(),
            ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: _kFrame,
            child: _horizontal(turns: 3),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: _kFrame,
            child: _horizontal(turns: 1),
          ),
          // La ventana de la ilustración, hundida en el marco.
          Positioned(
            left: _kNameBand,
            top: _kFrame,
            bottom: _kFrame,
            right: textBox ? _kFrame + _kTextBox + _kTypeBand : _kFrame,
            child: const DecoratedBox(decoration: bevel),
          ),
        ],
      ),
    );
  }
}

/// La zona del número: imagen, color del jugador, número, botones + y −,
/// burbuja del cambio pendiente e historial.
class _Zone extends StatelessWidget {
  const _Zone({
    required this.player,
    required this.color,
    required this.frame,
    required this.style,
    required this.hit,
    required this.gained,
    required this.scrollController,
  });

  final PlayerState player;
  final Color color;
  final PanelStyle style;
  final Animation<double> hit;
  final bool Function() gained;
  final ScrollController scrollController;
  final CardFrame frame;

  @override
  Widget build(BuildContext context) {
    final look = style.look;
    // En el borde antiguo el número va en la ventana de la ilustración, que
    // empieza tras la franja del nombre.
    final double left = look.isClassic ? _kNameBand : 0;
    final background = style.background;
    final inset = _numberInset(style);
    // Las filas de botones quedan lejos de la barra en el borde nuevo, que
    // flota encima de los paneles.
    // En cristal la barra flota sobre el borde de dentro del panel, que es
    // el de arriba o el de abajo según esté girado: se deja sitio en los dos.
    final double plusTop = look.isGlass
        ? 40
        : (look.isClassic ? _kFrame + 8 : 18);
    final double minusBottom = look.isGlass
        ? 40
        : (look.isClassic ? _kFrame + 8 : 18);
    return Stack(
      fit: StackFit.expand,
      children: [
        // Debajo de la imagen asoma el color del jugador: con poca opacidad
        // manda el color y el número se lee mejor.
        ColoredBox(color: _baseColor(look)),
        if (background != null)
          style.backgroundMode == BackgroundMode.screen
              ? ScreenAlignedImage(
                  image: background,
                  opacity: style.imageOpacity,
                  screenKey: style.screenKey,
                )
              : DecoratedBox(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: background,
                      fit: BoxFit.cover,
                      opacity: style.imageOpacity,
                    ),
                  ),
                ),
        DecoratedBox(decoration: _tint(look, background == null)),
        if (style.focus)
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-inset / 400, 0),
                radius: 0.75,
                colors: const [
                  Color(0xAD000000),
                  Color(0x6B000000),
                  Color(0x00000000),
                ],
                stops: const [0, 0.5, 1],
              ),
            ),
          ),
        // La mitad que suma se distingue de la que resta (salvo con «Línea»
        // o «Nada»).
        if (style.zoneMarks != ZoneMarks.line &&
            style.zoneMarks != ZoneMarks.none)
          _Halves(marks: style.zoneMarks),
        if (style.zoneMarks.hasLine)
          Padding(
            padding: EdgeInsets.only(left: left + 10, right: inset + 4),
            child: Center(child: _MidLine(classic: look.isClassic)),
          ),
        if (look.isClassic)
          _CardBands(
            frame: frame,
            alpha: style.frameOpacity,
            textBox: style.showHistory,
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            left + 12,
            plusTop + 50,
            // Sin historial, el mismo margen que a la izquierda.
            inset + (style.showHistory ? 4 : 12),
            minusBottom + 50,
          ),
          child: Center(
            child: _HitNumber(
              player: player,
              look: look,
              color: color,
              hit: hit,
              gained: gained,
            ),
          ),
        ),
        Positioned(
          top: plusTop,
          left: left,
          right: inset,
          child: Center(
            child: _Pip(look: look, color: color, sign: '+'),
          ),
        ),
        Positioned(
          bottom: minusBottom,
          left: left,
          right: inset,
          child: Center(
            child: _Pip(look: look, color: color, sign: '−'),
          ),
        ),
        // Borde que se tiñe al cambiar la vida.
        IgnorePointer(
          child: AnimatedBuilder(
            animation: hit,
            builder: (context, _) {
              final t = 1 - hit.value;
              if (t <= 0 || hit.isDismissed) return const SizedBox.shrink();
              final glow = hitColor(up: gained(), panel: color);
              return DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    radius: 1.05,
                    colors: [
                      glow.withValues(alpha: 0),
                      glow.withValues(alpha: 0.75 * t),
                    ],
                    stops: const [0.55, 1],
                  ),
                ),
              );
            },
          ),
        ),
        // Burbuja con el cambio que aún no está en el historial, en el centro
        // del panel, encima del número.
        Positioned.fill(
          left: left,
          right: inset,
          child: IgnorePointer(
            child: Center(
              child: ListenableBuilder(
                listenable: player,
                builder: (context, _) {
                  final pending = player.pending;
                  if (pending == 0) return const SizedBox.shrink();
                  return _Bubble(look: look, pending: pending);
                },
              ),
            ),
          ),
        ),
        if (style.showHistory)
          _History(
            player: player,
            look: look,
            color: color,
            frame: frame,
            alpha: style.historyOpacity,
            controller: scrollController,
          ),
      ],
    );
  }

  Color _baseColor(Look look) => switch (look.theme) {
    AppTheme.original => color,
    AppTheme.modern => shade(color, 0.8),
    AppTheme.classic => shade(color, 0.55),
  };

  BoxDecoration _tint(Look look, bool noImage) {
    if (noImage) {
      return BoxDecoration(color: color.withValues(alpha: 0.86));
    }
    if (look.tintMode == TintMode.edge) return const BoxDecoration();
    if (look.isGlass) {
      return BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: look.veil),
            shade(color, 0.72).withValues(alpha: look.veil + 0.15),
          ],
        ),
      );
    }
    return BoxDecoration(color: color.withValues(alpha: look.veil));
  }
}

/// Color del golpe: verde al ganar y rojo al perder. Si el panel ya es de ese
/// tono (el verde de AlicanteMTG, el granate de Full Tapped), se usa uno que
/// contraste con él: lima al ganar y naranja al perder.
Color hitColor({required bool up, required Color panel}) {
  final hue = HSVColor.fromColor(panel).hue;
  double distance(double a, double b) {
    final d = (a - b).abs() % 360;
    return d > 180 ? 360 - d : d;
  }

  if (up) {
    return distance(hue, 135) < 45
        ? const Color(0xFFE6FF5C)
        : const Color(0xFF4ADE80);
  }
  return distance(hue, 0) < 30
      ? const Color(0xFFFFB347)
      : const Color(0xFFF85050);
}

/// El tono de las dos mitades: arriba más claro (suma), abajo más oscuro
/// (resta).
class _Halves extends StatelessWidget {
  const _Halves({required this.marks});

  final ZoneMarks marks;

  // Colores lisos y no degradados: lo que se ve es el corte en medio, y con
  // un degradado que se apagaba hacia el centro apenas se notaba.
  @override
  Widget build(BuildContext context) {
    final (Color top, Color bottom) = switch (marks) {
      ZoneMarks.soft || ZoneMarks.both => (
        Colors.white.withValues(alpha: 0.1),
        Colors.black.withValues(alpha: 0.22),
      ),
      ZoneMarks.strong => (
        Colors.white.withValues(alpha: 0.22),
        Colors.black.withValues(alpha: 0.45),
      ),
      ZoneMarks.color => (
        const Color(0xFF4ADE80).withValues(alpha: 0.18),
        const Color(0xFFF85050).withValues(alpha: 0.2),
      ),
      ZoneMarks.line ||
      ZoneMarks.none => (Colors.transparent, Colors.transparent),
    };
    // Sin stretch las cajas vacías se quedan con 0 de ancho y no se ve nada.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: ColoredBox(color: top)),
        Expanded(child: ColoredBox(color: bottom)),
      ],
    );
  }
}

/// Línea discontinua entre la mitad que suma y la que resta. Va por detrás
/// del número.
class _MidLine extends StatelessWidget {
  const _MidLine({required this.classic});

  final bool classic;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, 2),
      painter: _DashPainter(
        classic ? const Color(0x99F6EDD5) : const Color(0x80FFFFFF),
      ),
    );
  }
}

class _DashPainter extends CustomPainter {
  _DashPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    const dash = 10.0, gap = 8.0;
    final y = size.height / 2;
    for (var x = 0.0; x < size.width; x += dash + gap) {
      canvas.drawLine(
        Offset(x, y),
        Offset(min(x + dash, size.width), y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.color != color;
}

/// El número de vidas con el efecto golpe.
class _HitNumber extends StatelessWidget {
  const _HitNumber({
    required this.player,
    required this.look,
    required this.color,
    required this.hit,
    required this.gained,
  });

  final PlayerState player;
  final Look look;
  final Color color;
  final Animation<double> hit;
  final bool Function() gained;

  List<Shadow> _baseShadows() => switch (look.theme) {
    AppTheme.original => const [
      Shadow(color: Color(0x59000000), offset: Offset(0, 2), blurRadius: 4),
    ],
    AppTheme.modern => [
      const Shadow(color: Color(0xD9000000), blurRadius: 2),
      const Shadow(color: Color(0x59000000), offset: Offset(0, 2)),
      if (look.isCards)
        Shadow(color: shade(color, 1.3).withValues(alpha: 0.9), blurRadius: 28)
      else
        const Shadow(color: Color(0x99000000), blurRadius: 28),
    ],
    AppTheme.classic => const [
      Shadow(color: Colors.black, offset: Offset(0, 3)),
      Shadow(color: Color(0xCC000000), blurRadius: 22),
    ],
  };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: player,
      builder: (context, _) {
        final text = '${player.life}'.replaceFirst('-', '−');
        return AnimatedBuilder(
          animation: hit,
          builder: (context, _) {
            final t = hit.value;
            final active = hit.isAnimating;
            final up = gained();
            final glow = hitColor(up: up, panel: color);
            final fade = active ? 1 - t : 0.0;
            // El número se tiñe un poco por dentro y lleva un contorno oscuro
            // suave mientras dura el golpe: así se nota aunque el panel sea
            // del mismo color, sin que el número cambie del todo.
            final fill = Color.lerp(look.numberColor, glow, 0.45 * fade)!;
            final shadows = [
              if (fade > 0)
                Shadow(
                  color: Colors.black.withValues(alpha: 0.45 * fade),
                  blurRadius: 4,
                ),
              ..._baseShadows(),
              if (fade > 0)
                Shadow(
                  color: glow.withValues(alpha: 0.9 * fade),
                  blurRadius: 38,
                ),
            ];
            // Al ganar crece un poco; al perder se sacude de lado a lado.
            final scale = up && active ? 1 + 0.08 * (1 - t) : 1.0;
            final dx = !up && active && t < 0.7
                ? 9 * sin(t * pi * 8) * (1 - t / 0.7)
                : 0.0;
            return Transform.translate(
              offset: Offset(dx, 0),
              child: Transform.scale(
                scale: scale,
                child: AutoSizeText(
                  text,
                  style: look
                      .numberStyle(500 * look.numberScale)
                      .copyWith(color: fill, shadows: shadows),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  // Bajo para que «−999» quepa entero en las pantallas
                  // estrechas: con 60 se cortaba y se leía «−99».
                  minFontSize: 24,
                  textScaleFactor: 1.0,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Botón visual de + o −. Va en un círculo para que se vea sobre cualquier
/// imagen.
class _Pip extends StatelessWidget {
  const _Pip({required this.look, required this.color, required this.sign});

  final Look look;
  final Color color;
  final String sign;

  @override
  Widget build(BuildContext context) {
    if (look.theme == AppTheme.modern) return _modern();
    final classic = look.isClassic;
    final size = classic ? 42.0 : 46.0;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: classic
          ? kParchmentPip
          : BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.42),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.55),
                width: 1.5,
              ),
            ),
      child: Text(
        sign,
        style: withFont(
          look.numberFont,
          TextStyle(
            color: classic ? kInk : Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.w700,
            height: 1,
            fontFeatures: kNumberFeatures,
          ),
        ),
      ),
    );
  }

  // En el borde nuevo el signo es un icono: el + y el − de Barlow y Outfit no
  // quedan centrados dentro del círculo.
  Widget _modern() {
    final icon = sign == '+' ? Icons.add_rounded : Icons.remove_rounded;
    final edge = look.isCards
        ? shade(color, 1.3)
        : Colors.white.withValues(alpha: 0.55);
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black.withValues(alpha: 0.42),
        border: Border.all(color: edge, width: 1.5),
      ),
      child: Icon(icon, color: Colors.white, size: 30),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.look, required this.pending});

  final Look look;
  final int pending;

  @override
  Widget build(BuildContext context) {
    final up = pending > 0;
    final classic = look.isClassic;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: classic ? null : Colors.black.withValues(alpha: 0.7),
        gradient: classic
            ? const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFF2E8CF), Color(0xFFE0CFA6)],
              )
            : null,
        boxShadow: classic
            ? const [BoxShadow(color: Color(0xFF0B0705), spreadRadius: 2)]
            : null,
      ),
      child: Text(
        up ? '+$pending' : '−${-pending}',
        style: withFont(
          look.numberFont,
          TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            fontFeatures: kNumberFeatures,
            color: classic
                ? (up ? const Color(0xFF1D6A2B) : const Color(0xFF8F1C1C))
                : (up ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5)),
          ),
        ),
      ),
    );
  }
}

/// El historial: una entrada `+N = vida` por cada grupo de toques.
class _History extends StatelessWidget {
  const _History({
    required this.player,
    required this.look,
    required this.color,
    required this.frame,
    required this.alpha,
    required this.controller,
  });

  final PlayerState player;
  final Look look;
  final Color color;
  final double alpha;
  final CardFrame frame;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    final classic = look.isClassic;
    final list = ListenableBuilder(
      listenable: player,
      builder: (context, _) {
        final history = player.history;
        return ListView.builder(
          controller: controller,
          padding: EdgeInsets.symmetric(
            vertical: classic ? 4 : 6,
            horizontal: classic ? 2 : 4,
          ),
          itemCount: history.length,
          itemBuilder: (context, index) => _HistoryLine(
            entry: history[index],
            look: look,
            last: index == history.length - 1,
            darkBox: classic && frame.darkTextBox,
          ),
        );
      },
    );
    return switch (look.theme) {
      AppTheme.original => Positioned(
        top: 0,
        bottom: 0,
        right: 0,
        width: 76,
        child: ColoredBox(
          color: Colors.black.withValues(alpha: alpha),
          child: list,
        ),
      ),
      AppTheme.modern => Positioned(
        // En cristal la barra flota sobre el borde de dentro del panel.
        top: look.isGlass ? 40 : 14,
        bottom: look.isGlass ? 40 : 14,
        right: 10,
        width: 62,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: alpha),
            borderRadius: BorderRadius.circular(look.isCards ? 18 : 16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
          ),
          clipBehavior: Clip.antiAlias,
          child: list,
        ),
      ),
      AppTheme.classic => Positioned(
        top: _kFrame,
        bottom: _kFrame,
        right: _kFrame,
        width: _kTextBox,
        // La caja de texto de la carta de su marco (agua en la azul, madera
        // en la verde...), con un bisel como si estuviera hundida en él.
        child: DecoratedBox(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage(frame.textBoxAsset),
              fit: BoxFit.cover,
              opacity: alpha,
              // Las cajas oscuras se oscurecen algo más para la tinta clara.
              colorFilter: frame.darkTextBox
                  ? const ColorFilter.mode(Color(0x4D000000), BlendMode.srcATop)
                  : null,
            ),
            border: const Border(
              top: BorderSide(color: Color(0xCC2A2218), width: 2),
              left: BorderSide(color: Color(0xCC2A2218), width: 2),
              right: BorderSide(color: Color(0x99F5F0E4), width: 2),
              bottom: BorderSide(color: Color(0x99F5F0E4), width: 2),
            ),
          ),
          child: list,
        ),
      ),
    };
  }
}

class _HistoryLine extends StatelessWidget {
  const _HistoryLine({
    required this.entry,
    required this.look,
    required this.last,
    this.darkBox = false,
  });

  final String entry;
  final Look look;
  final bool last;

  /// En el Old Border, si la caja de texto es oscura y va en tinta clara.
  final bool darkBox;

  @override
  Widget build(BuildContext context) {
    // Las entradas son «-5 = 15» o «+2 = 17».
    final parts = entry.split(' = ');
    final delta = parts.first.replaceFirst('-', '−');
    final value = parts.length > 1 ? parts[1].replaceFirst('-', '−') : '';
    final up = delta.startsWith('+');
    final classic = look.isClassic;
    final original = look.theme == AppTheme.original;
    // En el Old Border la tinta depende de la caja: oscura sobre las claras y
    // clara sobre el rojo y la madera. Medida para pasar de 4,5:1.
    final deltaColor = classic
        ? darkBox
              ? (up ? const Color(0xFFD4FFC9) : const Color(0xFFFFD8CF))
              : (up ? const Color(0xFF0A3D12) : const Color(0xFF5C0A0A))
        : original
        ? (up ? const Color(0xFF69F0AE) : const Color(0xFFFF5252))
        : (up ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5));
    final valueColor = classic
        ? (darkBox ? const Color(0xFFFFF6E4) : const Color(0xFF14110E))
        : Colors.white.withValues(alpha: original ? 1 : 0.75);
    // Un halo del color contrario separa los números de la textura.
    final halo = classic
        ? darkBox
              ? const [
                  Shadow(color: Color(0xE6000000), blurRadius: 2),
                  Shadow(color: Color(0x99000000), blurRadius: 6),
                ]
              : const [
                  Shadow(color: Color(0xE6FAF7EE), blurRadius: 2),
                  Shadow(color: Color(0x99FAF7EE), blurRadius: 6),
                ]
        : null;
    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: last
          ? BoxDecoration(
              color: classic
                  ? darkBox
                        ? Colors.black.withValues(alpha: 0.3)
                        : Colors.white.withValues(alpha: 0.4)
                  : Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(classic ? 2 : 8),
            )
          : null,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Text(
              delta,
              style: withFont(
                look.numberFont,
                TextStyle(
                  color: deltaColor,
                  fontWeight: classic ? FontWeight.w800 : FontWeight.w700,
                  fontSize: original ? 18 : (classic ? 16 : 15),
                  shadows: halo,
                  fontFeatures: kNumberFeatures,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              value,
              style: withFont(
                look.numberFont,
                TextStyle(
                  color: valueColor,
                  fontWeight: classic ? FontWeight.w700 : FontWeight.w600,
                  fontSize: original ? 15 : (classic ? 15 : 13),
                  shadows: halo,
                  fontFeatures: kNumberFeatures,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// La imagen de fondo de la pantalla entera: se ve en los huecos entre
/// paneles y, un poco, a través de los marcos.
class ScreenBackground extends StatelessWidget {
  const ScreenBackground({super.key, required this.skin, required this.style});

  final Skin skin;
  final PanelStyle style;

  @override
  Widget build(BuildContext context) {
    final background = style.background;
    if (background == null || style.backgroundMode != BackgroundMode.screen) {
      return const ColoredBox(color: Colors.black);
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black,
        image: DecorationImage(
          image: background,
          fit: BoxFit.cover,
          opacity: style.imageOpacity * (style.look.isCards ? 0.45 : 1),
        ),
      ),
    );
  }
}
