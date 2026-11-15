import 'package:flutter/material.dart';
import 'package:mtglifecounter/app_settings.dart';
import 'package:mtglifecounter/chess_clock.dart';
import 'package:mtglifecounter/hold_to_repeat.dart';
import 'package:mtglifecounter/look.dart';
import 'package:mtglifecounter/round_timer.dart';
import 'package:mtglifecounter/themed_dialog.dart';
import 'package:mtglifecounter/themed_style.dart';

/// El reloj de la barra central. Se pone ámbar a falta de 5 minutos (si el
/// aviso está activado) y rojo al acabar, parado en 0:00. En el reloj de
/// ajedrez enseña lo que les queda entre los dos.
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
          // En el reloj de ajedrez la barra se pone roja cuando se les ha
          // acabado a los dos.
          final chess = timer.chess;
          final finished = chess
              ? timer.started && timer.totalLeft == Duration.zero
              : timer.finished;
          final warning = warningEnabled && timer.warning;
          // Parado por haberse acabado el tiempo no es una pausa: sin el
          // icono de pausa.
          final paused =
              !timer.running &&
              timer.started &&
              !finished &&
              !timer.waitingForPress;
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
          final label = timerLabel(timer);
          return Semantics(
            button: true,
            label: switch (timer.mode) {
              TimerMode.stopwatch => 'Cronómetro: $label',
              TimerMode.chess => 'Reloj de ajedrez, lo que queda: $label',
              TimerMode.countdown when finished => 'Se acabó el tiempo',
              TimerMode.countdown => 'Temporizador de ronda: $label',
            },
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

/// Cambia el modo del reloj de esta partida. Entrar o salir del reloj de
/// ajedrez con el reloj empezado mezclaría los tiempos (lo gastado no es de
/// ningún jugador), así que antes pregunta si se reinicia, con el aviso del
/// tema ([showThemedConfirm]).
Future<void> pickTimerMode(
  BuildContext context, {
  required RoundTimer timer,
  required AppSettings settings,
  required TimerMode mode,
}) async {
  final crossesChess = (mode == TimerMode.chess) != timer.chess;
  if (!crossesChess || !timer.started) {
    timer.mode = mode;
    return;
  }
  final toChess = mode == TimerMode.chess;
  final accepted = await showThemedConfirm(
    context,
    settings: settings,
    icon: Icons.restart_alt,
    title: toChess
        ? '¿Pasar al reloj de ajedrez?'
        : '¿Salir del reloj de ajedrez?',
    message: toChess
        ? 'El reloj ya ha empezado. Para repartir el tiempo entre los dos hay '
              'que reiniciarlo.'
        : 'El reloj de ajedrez ya ha empezado. Para cambiar de modo hay que '
              'reiniciarlo.',
    confirmLabel: 'Reiniciar y cambiar',
    destructive: true,
  );
  if (!accepted) return;
  timer.reset();
  timer.mode = mode;
}

/// El panel del temporizador: tiempo grande, iniciar o pausar y reiniciar.
/// Antes de empezar, la cuenta atrás y el reloj de ajedrez dejan cambiar la
/// duración. En el reloj de ajedrez enseña además lo de cada jugador.
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
    final mode = timer.mode;
    final chess = timer.chess;
    final finished = chess
        ? timer.started && timer.totalLeft == Duration.zero
        : timer.finished;
    final warning = settings.timerWarning && timer.warning;
    final turn = timer.turn;
    final whose = turn == Seat.top ? 'arriba' : 'abajo';
    final state = chess && turn == null
        ? 'Pulsa el botón de quien no empieza'
        : finished
        ? 'Se acabó el tiempo'
        : timer.waitingForPress
        ? 'Al de $whose se le ha acabado: que pase el turno'
        : timer.running && chess
        ? 'En marcha · le toca al de $whose'
        : timer.running
        ? 'En marcha'
        : timer.started
        ? 'En pausa'
        : 'Preparado para empezar';
    // La duración de esta ronda (no la de Ajustes), antes de empezar.
    void setLength(int minutes) =>
        timer.setRoundLength(Duration(minutes: minutes));
    final minutes = timer.roundLength.inMinutes;
    final less = minutes > AppSettings.minRoundMinutes
        ? () => setLength(minutes - 1)
        : null;
    final more = minutes < AppSettings.maxRoundMinutes
        ? () => setLength(minutes + 1)
        : null;
    // «Ajedrez» solo sale si está activado en Ajustes (o si el reloj ya va
    // así). Con tres no caben los iconos en un móvil estrecho.
    final modes = [
      TimerMode.countdown,
      TimerMode.stopwatch,
      if (settings.chessEnabled || chess) TimerMode.chess,
    ];
    final icons = modes.length == 2;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Material(
              type: MaterialType.transparency,
              child: style.frame(
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // El modo de esta partida. Entre cuenta atrás y
                    // cronómetro se cambia sin perder el tiempo que lleva;
                    // entrar o salir del de ajedrez lo reinicia (pregunta
                    // antes).
                    style.selector<TimerMode>(
                      options: [
                        for (final m in modes)
                          (
                            m,
                            !icons
                                ? null
                                : m == TimerMode.countdown
                                ? Icons.hourglass_bottom
                                : Icons.timer_outlined,
                            m.label,
                          ),
                      ],
                      selected: mode,
                      onSelected: (picked) => pickTimerMode(
                        context,
                        timer: timer,
                        settings: settings,
                        mode: picked,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      mode == TimerMode.stopwatch
                          ? 'Tiempo de partida'
                          : 'Tiempo de ronda',
                      textAlign: TextAlign.center,
                      style: style.titleStyle,
                    ),
                    const SizedBox(height: 4),
                    // El cronómetro puede pasar de la hora («1:02:03»): se
                    // encoge para caber en los móviles estrechos.
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        timerLabel(timer),
                        style: style.numberStyle(
                          chess ? 72 : 84,
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
                              style: style,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _SeatCard(
                              timer: timer,
                              seat: Seat.bottom,
                              color: settings.skin.bottom,
                              warningEnabled: settings.timerWarning,
                              style: style,
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
                          HoldToRepeat(
                            onStep: less,
                            label: 'Un minuto menos',
                            child: style.roundButton(Icons.remove, onTap: less),
                          ),
                          SizedBox(
                            width: 110,
                            child: Text(
                              '$minutes min',
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
                      if (chess)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            '${formatClock(timer.share)} para cada uno',
                            textAlign: TextAlign.center,
                            style: style.bodyStyle.copyWith(fontSize: 14),
                          ),
                        ),
                    ],
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: style.button(
                            'Reiniciar',
                            kind: ButtonKind.plain,
                            onTap: timer.started || turn != null
                                ? timer.reset
                                : null,
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
                            // El reloj de ajedrez lo arranca el botón de un
                            // jugador; desde aquí solo se pausa y se reanuda.
                            // Acabado el tiempo, solo se reinicia.
                            onTap: timer.running
                                ? timer.pause
                                : timer.canStart
                                ? timer.start
                                : null,
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

/// Lo de un jugador en la hoja del reloj de ajedrez: lo que le queda y si
/// le toca, espera o se ha quedado sin tiempo. Con los colores del tema; el que tiene el
/// turno, resaltado con el color de lo principal.
class _SeatCard extends StatelessWidget {
  const _SeatCard({
    required this.timer,
    required this.seat,
    required this.color,
    required this.warningEnabled,
    required this.style,
  });

  final RoundTimer timer;
  final Seat seat;
  final Color color;
  final bool warningEnabled;
  final ThemedStyle style;

  @override
  Widget build(BuildContext context) {
    final classic = style.look.isClassic;
    final turn = timer.turn;
    final mine = turn == seat;
    final over = turn != null && timer.outOfTime(seat);
    final warn = warningEnabled && mine && timer.warningFor(seat);
    final state = turn == null
        ? 'Preparado'
        : over
        ? 'Sin tiempo'
        : mine
        ? (timer.running ? 'Le toca' : 'Le toca (en pausa)')
        : 'Esperando';
    final ink = classic ? kInk : Colors.white;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
      decoration: BoxDecoration(
        color: classic
            ? Colors.black.withValues(alpha: mine ? 0.1 : 0.04)
            : Colors.white.withValues(alpha: mine ? 0.12 : 0.05),
        borderRadius: BorderRadius.circular(classic ? 10 : 16),
        border: Border.all(
          color: mine
              ? style.accent
              : (classic ? const Color(0x33000000) : const Color(0x14FFFFFF)),
          width: mine ? 2 : 1.5,
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
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: classic ? Border.all(color: kInk) : null,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  seat == Seat.top ? 'Arriba' : 'Abajo',
                  overflow: TextOverflow.ellipsis,
                  style: style.bodyStyle.copyWith(
                    fontSize: 13,
                    color: style.muted,
                  ),
                ),
              ),
            ],
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              formatClock(timer.leftFor(seat)),
              style: style.numberStyle(
                34,
                over
                    ? style.dangerInk
                    : warn
                    ? style.warnInk
                    : ink,
              ),
            ),
          ),
          Text(
            state,
            textAlign: TextAlign.center,
            style: style.bodyStyle.copyWith(
              fontSize: 13,
              color: mine && !over ? ink : style.muted,
              fontWeight: mine && !over ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
