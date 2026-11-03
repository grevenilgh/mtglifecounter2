// Pruebas del reloj de ajedrez: el modelo (RoundTimer en modo ajedrez), los
// ajustes (el interruptor y el modo por defecto), los botones de cada panel,
// la barra, la hoja del reloj y la vibración, dentro de la app de verdad.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtglifecounter/app_settings.dart';
import 'package:mtglifecounter/chess_clock.dart';
import 'package:mtglifecounter/game_state.dart';
import 'package:mtglifecounter/look.dart';
import 'package:mtglifecounter/main.dart';
import 'package:mtglifecounter/player_counter.dart';
import 'package:mtglifecounter/round_timer.dart';
import 'package:mtglifecounter/timer_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  useGoogleFonts = false;

  late DateTime now;
  late SharedPreferences prefs;
  // Lo que se ha pedido vibrar, en milisegundos.
  late List<int> vibrations;

  setUp(() async {
    now = DateTime(2026, 11, 4, 18);
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    vibrations = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('mtglifecounter/vibrate'),
          (call) async {
            vibrations.add(call.arguments as int);
            return null;
          },
        );
  });

  RoundTimer newTimer({
    TimerMode mode = TimerMode.countdown,
    int minutes = 50,
  }) => RoundTimer(
    prefs,
    mode: mode,
    roundLength: Duration(minutes: minutes),
    clock: () => now,
  );

  group('RoundTimer en modo ajedrez', () {
    test('formatSignedClock', () {
      expect(formatSignedClock(Duration.zero), '0:00');
      expect(formatSignedClock(const Duration(minutes: 1, seconds: 5)), '1:05');
      // Nada más pasarse ya sale en negativo.
      expect(formatSignedClock(const Duration(milliseconds: -400)), '−0:01');
      expect(formatSignedClock(const Duration(seconds: -42)), '−0:42');
      expect(
        formatSignedClock(const Duration(hours: -1, seconds: -1)),
        '−1:00:01',
      );
    });

    test('el aviso de cambio de modo no salta con cada segundo', () {
      final timer = newTimer(mode: TimerMode.chess);
      addTearDown(timer.dispose);
      var changes = 0;
      timer.modeListenable.addListener(() => changes++);
      timer.press(Seat.top);
      now = now.add(const Duration(minutes: 1));
      timer.press(Seat.bottom);
      expect(changes, 0);

      timer.mode = TimerMode.chess; // el mismo: nada
      expect(changes, 0);
      timer.setDefaults(TimerMode.countdown, const Duration(minutes: 50));
      timer.reset(); // vuelve a la cuenta atrás
      expect(changes, 1);
      expect(timer.modeListenable.value, TimerMode.countdown);
    });

    test('si lo de Ajustes no cambia, no pisa lo elegido en la hoja', () {
      final timer = newTimer();
      addTearDown(timer.dispose);
      timer.mode = TimerMode.stopwatch; // en la hoja, sin empezar
      timer.setDefaults(TimerMode.countdown, const Duration(minutes: 50));
      expect(timer.mode, TimerMode.stopwatch);
    });

    test(
      'la duración de la hoja se guarda y al reiniciar vuelve a Ajustes',
      () {
        final timer = newTimer(mode: TimerMode.chess);
        addTearDown(timer.dispose);
        timer.setRoundLength(const Duration(minutes: 30));
        final reopened = newTimer(mode: TimerMode.chess);
        addTearDown(reopened.dispose);
        expect(reopened.roundLength, const Duration(minutes: 30));
        expect(reopened.share, const Duration(minutes: 15));
        reopened.reset();
        expect(reopened.roundLength, const Duration(minutes: 50));
      },
    );

    test('con el reloj del móvil atrasado no se devuelve tiempo', () {
      final timer = newTimer(mode: TimerMode.chess)..press(Seat.top);
      addTearDown(timer.dispose);
      now = now.add(const Duration(minutes: 3));
      timer.press(Seat.bottom); // abajo ha gastado 3
      now = now.subtract(const Duration(hours: 1));
      expect(timer.leftFor(Seat.top), const Duration(minutes: 25));
      expect(timer.leftFor(Seat.bottom), const Duration(minutes: 22));
    });

    testWidgets('el aviso de pasarse no se repite al volver a abrir la app', (
      tester,
    ) async {
      var flags = 0;
      final timer = newTimer(mode: TimerMode.chess, minutes: 10)
        ..onFinished = (() => flags++)
        ..press(Seat.top);
      now = now.add(const Duration(minutes: 6));
      await tester.pump(const Duration(seconds: 1));
      expect(flags, 1);
      timer.dispose();

      var again = 0;
      final reopened = newTimer(mode: TimerMode.chess, minutes: 10)
        ..onFinished = () => again++;
      await tester.pump(const Duration(seconds: 2));
      expect(again, 0);
      expect(reopened.overtime(Seat.bottom), isTrue);

      // Tras reiniciar, vuelve a avisar.
      reopened
        ..reset()
        ..press(Seat.top);
      now = now.add(const Duration(minutes: 6));
      await tester.pump(const Duration(seconds: 1));
      expect(again, 1);
      reopened.dispose();
    });

    test('pausar y seguir no cambia el turno ni lo gastado', () {
      final timer = newTimer(mode: TimerMode.chess)..press(Seat.top);
      addTearDown(timer.dispose);
      now = now.add(const Duration(minutes: 2));
      timer
        ..pause()
        ..pause(); // dos veces: nada
      now = now.add(const Duration(minutes: 30));
      timer.start();
      expect(timer.turn, Seat.bottom);
      expect(timer.leftFor(Seat.bottom), const Duration(minutes: 23));
      expect(timer.totalLeft, const Duration(minutes: 48));
    });
  });

  group('Ajustes', () {
    test('el reloj de ajedrez se guarda y viene desactivado', () {
      final settings = AppSettings(prefs);
      expect(settings.chessEnabled, isFalse);
      settings.chessEnabled = true;
      expect(AppSettings(prefs).chessEnabled, isTrue);
    });

    test('quien ya lo tenía por defecto lo tiene activado', () async {
      SharedPreferences.setMockInitialValues({'flutter.timerMode': 'chess'});
      final settings = AppSettings(await SharedPreferences.getInstance());
      expect(settings.chessEnabled, isTrue);
      expect(settings.timerMode, TimerMode.chess);
    });

    test('la barra enseña el reloj solo si el de por defecto es ajedrez', () {
      final settings = AppSettings(prefs)..showTimer = false;
      settings.chessEnabled = true;
      expect(settings.showTimer, isFalse);
      settings.timerMode = TimerMode.chess;
      expect(settings.showTimer, isTrue);
      settings.chessEnabled = false;
      expect(settings.showTimer, isFalse);
    });
  });

  group('En la app', () {
    late AppSettings settings;
    late GameState game;
    late RoundTimer timer;

    Future<void> pumpApp(
      WidgetTester tester, {
      AppTheme theme = AppTheme.original,
      void Function()? before,
    }) async {
      await tester.binding.setSurfaceSize(const Size(412, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      settings = AppSettings(prefs)..theme = theme;
      game = GameState();
      before?.call();
      timer = RoundTimer(
        prefs,
        mode: settings.timerMode,
        roundLength: Duration(minutes: settings.roundMinutes),
        clock: () => now,
      );
      await tester.pumpWidget(
        MyApp(
          settings: settings,
          game: game,
          storage: GameStorage(prefs, game),
          timer: timer,
        ),
      );
      await tester.pump();
    }

    Future<void> close(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
      timer.dispose();
    }

    void enableChess() {
      settings
        ..chessEnabled = true
        ..timerMode = TimerMode.chess;
    }

    Finder clockOf(int panel) => find.descendant(
      of: find.byType(PlayerCounter).at(panel),
      matching: find.byType(ChessClockButton),
    );

    testWidgets('desactivado no hay botones', (tester) async {
      await pumpApp(tester);
      expect(find.byType(ChessClockButton), findsNothing);
      expect(find.byType(ChessClockIcon), findsNothing);
      await close(tester);
    });

    testWidgets('activado, cada panel tiene su botón y la barra el total', (
      tester,
    ) async {
      await pumpApp(tester, before: enableChess);
      expect(find.byType(ChessClockButton), findsNWidgets(2));
      final bar = find.byType(TimerButton);
      expect(
        find.descendant(of: bar, matching: find.byType(ChessClockIcon)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: bar, matching: find.text('50:00')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: clockOf(0), matching: find.text('25:00')),
        findsOneWidget,
      );
      await close(tester);
    });

    testWidgets('pulsar vibra; el botón del que espera no hace nada', (
      tester,
    ) async {
      await pumpApp(tester, before: enableChess);
      await tester.tap(clockOf(0));
      await tester.pump();
      expect(timer.turn, Seat.bottom);
      expect(vibrations, [90]);

      await tester.tap(clockOf(0)); // ya no tiene el turno
      await tester.pump();
      expect(vibrations, [90]);

      now = now.add(const Duration(minutes: 4));
      await tester.pump(const Duration(seconds: 1));
      expect(
        find.descendant(of: clockOf(1), matching: find.text('21:00')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(TimerButton),
          matching: find.text('46:00'),
        ),
        findsOneWidget,
      );
      await close(tester);
    });

    testWidgets('sin «Vibrar» no vibra', (tester) async {
      await pumpApp(
        tester,
        before: () {
          enableChess();
          settings.timerVibrate = false;
        },
      );
      await tester.tap(clockOf(1));
      await tester.pump();
      expect(timer.turn, Seat.top);
      expect(vibrations, isEmpty);
      await close(tester);
    });

    testWidgets('al pasarse vibra tres veces y sale en rojo y en negativo', (
      tester,
    ) async {
      await pumpApp(tester, before: enableChess);
      await tester.tap(clockOf(0));
      await tester.pump();
      vibrations.clear();
      now = now.add(const Duration(minutes: 25, seconds: 42));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 2));
      expect(vibrations, [300, 300, 300]);
      expect(
        find.descendant(of: clockOf(1), matching: find.text('−0:42')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: clockOf(1),
          matching: find.byIcon(Icons.flag_rounded),
        ),
        findsOneWidget,
      );
      // Sigue contando.
      now = now.add(const Duration(seconds: 10));
      await tester.pump(const Duration(seconds: 1));
      expect(
        find.descendant(of: clockOf(1), matching: find.text('−0:52')),
        findsOneWidget,
      );
      await close(tester);
    });

    testWidgets('reiniciar la partida no toca el reloj', (tester) async {
      await pumpApp(tester, before: enableChess);
      await tester.tap(clockOf(0));
      await tester.pump();
      game.bottom
        ..change(-5)
        ..commit();
      await tester.tap(find.byTooltip('Reiniciar partida'));
      await settle(tester);
      await tester.tap(find.text('Aceptar'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(game.bottom.life, 20);
      expect(timer.turn, Seat.bottom);
      expect(timer.running, isTrue);
      expect(find.byType(ChessClockButton), findsNWidgets(2));
      await close(tester);
    });

    testWidgets('al volver a abrir la app sigue el reloj de ajedrez', (
      tester,
    ) async {
      await pumpApp(tester, before: enableChess);
      await tester.tap(clockOf(1));
      await tester.pump();
      now = now.add(const Duration(minutes: 3));
      await close(tester);

      await pumpApp(tester);
      expect(timer.chess, isTrue);
      expect(timer.turn, Seat.top);
      expect(find.byType(ChessClockButton), findsNWidgets(2));
      expect(
        find.descendant(of: clockOf(0), matching: find.text('22:00')),
        findsOneWidget,
      );
      await close(tester);
    });

    testWidgets('un reloj de ajedrez sin la función activada se reinicia', (
      tester,
    ) async {
      // Quedó así de antes, pero en Ajustes no está activado.
      newTimer(mode: TimerMode.chess)
        ..press(Seat.top)
        ..dispose();
      await pumpApp(tester);
      expect(timer.chess, isFalse);
      expect(timer.started, isFalse);
      expect(find.byType(ChessClockButton), findsNothing);
      await close(tester);
    });

    testWidgets('quitarlo en Ajustes quita los botones y reinicia el reloj', (
      tester,
    ) async {
      await pumpApp(tester, before: enableChess);
      await tester.tap(clockOf(0));
      await tester.pump();
      settings.chessEnabled = false;
      await tester.pump();
      expect(settings.timerMode, TimerMode.countdown);
      expect(timer.chess, isFalse);
      expect(timer.started, isFalse);
      expect(find.byType(ChessClockButton), findsNothing);
      await close(tester);
    });

    testWidgets('en el Old Border, el reloj de arena del que espera se tumba', (
      tester,
    ) async {
      await pumpApp(tester, theme: AppTheme.classic, before: enableChess);
      double turns(int panel) => tester
          .widget<AnimatedRotation>(
            find.descendant(
              of: clockOf(panel),
              matching: find.byType(AnimatedRotation),
            ),
          )
          .turns;
      expect(turns(0), 0);
      expect(turns(1), 0);
      await tester.tap(clockOf(0));
      await tester.pump(const Duration(milliseconds: 400));
      expect(turns(0), 0.25); // arriba espera
      expect(turns(1), 0); // abajo le toca

      // En pausa se tumban los dos.
      timer.pause();
      await tester.pump(const Duration(milliseconds: 400));
      expect(turns(1), 0.25);
      await close(tester);
    });

    testWidgets('en el Old Border, el reloj de la barra en pausa sigue siendo '
        'la pastilla de maná', (tester) async {
      await pumpApp(tester, theme: AppTheme.classic);
      timer.start();
      now = now.add(const Duration(minutes: 5));
      timer.pause();
      await tester.pump();
      final bar = find.byType(TimerButton);
      final pill = tester.widget<Container>(
        find.descendant(of: bar, matching: find.byType(Container)).first,
      );
      expect((pill.decoration! as BoxDecoration).color, kManaGray);
      expect(
        find.descendant(of: bar, matching: find.byIcon(Icons.pause_rounded)),
        findsOneWidget,
      );
      await close(tester);
    });

    testWidgets('la esquina del botón no suma ni resta, sin historial', (
      tester,
    ) async {
      await pumpApp(
        tester,
        before: () {
          enableChess();
          settings.showHistory = false;
        },
      );
      final rect = tester.getRect(clockOf(1));
      // Justo al lado del botón, dentro de su esquina.
      await tester.longPressAt(rect.centerLeft - const Offset(4, 0));
      await tester.pump(const Duration(seconds: 1));
      expect(game.bottom.life, 20);
      await close(tester);
    });

    group('Ajustes', () {
      Future<void> openGameSettings(WidgetTester tester) async {
        await tester.tap(find.byTooltip('Ajustes'));
        await settle(tester);
        await tester.tap(find.text('Partida'));
        await settle(tester);
      }

      testWidgets('Ajedrez solo sale con el interruptor y llega sin empezar', (
        tester,
      ) async {
        await pumpApp(tester);
        await openGameSettings(tester);
        expect(find.text('Reloj de ajedrez'), findsOneWidget);
        expect(find.text('Ajedrez'), findsNothing);

        await tester.tap(find.text('Reloj de ajedrez'));
        await settle(tester);
        expect(settings.chessEnabled, isTrue);
        await tester.tap(find.text('Ajedrez'));
        await settle(tester);
        expect(settings.timerMode, TimerMode.chess);
        // El reloj no había empezado: le llega al momento.
        expect(timer.chess, isTrue);
        await close(tester);
      });

      testWidgets('con el reloj empezado, el de por defecto no lo toca', (
        tester,
      ) async {
        await pumpApp(tester);
        timer.start();
        now = now.add(const Duration(minutes: 5));
        await openGameSettings(tester);
        await tester.tap(find.text('Cronómetro'));
        await settle(tester);
        expect(settings.timerMode, TimerMode.stopwatch);
        expect(timer.mode, TimerMode.countdown);
        expect(timer.running, isTrue);
        expect(
          find.textContaining('La partida de ahora sigue con Cuenta atrás'),
          findsOneWidget,
        );
        await close(tester);
      });

      testWidgets('quitarlo con el de ajedrez empezado pregunta antes', (
        tester,
      ) async {
        await pumpApp(tester, before: enableChess);
        await tester.tap(clockOf(0));
        await tester.pump();
        await openGameSettings(tester);

        await tester.tap(find.text('Reloj de ajedrez'));
        await settle(tester);
        expect(find.text('Quitar el reloj de ajedrez'), findsOneWidget);
        await tester.tap(find.text('Cancelar'));
        await settle(tester);
        expect(settings.chessEnabled, isTrue);
        expect(timer.turn, Seat.bottom);

        await tester.tap(find.text('Reloj de ajedrez'));
        await settle(tester);
        await tester.tap(find.text('Quitar y reiniciar'));
        await settle(tester);
        expect(settings.chessEnabled, isFalse);
        expect(timer.chess, isFalse);
        expect(timer.started, isFalse);
        await close(tester);
      });
    });

    group('La hoja del reloj', () {
      Future<void> openSheet(WidgetTester tester) async {
        await tester.tap(find.byType(TimerButton));
        await settle(tester);
      }

      testWidgets('cambia el reloj de esta partida, no lo de Ajustes', (
        tester,
      ) async {
        await pumpApp(tester);
        await openSheet(tester);
        await tester.tap(find.byIcon(Icons.add).last);
        await settle(tester);
        expect(timer.roundLength, const Duration(minutes: 51));
        expect(settings.roundMinutes, 50);

        timer.start();
        now = now.add(const Duration(minutes: 7));
        await tester.pump();
        await tester.tap(find.text('Cronómetro'));
        await settle(tester);
        expect(timer.mode, TimerMode.stopwatch);
        expect(settings.timerMode, TimerMode.countdown);
        // Sin perder el tiempo que lleva.
        expect(timer.elapsed, const Duration(minutes: 7));
        await close(tester);
      });

      testWidgets('en ajedrez, «Iniciar» espera al botón de un jugador', (
        tester,
      ) async {
        await pumpApp(tester, before: enableChess);
        await openSheet(tester);
        expect(find.text('Pulsa el botón de quien no empieza'), findsOneWidget);
        final start = find.widgetWithText(FilledButton, 'Iniciar');
        expect(tester.widget<FilledButton>(start).onPressed, isNull);
        Navigator.of(tester.element(start)).pop();
        await settle(tester);

        await tester.tap(clockOf(0));
        await tester.pump();
        await openSheet(tester);
        expect(find.textContaining('le toca al de abajo'), findsOneWidget);
        await tester.tap(find.widgetWithText(FilledButton, 'Pausar'));
        await tester.pump();
        expect(timer.running, isFalse);
        await tester.tap(find.widgetWithText(FilledButton, 'Reanudar'));
        await tester.pump();
        expect(timer.running, isTrue);
        expect(timer.turn, Seat.bottom);
        await close(tester);
      });
    });
  });
}

/// Deja que acaben las transiciones y los diálogos. No vale pumpAndSettle:
/// con el reloj de ajedrez en marcha, el brillo del botón late sin parar.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}
