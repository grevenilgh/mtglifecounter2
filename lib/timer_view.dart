import 'package:flutter/material.dart';
import 'package:mtglifecounter/app_settings.dart';
import 'package:mtglifecounter/hold_to_repeat.dart';
import 'package:mtglifecounter/look.dart';
import 'package:mtglifecounter/round_timer.dart';
import 'package:mtglifecounter/settings_page.dart';

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
    backgroundColor: kCardColor,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => ListenableBuilder(
      listenable: Listenable.merge([timer, settings]),
      builder: (context, _) {
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
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Se puede cambiar de modo en cualquier momento: el tiempo que
                // lleva la partida se mantiene.
                SegmentedButton<TimerMode>(
                  segments: const [
                    ButtonSegment(
                      value: TimerMode.countdown,
                      icon: Icon(Icons.hourglass_bottom),
                      label: Text('Cuenta atrás'),
                    ),
                    ButtonSegment(
                      value: TimerMode.stopwatch,
                      icon: Icon(Icons.timer_outlined),
                      label: Text('Cronómetro'),
                    ),
                  ],
                  selected: {settings.timerMode},
                  showSelectedIcon: false,
                  onSelectionChanged: (modes) =>
                      settings.timerMode = modes.first,
                  style: SegmentedButton.styleFrom(
                    foregroundColor: Colors.white,
                    selectedForegroundColor: const Color(0xFF1A1306),
                    selectedBackgroundColor: kAccent,
                    side: const BorderSide(color: Color(0x40FFFFFF)),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  countdown ? 'Tiempo de ronda' : 'Tiempo de partida',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                // Con lo que se pasan puede ser «−1:02:03»: se encoge para
                // caber en los móviles estrechos.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    timerLabel(timer),
                    style: TextStyle(
                      color: finished
                          ? const Color(0xFFF87171)
                          : warning
                          ? const Color(0xFFFBBF24)
                          : Colors.white,
                      fontSize: 84,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                      fontFeatures: kNumberFeatures,
                    ),
                  ),
                ),
                Text(
                  state,
                  style: const TextStyle(color: kMutedText, fontSize: 14),
                ),
                if (countdown && !timer.started) ...[
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Builder(
                        builder: (context) {
                          final step =
                              settings.roundMinutes >
                                  AppSettings.minRoundMinutes
                              ? () => settings.roundMinutes -= 1
                              : null;
                          return HoldToRepeat(
                            onStep: step,
                            label: 'Un minuto menos',
                            child: IconButton.filledTonal(
                              onPressed: step,
                              icon: const Icon(Icons.remove),
                            ),
                          );
                        },
                      ),
                      SizedBox(
                        width: 110,
                        child: Text(
                          '${settings.roundMinutes} min',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Builder(
                        builder: (context) {
                          final step =
                              settings.roundMinutes <
                                  AppSettings.maxRoundMinutes
                              ? () => settings.roundMinutes += 1
                              : null;
                          return HoldToRepeat(
                            onStep: step,
                            label: 'Un minuto más',
                            child: IconButton.filledTonal(
                              onPressed: step,
                              icon: const Icon(Icons.add),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: timer.started ? timer.reset : null,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(50),
                        ),
                        child: const Text('Reiniciar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: timer.running ? timer.pause : timer.start,
                        style: FilledButton.styleFrom(
                          backgroundColor: kAccent,
                          foregroundColor: const Color(0xFF1A1306),
                          minimumSize: const Size.fromHeight(50),
                        ),
                        child: Text(
                          timer.running
                              ? 'Pausar'
                              : timer.started
                              ? 'Reanudar'
                              : 'Iniciar',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
