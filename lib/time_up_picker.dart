import 'package:flutter/material.dart';
import 'package:mtglifecounter/app_settings.dart';
import 'package:mtglifecounter/look.dart';
import 'package:mtglifecounter/settings_page.dart';
import 'package:mtglifecounter/skin.dart';
import 'package:mtglifecounter/time_up.dart';

/// El aviso de fin de ronda de Ajustes → Diseño. Como los colores, solo se
/// elige con la skin personalizada: entonces sale una miniatura de cada aviso,
/// de dos en dos (los generales y luego los de las comunidades). Con las
/// demás skins, solo la del suyo. Quieta, la miniatura enseña el aviso
/// entero; al tocarla se ve animada una vez (y, en la personalizada, se
/// elige).
class TimeUpPicker extends StatelessWidget {
  const TimeUpPicker({super.key, required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final custom = settings.skinId == Skin.customDefault.id;
    final chosen = settings.timeUpStyle;
    final styles = custom
        ? [
            for (final style in TimeUpStyle.values)
              if (style.skinId == null) style,
            for (final style in TimeUpStyle.values)
              if (style.skinId != null) style,
          ]
        : [chosen];
    return Column(
      children: [
        for (var i = 0; i < styles.length; i += 2)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var j = i; j < i + 2; j++) ...[
                  if (j > i) const SizedBox(width: 10),
                  Expanded(
                    child: j < styles.length
                        ? TimeUpCard(
                            key: ValueKey(styles[j]),
                            style: styles[j],
                            look: settings.look,
                            roundMinutes: settings.roundMinutes,
                            selected: styles[j] == chosen,
                            onTap: custom
                                ? () => settings.timeUpStyle = styles[j]
                                : () {},
                          )
                        : const SizedBox(),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

/// La miniatura de un aviso. Solo se anima al tocarla, una vez: Ajustes no
/// gasta batería mientras está abierto.
class TimeUpCard extends StatefulWidget {
  const TimeUpCard({
    super.key,
    required this.style,
    required this.look,
    required this.selected,
    required this.onTap,
    this.roundMinutes,
  });

  final TimeUpStyle style;
  final Look look;
  final bool selected;
  final VoidCallback onTap;

  /// La duración de la ronda de Ajustes, para los avisos que la enseñan.
  final int? roundMinutes;

  @override
  State<TimeUpCard> createState() => _TimeUpCardState();
}

class _TimeUpCardState extends State<TimeUpCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: TimeUpOverlay.duration,
  )..addStatusListener((_) => setState(() {}));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _tap() {
    widget.onTap();
    _c.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style;
    final community = style.skinId == null
        ? null
        : [...Skin.presets].where((s) => s.id == style.skinId).firstOrNull;
    return Semantics(
      button: true,
      selected: widget.selected,
      label: 'Aviso de fin de ronda: ${style.label}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: _tap,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: widget.selected ? kAccent : const Color(0x22FFFFFF),
                  width: widget.selected ? 2.5 : 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: ColoredBox(
                    color: const Color(0xFF16161A),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        AnimatedBuilder(
                          animation: _c,
                          builder: (context, _) => TimeUpScene(
                            style: style,
                            t: _c.isAnimating ? _c.value : TimeUpScene.still,
                            look: widget.look,
                            lives: (20, 17),
                            roundMinutes: widget.roundMinutes,
                          ),
                        ),
                        if (!_c.isAnimating)
                          const Positioned(
                            right: 6,
                            bottom: 6,
                            child: Icon(
                              Icons.play_circle_fill,
                              size: 22,
                              color: Color(0xCCFFFFFF),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              style.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: widget.selected ? Colors.white : kMutedText,
                fontSize: 13.5,
                fontWeight: widget.selected ? FontWeight.w600 : null,
              ),
            ),
            if (community != null)
              Text(
                'De ${community.name}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: kAccent, fontSize: 11.5),
              ),
          ],
        ),
      ),
    );
  }
}
