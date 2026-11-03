import 'package:flutter/material.dart';
import 'package:mtglifecounter/app_settings.dart';
import 'package:mtglifecounter/chess_clock.dart';
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
        // En el reloj de ajedrez la barra enseña lo que les queda entre los
        // dos y se pone roja cuando se les ha acabado a los dos, pero no se
        // para ni parpadea: cada uno sigue con su botón.
        final chess = timer.chess;
        final finished = chess
            ? timer.started && timer.totalLeft <= Duration.zero
            : timer.finished;
        final warning = widget.warningEnabled && timer.warning;
        final paused = !timer.running && timer.started && !finished;
        if (finished && !chess && !_blink.isAnimating) {
          _blink.repeat(reverse: true);
        } else if ((!finished || chess) && _blink.isAnimating) {
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
          // la barra. En pausa sigue igual, con el icono de pausa: solo con
          // el contorno parecía que se había perdido el botón.
          background = kManaGray;
          foreground = kManaInk;
        } else {
          background = paused
              ? Colors.transparent
              : Colors.white.withValues(alpha: 0.1);
          foreground = Colors.white;
        }
        final label = chess
            ? formatSignedClock(timer.totalLeft)
            : finished
            ? 'Tiempo'
            : formatClock(timer.shown);
        return Semantics(
          button: true,
          label: switch (timer.mode) {
            TimerMode.countdown => 'Temporizador de ronda: $label',
            TimerMode.stopwatch => 'Cronómetro: $label',
            TimerMode.chess => 'Reloj de ajedrez, lo que queda: $label',
          },
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
                  border: paused && !classic
                      ? Border.all(
                          color: foreground.withValues(alpha: 0.6),
                          width: 1.5,
                        )
                      : null,
                  boxShadow: classic
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
                    if (paused)
                      Icon(Icons.pause_rounded, size: 18, color: foreground)
                    else if (chess)
                      ChessClockIcon(color: foreground, size: 18)
                    else
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

/// Cambia el modo del reloj de esta partida. Entrar o salir del reloj de
/// ajedrez con el reloj empezado mezclaría los tiempos (lo gastado no es de
/// ningún jugador), así que antes pregunta si se reinicia.
Future<void> pickTimerMode(
  BuildContext context, {
  required RoundTimer timer,
  required TimerMode mode,
}) async {
  final crossesChess = (mode == TimerMode.chess) != timer.chess;
  if (!crossesChess || !timer.started) {
    timer.mode = mode;
    return;
  }
  final toChess = mode == TimerMode.chess;
  final accepted = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: kCardColor,
      title: Text(
        toChess ? 'Pasar al reloj de ajedrez' : 'Salir del reloj de ajedrez',
        style: const TextStyle(color: Colors.white),
      ),
      content: Text(
        toChess
            ? 'El reloj ya ha empezado. Para repartir el tiempo entre los '
                  'dos hay que reiniciarlo.'
            : 'El reloj de ajedrez ya ha empezado. Para cambiar de modo hay '
                  'que reiniciarlo.',
        style: const TextStyle(color: kMutedText),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          style: TextButton.styleFrom(foregroundColor: Colors.white),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: TextButton.styleFrom(foregroundColor: kAccent),
          child: const Text('Reiniciar y cambiar'),
        ),
      ],
    ),
  );
  if (accepted != true) return;
  timer.reset();
  timer.mode = mode;
}

/// El panel del temporizador: tiempo grande, iniciar o pausar y reiniciar.
/// Antes de empezar, la cuenta atrás y el reloj de ajedrez dejan cambiar la
/// duración. En el reloj de ajedrez enseña además lo de cada jugador.
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
        final mode = timer.mode;
        final chess = timer.chess;
        final finished = chess
            ? timer.started && timer.totalLeft <= Duration.zero
            : timer.finished;
        final warning = settings.timerWarning && timer.warning;
        final turn = timer.turn;
        final state = chess && turn == null
            ? 'Pulsa el botón de quien no empieza'
            : timer.running && chess
            ? 'En marcha · le toca al de ${turn == Seat.top ? 'arriba' : 'abajo'}'
            : timer.running
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
                // El modo de esta partida. «Ajedrez» solo sale si está
                // activado en Ajustes (o si el reloj ya va así). Entre cuenta
                // atrás y cronómetro se cambia sin perder el tiempo que lleva;
                // entrar o salir del de ajedrez lo reinicia (pregunta antes).
                Builder(
                  builder: (context) {
                    final modes = [
                      TimerMode.countdown,
                      TimerMode.stopwatch,
                      if (settings.chessEnabled || chess) TimerMode.chess,
                    ];
                    // Con tres no caben los iconos en un móvil estrecho.
                    final icons = modes.length == 2;
                    return SegmentedButton<TimerMode>(
                      segments: [
                        for (final m in modes)
                          ButtonSegment(
                            value: m,
                            icon: !icons
                                ? null
                                : Icon(
                                    m == TimerMode.countdown
                                        ? Icons.hourglass_bottom
                                        : Icons.timer_outlined,
                                  ),
                            label: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(m.label, maxLines: 1),
                            ),
                          ),
                      ],
                      selected: {mode},
                      showSelectedIcon: false,
                      onSelectionChanged: (picked) => pickTimerMode(
                        context,
                        timer: timer,
                        mode: picked.first,
                      ),
                      style: SegmentedButton.styleFrom(
                        foregroundColor: Colors.white,
                        selectedForegroundColor: const Color(0xFF1A1306),
                        selectedBackgroundColor: kAccent,
                        side: const BorderSide(color: Color(0x40FFFFFF)),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  mode == TimerMode.stopwatch
                      ? 'Tiempo de partida'
                      : 'Tiempo de ronda',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    chess
                        ? formatSignedClock(timer.totalLeft)
                        : formatClock(timer.shown),
                    style: TextStyle(
                      color: finished
                          ? const Color(0xFFF87171)
                          : warning
                          ? const Color(0xFFFBBF24)
                          : Colors.white,
                      fontSize: chess ? 72 : 84,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                      fontFeatures: kNumberFeatures,
                    ),
                  ),
                ),
                Text(
                  state,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: kMutedText, fontSize: 14),
                ),
                if (chess) ...[
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _SeatCard(
                          timer: timer,
                          seat: Seat.top,
                          color: settings.skin.top,
                          warningEnabled: settings.timerWarning,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SeatCard(
                          timer: timer,
                          seat: Seat.bottom,
                          color: settings.skin.bottom,
                          warningEnabled: settings.timerWarning,
                        ),
                      ),
                    ],
                  ),
                ],
                if (mode != TimerMode.stopwatch && !timer.started) ...[
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Builder(
                        builder: (context) {
                          final step =
                              timer.roundLength.inMinutes >
                                  AppSettings.minRoundMinutes
                              ? () => timer.setRoundLength(
                                  timer.roundLength -
                                      const Duration(minutes: 1),
                                )
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
                          '${timer.roundLength.inMinutes} min',
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
                              timer.roundLength.inMinutes <
                                  AppSettings.maxRoundMinutes
                              ? () => timer.setRoundLength(
                                  timer.roundLength +
                                      const Duration(minutes: 1),
                                )
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
                  if (chess)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '${formatClock(timer.share)} para cada uno',
                        style: const TextStyle(color: kMutedText, fontSize: 14),
                      ),
                    ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: timer.started || turn != null
                            ? timer.reset
                            : null,
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
                        // El reloj de ajedrez lo arranca el botón de un
                        // jugador; desde aquí solo se pausa y se reanuda.
                        onPressed:
                            (finished && !chess) || (chess && turn == null)
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

/// Lo de un jugador en la hoja del reloj de ajedrez: lo que le queda y si
/// le toca, espera o se ha pasado.
class _SeatCard extends StatelessWidget {
  const _SeatCard({
    required this.timer,
    required this.seat,
    required this.color,
    required this.warningEnabled,
  });

  final RoundTimer timer;
  final Seat seat;
  final Color color;
  final bool warningEnabled;

  @override
  Widget build(BuildContext context) {
    final turn = timer.turn;
    final mine = turn == seat;
    final over = turn != null && timer.overtime(seat);
    final warn = warningEnabled && mine && timer.warningFor(seat);
    final state = turn == null
        ? 'Preparado'
        : over
        ? 'Se ha pasado'
        : mine
        ? (timer.running ? 'Le toca' : 'Le toca (en pausa)')
        : 'Esperando';
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
      decoration: BoxDecoration(
        color: mine ? const Color(0xFF33302A) : const Color(0xFF2A2928),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: mine ? kAccent : Colors.white.withValues(alpha: 0.08),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  seat == Seat.top ? 'Arriba' : 'Abajo',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: kMutedText, fontSize: 13),
                ),
              ),
            ],
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              formatSignedClock(timer.leftFor(seat)),
              style: TextStyle(
                color: over
                    ? const Color(0xFFF87171)
                    : warn
                    ? const Color(0xFFFBBF24)
                    : Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.w700,
                height: 1.2,
                fontFeatures: kNumberFeatures,
              ),
            ),
          ),
          Text(
            state,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: mine && !over ? kAccent : kMutedText,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
