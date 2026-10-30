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
  final bool focus;
  final bool animations;

  /// El widget que ocupa toda la pantalla, para [ScreenAlignedImage].
  final GlobalKey screenKey;
}

class PlayerCounter extends StatefulWidget {
  final PlayerState player;
  final Color color;
  final PanelStyle style;
  final int lifeChangeAmount;
  final VoidCallback onLifeChanged;

  const PlayerCounter({
    super.key,
    required this.player,
    required this.color,
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
    if (tapX >= width - _historyReserve(widget.style.look)) return;

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
          color: widget.color,
          alpha: style.frameOpacity,
          child: zone,
        ),
      },
    );
  }
}

/// Ancho que ocupa el historial a la derecha del panel: ahí los toques no
/// cuentan.
double _historyReserve(Look look) => switch (look.theme) {
  AppTheme.original => 76,
  AppTheme.modern => 72,
  AppTheme.classic => 80,
};

/// Margen que deja el número a la derecha para no pisar el historial.
double _numberInset(Look look) => switch (look.theme) {
  AppTheme.original => 76,
  AppTheme.modern => 72,
  AppTheme.classic => 70,
};

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

/// Marco fino de carta antigua: borde negro, jaspeado del color del jugador y
/// una ventana biselada para la imagen.
class _ClassicFrame extends StatelessWidget {
  const _ClassicFrame({
    required this.color,
    required this.alpha,
    required this.child,
  });

  final Color color;
  final double alpha;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: alpha),
            spreadRadius: 5,
          ),
          const BoxShadow(
            color: Color(0xB3000000),
            offset: Offset(0, 8),
            blurRadius: 18,
          ),
        ],
      ),
      child: Mottled(
        color: color,
        alpha: alpha,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Container(
            // Bisel: sombra arriba e izquierda, luz abajo y derecha.
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Color(0xA6000000), width: 3),
                left: BorderSide(color: Color(0xA6000000), width: 3),
                right: BorderSide(color: Color(0x73FFF0D2), width: 3),
                bottom: BorderSide(color: Color(0x73FFF0D2), width: 3),
              ),
            ),
            child: ClipRect(child: child),
          ),
        ),
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

  @override
  Widget build(BuildContext context) {
    final look = style.look;
    final background = style.background;
    final inset = _numberInset(look);
    // Las filas de botones quedan lejos de la barra en el borde nuevo, que
    // flota encima de los paneles.
    // En cristal la barra flota sobre el borde de dentro del panel, que es
    // el de arriba o el de abajo según esté girado: se deja sitio en los dos.
    final double plusTop = look.isGlass ? 40 : (look.isClassic ? 14 : 18);
    final double minusBottom = look.isGlass ? 40 : (look.isClassic ? 14 : 18);
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
        // Tono sutil: la mitad que suma algo más clara, la que resta más oscura.
        const Column(
          children: [
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x1AFFFFFF), Color(0x0AFFFFFF)],
                  ),
                ),
              ),
            ),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x1A000000), Color(0x38000000)],
                  ),
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(12, plusTop + 50, inset + 4, minusBottom + 50),
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
          left: 0,
          right: inset,
          child: Center(child: _Pip(look: look, color: color, sign: '+')),
        ),
        Positioned(
          bottom: minusBottom,
          left: 0,
          right: inset,
          child: Center(child: _Pip(look: look, color: color, sign: '−')),
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
        _History(
          player: player,
          look: look,
          color: color,
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
                Shadow(color: Colors.black.withValues(alpha: 0.45 * fade), blurRadius: 4),
              ..._baseShadows(),
              if (fade > 0)
                Shadow(color: glow.withValues(alpha: 0.9 * fade), blurRadius: 38),
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
                  minFontSize: 60,
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
                color: look.isCards
                    ? shade(color, 1.3)
                    : Colors.white.withValues(alpha: 0.55),
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
    required this.alpha,
    required this.controller,
  });

  final PlayerState player;
  final Look look;
  final Color color;
  final double alpha;
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
        child: ColoredBox(color: Colors.black.withValues(alpha: alpha), child: list),
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
        top: 8,
        bottom: 8,
        right: 8,
        width: 60,
        // La caja de texto de los artefactos antiguos: pergamino gris con
        // manchas, y un bisel como si estuviera hundida en el marco.
        child: _Layers(layers: _artifactBox(alpha), child: list),
      ),
    };
  }
}

/// Capas de la caja de texto de los artefactos: pergamino gris con manchas
/// de luz y sombra y un bisel hundido.
List<Decoration> _artifactBox(double alpha) => [
  BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        const Color(0xFFECE6D8).withValues(alpha: alpha),
        const Color(0xFFCBC2AF).withValues(alpha: alpha),
      ],
    ),
  ),
  BoxDecoration(
    gradient: RadialGradient(
      center: const Alignment(-0.6, -0.5),
      radius: 0.9,
      colors: [
        Colors.white.withValues(alpha: 0.5 * alpha),
        Colors.white.withValues(alpha: 0),
      ],
    ),
  ),
  BoxDecoration(
    gradient: RadialGradient(
      center: const Alignment(0.7, 0.1),
      radius: 0.7,
      colors: [
        const Color(0xFF5A4E3C).withValues(alpha: 0.3 * alpha),
        const Color(0x005A4E3C),
      ],
    ),
  ),
  BoxDecoration(
    gradient: RadialGradient(
      center: const Alignment(-0.3, 0.75),
      radius: 0.8,
      colors: [
        const Color(0xFF5A4E3C).withValues(alpha: 0.26 * alpha),
        const Color(0x005A4E3C),
      ],
    ),
  ),
  BoxDecoration(
    gradient: RadialGradient(
      center: const Alignment(0.4, -0.85),
      radius: 0.5,
      colors: [
        Colors.white.withValues(alpha: 0.25 * alpha),
        Colors.white.withValues(alpha: 0),
      ],
    ),
  ),
  // El bisel: sombra arriba e izquierda, luz abajo y derecha.
  const BoxDecoration(
    border: Border(
      top: BorderSide(color: Color(0xCC4A4033), width: 2),
      left: BorderSide(color: Color(0xCC4A4033), width: 2),
      right: BorderSide(color: Color(0xCCF5F0E4), width: 2),
      bottom: BorderSide(color: Color(0xCCF5F0E4), width: 2),
    ),
  ),
];

/// Pinta [layers] una encima de otra detrás de [child].
class _Layers extends StatelessWidget {
  const _Layers({required this.layers, required this.child});

  final List<Decoration> layers;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    Widget result = child;
    for (final layer in layers.reversed) {
      result = DecoratedBox(decoration: layer, child: result);
    }
    return result;
  }
}

class _HistoryLine extends StatelessWidget {
  const _HistoryLine({
    required this.entry,
    required this.look,
    required this.last,
  });

  final String entry;
  final Look look;
  final bool last;

  @override
  Widget build(BuildContext context) {
    // Las entradas son «-5 = 15» o «+2 = 17».
    final parts = entry.split(' = ');
    final delta = parts.first.replaceFirst('-', '−');
    final value = parts.length > 1 ? parts[1].replaceFirst('-', '−') : '';
    final up = delta.startsWith('+');
    final classic = look.isClassic;
    final original = look.theme == AppTheme.original;
    final deltaColor = classic
        ? (up ? const Color(0xFF1D6A2B) : const Color(0xFF8F1C1C))
        : original
        ? (up ? const Color(0xFF69F0AE) : const Color(0xFFFF5252))
        : (up ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5));
    final valueColor = classic
        ? const Color(0xFF1F1D19)
        : Colors.white.withValues(alpha: original ? 1 : 0.75);
    final halo = classic
        ? const [Shadow(color: Color(0xE6FAF7EE), blurRadius: 3)]
        : null;
    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: last
          ? BoxDecoration(
              color: classic
                  ? Colors.white.withValues(alpha: 0.35)
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
                  fontWeight: FontWeight.w700,
                  fontSize: original ? 18 : 15,
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
                  fontWeight: FontWeight.w600,
                  fontSize: original ? 15 : 13,
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
