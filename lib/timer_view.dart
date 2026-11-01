import 'package:flutter/material.dart';
import 'package:mtglifecounter/app_settings.dart';
import 'package:mtglifecounter/hold_to_repeat.dart';
import 'package:mtglifecounter/look.dart';
import 'package:mtglifecounter/round_timer.dart';
import 'package:mtglifecounter/settings_page.dart';

/// El reloj de la barra central. Se pone ámbar a falta de 5 minutos (si el
/// aviso está activado) y rojo parpadeando al acabar.
class TimerButton extends StatefulWidget {
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
  State<TimerButton> createState() => _TimerButtonState();
}

class _TimerButtonState extends State<TimerButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _blink = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timer = widget.timer;
    final classic = widget.look.isClassic;
    return ListenableBuilder(
      listenable: timer,
      builder: (context, _) {
        final finished = timer.finished;
        final warning = widget.warningEnabled && timer.warning;
        final paused = !timer.running && timer.started && !finished;
        if (finished && !_blink.isAnimating) {
          _blink.repeat(reverse: true);
        } else if (!finished && _blink.isAnimating) {
          _blink.stop();
          _blink.value = 0;
        }
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
        final label = finished ? 'Tiempo' : formatClock(timer.shown);
        return Semantics(
          button: true,
          label: timer.mode == TimerMode.countdown
              ? 'Temporizador de ronda: $label'
              : 'Cronómetro: $label',
          child: GestureDetector(
            onTap: widget.onTap,
            child: FadeTransition(
              opacity: Tween<double>(begin: 1, end: 0.55).animate(_blink),
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
                    Text(
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
          ),
        );
      },
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
        final state = timer.running
            ? 'En marcha'
            : finished
            ? 'Se acabó el tiempo'
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
                Text(
                  formatClock(timer.shown),
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
                        onPressed: finished
                            ? null
                            : timer.running
                            ? timer.pause
                            : timer.start,
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
