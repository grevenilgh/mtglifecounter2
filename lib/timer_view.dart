import 'package:flutter/material.dart';
import 'package:mtglifecounter/app_settings.dart';
import 'package:mtglifecounter/hold_to_repeat.dart';
import 'package:mtglifecounter/look.dart';
import 'package:mtglifecounter/round_timer.dart';
import 'package:mtglifecounter/themed_style.dart';

/// El reloj de la barra central. Se pone ámbar a falta de 5 minutos (si el
/// aviso está activado) y rojo al acabar, contando en negativo lo que se
/// pasan.
///
/// No parpadea ni se anima: cambia una vez por segundo y nada más, porque la
/// app pasa el día encendida en la mesa (un parpadeo sin fin la tenía a 60
/// fotogramas por segundo, con la mitad del procesador). Va en su propia capa
/// ([RepaintBoundary]) para que cada segundo se repinte solo el botón y no la
/// pantalla entera.
class TimerButton extends StatelessWidget {
  const TimerButton({
    super.key,
    required this.timer,
    required this.look,
    required this.warningEnabled,
    required this.onTap,
  });

  final RoundTimer timer;
  final Look look;
  final bool warningEnabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final classic = look.isClassic;
    return RepaintBoundary(
      child: ListenableBuilder(
        listenable: timer,
        builder: (context, _) {
          final finished = timer.finished;
          final warning = warningEnabled && timer.warning;
          final paused = !timer.running && timer.started;
          final Color background;
          final Color foreground;
          if (finished) {
            background = const Color(0xFFDC2626);
            foreground = Colors.white;
          } else if (warning) {
            background = const Color(0xFFF59E0B);
            foreground = const Color(0xFF1F1403);
          } else if (classic) {
            // Como un coste de maná genérico, sobre la caja de texto clara de
            // la barra: en pausa, solo el contorno en tinta.
            background = paused ? Colors.transparent : kManaGray;
            foreground = kManaInk;
          } else {
            background = paused
                ? Colors.transparent
                : Colors.white.withValues(alpha: 0.1);
            foreground = Colors.white;
          }
          final label = timerLabel(timer);
          return Semantics(
            button: true,
            label: timer.mode == TimerMode.stopwatch
                ? 'Cronómetro: $label'
                : finished
                ? 'Se acabó el tiempo, pasados ${formatClock(timer.shown)}'
                : 'Temporizador de ronda: $label',
            child: GestureDetector(
              onTap: onTap,
              child: Container(
                height: classic ? kManaPipSize : 36,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(
                    classic ? kManaPipSize / 2 : 12,
                  ),
                  border: paused
                      ? Border.all(
                          color: foreground.withValues(alpha: 0.6),
                          width: 1.5,
                        )
                      : null,
                  boxShadow: classic && !paused
                      ? const [
                          // La sombra de los símbolos de maná.
                          BoxShadow(
                            color: Color(0xFF0B0705),
                            offset: Offset(-1.5, 2.5),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      timer.mode == TimerMode.countdown
                          ? Icons.timer_outlined
                          : Icons.av_timer,
                      size: 17,
                      color: foreground,
                    ),
                    const SizedBox(width: 5),
                    _SteadyLabel(
                      label,
                      style: withFont(
                        classic ? 'Vollkorn' : null,
                        TextStyle(
                          color: foreground,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          fontFeatures: kNumberFeatures,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// El texto del reloj sin mover nada al cambiar cada segundo.
///
/// El tamaño lo da una plantilla invisible con las cifras cambiadas por
/// ceros (que, con cifras tabulares, mide lo mismo), y el texto de verdad va
/// encima con el tamaño ya fijado: así, al cambiar de segundo, solo se vuelve
/// a medir ese texto y no la barra entera, que si no se repintaría con él
/// (y con ella media pantalla). La plantilla solo cambia cuando cambia la
/// forma («9:59» a «10:00», o el menos al acabar).
class _SteadyLabel extends StatelessWidget {
  const _SteadyLabel(this.text, {required this.style});

  final String text;
  final TextStyle style;

  static final RegExp _digit = RegExp(r'\d');

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ExcludeSemantics(
          child: Text(
            text.replaceAll(_digit, '0'),
            style: style.copyWith(color: Colors.transparent),
          ),
        ),
        Positioned.fill(
          child: Text(
            text,
            style: style,
            textAlign: TextAlign.center,
            softWrap: false,
            overflow: TextOverflow.visible,
          ),
        ),
      ],
    );
  }
}

/// El panel del temporizador: tiempo grande, iniciar o pausar y reiniciar.
/// Antes de empezar, la cuenta atrás deja cambiar la duración.
///
/// Va vestido como el tema ([ThemedStyle]): flota sobre la partida como una
/// tarjeta del mismo estilo que los avisos (en el Old Border, una carta con
/// botones de maná).
Future<void> showTimerSheet(
  BuildContext context, {
  required RoundTimer timer,
  required AppSettings settings,
}) {
  // Puede ocupar toda la pantalla y se desplaza: con la altura normal de una
  // hoja (9/16 de la pantalla), en los móviles pequeños los botones de
  // iniciar quedaban fuera.
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    elevation: 0,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => ListenableBuilder(
      listenable: Listenable.merge([timer, settings]),
      builder: (context, _) => _TimerSheet(timer: timer, settings: settings),
    ),
  );
}

class _TimerSheet extends StatelessWidget {
  const _TimerSheet({required this.timer, required this.settings});

  final RoundTimer timer;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final style = ThemedStyle.of(settings.look, settings.skin);
    final countdown = timer.mode == TimerMode.countdown;
    final finished = timer.finished;
    final warning = settings.timerWarning && timer.warning;
    final state = finished
        ? timer.running
              ? 'Se acabó el tiempo: lo que os habéis pasado'
              : 'Se acabó el tiempo (en pausa)'
        : timer.running
        ? 'En marcha'
        : timer.started
        ? 'En pausa'
        : 'Preparado para empezar';
    final less = settings.roundMinutes > AppSettings.minRoundMinutes
        ? () => settings.roundMinutes -= 1
        : null;
    final more = settings.roundMinutes < AppSettings.maxRoundMinutes
        ? () => settings.roundMinutes += 1
        : null;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Material(
              type: MaterialType.transparency,
              child: style.frame(
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Se puede cambiar de modo en cualquier momento: el
                    // tiempo que lleva la partida se mantiene.
                    style.selector<TimerMode>(
                      options: const [
                        (
                          TimerMode.countdown,
                          Icons.hourglass_bottom,
                          'Cuenta atrás',
                        ),
                        (
                          TimerMode.stopwatch,
                          Icons.timer_outlined,
                          'Cronómetro',
                        ),
                      ],
                      selected: settings.timerMode,
                      onSelected: (mode) => settings.timerMode = mode,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      countdown ? 'Tiempo de ronda' : 'Tiempo de partida',
                      textAlign: TextAlign.center,
                      style: style.titleStyle,
                    ),
                    const SizedBox(height: 4),
                    // Con lo que se pasan puede ser «−1:02:03»: se encoge
                    // para caber en los móviles estrechos.
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        timerLabel(timer),
                        style: style.numberStyle(
                          84,
                          finished
                              ? style.dangerInk
                              : warning
                              ? style.warnInk
                              : style.ink,
                        ),
                      ),
                    ),
                    Text(
                      state,
                      textAlign: TextAlign.center,
                      style: style.bodyStyle.copyWith(fontSize: 14),
                    ),
                    if (countdown && !timer.started) ...[
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          HoldToRepeat(
                            onStep: less,
                            label: 'Un minuto menos',
                            child: style.roundButton(Icons.remove, onTap: less),
                          ),
                          SizedBox(
                            width: 110,
                            child: Text(
                              '${settings.roundMinutes} min',
                              textAlign: TextAlign.center,
                              style: style.titleStyle.copyWith(fontSize: 19),
                            ),
                          ),
                          HoldToRepeat(
                            onStep: more,
                            label: 'Un minuto más',
                            child: style.roundButton(Icons.add, onTap: more),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: style.button(
                            'Reiniciar',
                            kind: ButtonKind.plain,
                            onTap: timer.started ? timer.reset : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: style.button(
                            timer.running
                                ? 'Pausar'
                                : timer.started
                                ? 'Reanudar'
                                : 'Iniciar',
                            kind: ButtonKind.accent,
                            onTap: timer.running ? timer.pause : timer.start,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
