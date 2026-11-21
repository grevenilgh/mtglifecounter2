// Pruebas de «Eventos de Companion»: la lógica que sigue los avisos de ronda
// (CompanionLink, con un Android de mentira) y, dentro de la app, el
// interruptor de Ajustes, la marca del reloj de la barra y la hoja.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtglifecounter/app_settings.dart';
import 'package:mtglifecounter/companion.dart';
import 'package:mtglifecounter/game_state.dart';
import 'package:mtglifecounter/look.dart';
import 'package:mtglifecounter/main.dart';
import 'package:mtglifecounter/round_timer.dart';
import 'package:mtglifecounter/settings_page.dart';
import 'package:mtglifecounter/timer_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Android de mentira: los avisos que se le pongan y lo que se le pide.
class FakeBridge implements CompanionBridge {
  final List<CompanionEvent> list = [];
  bool access = true;
  final List<bool> enabledCalls = [];
  int accessOpened = 0;
  VoidCallback? changed;

  @override
  set onChanged(VoidCallback? callback) => changed = callback;

  @override
  Future<void> setEnabled(bool enabled) async => enabledCalls.add(enabled);

  @override
  Future<bool> hasAccess() async => access;

  @override
  Future<void> openAccess() async => accessOpened++;

  bool screenAccess = false;
  final List<bool> screenCalls = [];
  int screenOpened = 0;

  @override
  Future<void> setScreenEnabled(bool enabled) async =>
      screenCalls.add(enabled);

  @override
  Future<bool> hasScreenAccess() async => screenAccess;

  @override
  Future<void> openScreenAccess() async => screenOpened++;

  @override
  Future<void> openAppInfo() async {}

  @override
  Future<List<CompanionEvent>> events() async => List.of(list);

  final List<(String, Map<String, Object?>)> logs = [];

  @override
  Future<void> log(String ev, Map<String, Object?> data) async =>
      logs.add((ev, data));
}

void main() {
  useGoogleFonts = false;

  late DateTime now;
  late SharedPreferences prefs;
  late FakeBridge bridge;

  setUp(() async {
    now = DateTime(2026, 11, 21, 17, 17);
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    bridge = FakeBridge();
  });

  RoundTimer newTimer({TimerMode mode = TimerMode.countdown}) => RoundTimer(
    prefs,
    mode: mode,
    roundLength: const Duration(minutes: 52),
    clock: () => now,
  );

  CompanionLink newLink(RoundTimer timer, {bool enabled = true}) =>
      CompanionLink(
        prefs,
        timer,
        enabled: enabled,
        bridge: bridge,
        clock: () => now,
      );

  CompanionEvent ev(CompanionEventKind kind, DateTime at) =>
      CompanionEvent(kind, at);

  group('CompanionLink', () {
    test('«Ronda iniciada» reinicia el reloj y lo arranca desde el aviso', () {
      final timer = newTimer();
      addTearDown(timer.dispose);
      final link = newLink(timer);
      // Lo de antes de la ronda se borra.
      timer.start();
      now = now.add(const Duration(minutes: 10));
      final start = now;
      bridge.list.add(ev(CompanionEventKind.roundStarted, start));
      // La app se abre tres minutos después del aviso.
      now = now.add(const Duration(minutes: 3));
      link.apply(bridge.list);
      expect(timer.running, isTrue);
      expect(timer.remaining, const Duration(minutes: 49));
      expect(link.engaged, isTrue);
    });

    test('«Ronda completada» lo para', () {
      final timer = newTimer();
      addTearDown(timer.dispose);
      final link = newLink(timer);
      final start = now;
      now = now.add(const Duration(minutes: 40));
      link.apply([
        ev(CompanionEventKind.roundStarted, start),
        ev(CompanionEventKind.roundCompleted, now),
      ]);
      expect(timer.running, isFalse);
      expect(timer.remaining, const Duration(minutes: 12));
    });

    test('cada ronda vuelve a la duración de Ajustes', () {
      final timer = newTimer();
      addTearDown(timer.dispose);
      final link = newLink(timer);
      timer.setRoundLength(const Duration(minutes: 30));
      link.apply([ev(CompanionEventKind.roundStarted, now)]);
      expect(timer.roundLength, const Duration(minutes: 52));
    });

    test('los avisos ya vistos no se vuelven a aplicar', () {
      final timer = newTimer();
      addTearDown(timer.dispose);
      final link = newLink(timer);
      final start = now;
      link.apply([ev(CompanionEventKind.roundStarted, start)]);
      now = now.add(const Duration(minutes: 5));
      timer.pause();
      // Al volver a la app llegan otra vez los mismos: no se arranca.
      link.apply([ev(CompanionEventKind.roundStarted, start)]);
      expect(timer.running, isFalse);
      // Y lo visto se recuerda al reabrir la app.
      final again = newLink(timer);
      again.apply([ev(CompanionEventKind.roundStarted, start)]);
      expect(timer.running, isFalse);
    });

    test('lo que llegó antes de activarlo no cuenta', () {
      final timer = newTimer();
      addTearDown(timer.dispose);
      final link = newLink(timer, enabled: false);
      final before = now;
      now = now.add(const Duration(minutes: 1));
      link.enabled = true;
      link.apply([ev(CompanionEventKind.roundStarted, before)]);
      expect(timer.running, isFalse);
      expect(link.inEvent, isFalse);
      expect(bridge.enabledCalls, [false, true]);
    });

    test('apagado no hace nada', () {
      final timer = newTimer();
      addTearDown(timer.dispose);
      final link = newLink(timer, enabled: false);
      link.apply([ev(CompanionEventKind.roundStarted, now)]);
      expect(timer.started, isFalse);
      expect(link.engaged, isFalse);
    });

    test('suelto, no toca el reloj; el evento siguiente lo engancha', () {
      final timer = newTimer();
      addTearDown(timer.dispose);
      final link = newLink(timer);
      link.apply([ev(CompanionEventKind.eventStarted, now)]);
      expect(link.engaged, isTrue);
      link.attached = false;
      expect(link.engaged, isFalse);
      expect(link.inEvent, isTrue);
      now = now.add(const Duration(minutes: 1));
      link.apply([ev(CompanionEventKind.roundStarted, now)]);
      expect(timer.started, isFalse);
      // Otro torneo, días después.
      now = now.add(const Duration(days: 7));
      link.apply([ev(CompanionEventKind.roundStarted, now)]);
      expect(link.engaged, isTrue);
      expect(timer.running, isTrue);
    });

    test('a las 3 horas sin avisos se suelta solo', () {
      final timer = newTimer();
      addTearDown(timer.dispose);
      final link = newLink(timer);
      link.apply([ev(CompanionEventKind.roundCompleted, now)]);
      expect(link.engaged, isTrue);
      now = now.add(CompanionLink.idleLimit);
      expect(link.engaged, isFalse);
      expect(link.inEvent, isFalse);
    });

    test('lo de hace más de 3 horas no se aplica', () {
      final timer = newTimer();
      addTearDown(timer.dispose);
      final link = newLink(timer);
      final old = now;
      now = now.add(const Duration(hours: 4));
      link.apply([ev(CompanionEventKind.roundStarted, old)]);
      expect(timer.started, isFalse);
      expect(link.inEvent, isFalse);
    });

    test('si la ronda ya se acabó, se queda en 0:00 sin avisar', () {
      final timer = newTimer();
      addTearDown(timer.dispose);
      var finished = 0;
      timer.onFinished = () => finished++;
      final link = newLink(timer);
      final start = now;
      now = now.add(const Duration(hours: 1));
      link.apply([ev(CompanionEventKind.roundStarted, start)]);
      expect(timer.finished, isTrue);
      expect(timer.running, isFalse);
      expect(finished, 0);
    });

    test('el reloj de ajedrez se reinicia pero no arranca', () {
      final timer = newTimer(mode: TimerMode.chess);
      addTearDown(timer.dispose);
      final link = newLink(timer);
      timer.press(Seat.top);
      link.apply([ev(CompanionEventKind.roundStarted, now)]);
      expect(timer.chess, isTrue);
      expect(timer.started, isFalse);
    });

    CompanionEvent clock(Duration left, DateTime at) =>
        CompanionEvent(CompanionEventKind.screenClock, at, left: left);

    test('la pantalla de Companion pone el reloj en hora', () {
      final timer = newTimer();
      addTearDown(timer.dispose);
      final link = CompanionLink(
        prefs,
        timer,
        enabled: true,
        bridge: bridge,
        clock: () => now,
      );
      // Va en cronómetro y desfasado: pasa a cuenta atrás con lo de Companion.
      timer.mode = TimerMode.stopwatch;
      timer.start();
      final seen = now;
      now = now.add(const Duration(seconds: 30));
      link.apply([clock(const Duration(minutes: 37, seconds: 12), seen)]);
      expect(timer.mode, TimerMode.countdown);
      expect(timer.running, isTrue);
      expect(timer.remaining, const Duration(minutes: 36, seconds: 42));
      expect(link.engaged, isTrue);
    });

    test('si Companion tiene más tiempo que la ronda, se alarga', () {
      final timer = newTimer();
      addTearDown(timer.dispose);
      final link = CompanionLink(
        prefs,
        timer,
        enabled: true,
        bridge: bridge,
        clock: () => now,
      );
      link.apply([clock(const Duration(minutes: 54, seconds: 18), now)]);
      expect(timer.roundLength, const Duration(minutes: 55));
      expect(timer.remaining, const Duration(minutes: 54, seconds: 18));
    });

    test('apagado, o suelto, la pantalla no toca el reloj', () {
      final timer = newTimer();
      addTearDown(timer.dispose);
      final off = newLink(timer, enabled: false);
      off.apply([clock(const Duration(minutes: 20), now)]);
      expect(timer.started, isFalse);
      // Suelto dentro de un evento (uno nuevo lo volvería a enganchar).
      final link = newLink(timer)
        ..apply([ev(CompanionEventKind.eventStarted, now)])
        ..attached = false;
      now = now.add(const Duration(seconds: 5));
      link.apply([clock(const Duration(minutes: 20), now)]);
      expect(timer.started, isFalse);
    });

    test('la pantalla se enciende y apaga con el mismo interruptor', () {
      final timer = newTimer();
      addTearDown(timer.dispose);
      final link = newLink(timer, enabled: false);
      link.enabled = true;
      link.enabled = false;
      expect(bridge.screenCalls, [false, true, false]);
      expect(bridge.enabledCalls, [false, true, false]);
    });

    test('el reloj de ajedrez no se pone en hora con la pantalla', () {
      final timer = newTimer(mode: TimerMode.chess);
      addTearDown(timer.dispose);
      final link = CompanionLink(
        prefs,
        timer,
        enabled: true,
        bridge: bridge,
        clock: () => now,
      );
      link.apply([clock(const Duration(minutes: 20), now)]);
      expect(timer.chess, isTrue);
      expect(timer.started, isFalse);
    });

    test('apunta lo que hace con cada aviso (trazas provisionales)', () {
      final timer = newTimer();
      addTearDown(timer.dispose);
      final link = newLink(timer);
      final start = now;
      now = now.add(const Duration(minutes: 1));
      link.apply([ev(CompanionEventKind.roundStarted, start)]);
      final (name, data) = bridge.logs.last;
      expect(name, 'event');
      expect(data['kind'], 'round_started');
      expect(data['decision'], 'applied');
      expect((data['before']! as Map)['running'], isFalse);
      expect((data['after']! as Map)['running'], isTrue);
      expect((data['after']! as Map)['shownMs'], 51 * 60 * 1000);
      // Apagado no apunta nada.
      bridge.logs.clear();
      link.enabled = false;
      link.trace('app-paused');
      expect(bridge.logs.map((l) => l.$1), ['disabled']);
    });

    test('sync lee los avisos del servicio y se llama cuando cambian', () async {
      final timer = newTimer();
      addTearDown(timer.dispose);
      newLink(timer);
      bridge.list.add(ev(CompanionEventKind.roundStarted, now));
      bridge.changed!();
      await Future<void>.delayed(Duration.zero);
      expect(timer.running, isTrue);
    });
  });

  group('En la app', () {
    late AppSettings settings;
    late RoundTimer timer;
    late CompanionLink link;

    Future<void> pumpApp(WidgetTester tester, {bool enabled = true}) async {
      await tester.binding.setSurfaceSize(const Size(400, 860));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      settings = AppSettings(prefs)
        ..roundMinutes = 52
        ..companionEnabled = enabled;
      final game = GameState();
      timer = RoundTimer(
        prefs,
        mode: settings.timerMode,
        roundLength: Duration(minutes: settings.roundMinutes),
        clock: () => now,
      );
      link = CompanionLink(
        prefs,
        timer,
        enabled: settings.companionEnabled,
        bridge: bridge,
        clock: () => now,
      );
      await tester.pumpWidget(
        MyApp(
          settings: settings,
          game: game,
          storage: GameStorage(prefs, game),
          timer: timer,
          companion: link,
        ),
      );
      await tester.pump();
    }

    Future<void> close(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
      timer.dispose();
    }

    Finder linkMark() => find.descendant(
      of: find.byType(TimerButton),
      matching: find.byIcon(Icons.link_rounded),
    );

    testWidgets('al abrir aplica lo que llegó con la app cerrada', (
      tester,
    ) async {
      bridge.list.add(
        ev(CompanionEventKind.roundStarted, DateTime(2026, 11, 21, 17, 10)),
      );
      await pumpApp(tester);
      await tester.pump();
      expect(timer.running, isTrue);
      expect(timer.remaining, const Duration(minutes: 45));
      expect(linkMark(), findsOneWidget);
      // La cadena va en lugar del icono del reloj, no al lado.
      expect(
        find.descendant(
          of: find.byType(TimerButton),
          matching: find.byIcon(Icons.timer_outlined),
        ),
        findsNothing,
      );
      await close(tester);
    });

    testWidgets('sin evento no hay marca ni fila en la hoja', (tester) async {
      await pumpApp(tester);
      expect(linkMark(), findsNothing);
      await tester.tap(find.byType(TimerButton));
      await tester.pumpAndSettle();
      expect(find.text('Seguir a Companion'), findsNothing);
      await close(tester);
    });

    testWidgets('en un evento, la hoja deja soltarlo y quita la marca', (
      tester,
    ) async {
      bridge.list.add(ev(CompanionEventKind.eventStarted, now));
      await pumpApp(tester);
      await tester.pump();
      expect(linkMark(), findsOneWidget);
      await tester.tap(find.byType(TimerButton));
      await tester.pumpAndSettle();
      expect(find.text('Seguir a Companion'), findsOneWidget);
      await tester.tap(find.byType(Switch).last);
      await tester.pumpAndSettle();
      expect(link.attached, isFalse);
      expect(
        find.text('Suelto en este torneo: el reloj va a mano.'),
        findsOneWidget,
      );
      Navigator.of(tester.element(find.byType(Switch).last)).pop();
      await tester.pumpAndSettle();
      expect(linkMark(), findsNothing);
      await close(tester);
    });

    testWidgets('el interruptor de Ajustes pide el acceso si falta', (
      tester,
    ) async {
      bridge.access = false;
      await pumpApp(tester, enabled: false);
      await tester.tap(find.byTooltip('Ajustes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Partida'));
      await tester.pumpAndSettle();
      final title = find.text('Eventos de Companion');
      await tester.scrollUntilVisible(
        title,
        200,
        scrollable: find
            .ancestor(
              of: find.text('En pantalla'),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      final toggle = find.descendant(
        of: find.ancestor(of: title, matching: find.byType(SwitchListTile)),
        matching: find.byType(Switch),
      );
      await tester.ensureVisible(toggle);
      await tester.pumpAndSettle();
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(settings.companionEnabled, isTrue);
      expect(link.enabled, isTrue);
      expect(find.text('Dar acceso a notificaciones'), findsOneWidget);
      await tester.tap(find.text('Ir a Ajustes'));
      await tester.pumpAndSettle();
      expect(bridge.accessOpened, 1);
      // Sigue faltando: lo dice debajo del interruptor.
      expect(find.text('Dar acceso'), findsOneWidget);
      await close(tester);
    });

    Future<void> openCompanionSettings(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Ajustes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Partida'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Eventos de Companion'),
        200,
        scrollable: find
            .ancestor(
              of: find.text('En pantalla'),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
    }

    testWidgets('leer la pantalla es opcional y explica el permiso', (
      tester,
    ) async {
      await pumpApp(tester, enabled: false);
      await openCompanionSettings(tester);
      // Sin los eventos activados no sale.
      final ask = find.text('Leer la pantalla de Companion');
      expect(ask, findsNothing);
      settings.companionEnabled = true;
      await tester.pumpAndSettle();
      await tester.ensureVisible(ask);
      await tester.pumpAndSettle();
      await tester.tap(ask);
      await tester.pumpAndSettle();
      // El aviso explica el permiso antes de mandar a Accesibilidad.
      expect(find.textContaining('solo recibe lo de Companion'), findsWidgets);
      await tester.tap(find.text('Ir a Accesibilidad'));
      await tester.pumpAndSettle();
      expect(bridge.screenOpened, 1);
      await close(tester);
    });

    testWidgets('con el permiso dado lo dice y no lo vuelve a pedir', (
      tester,
    ) async {
      bridge.screenAccess = true;
      await pumpApp(tester);
      await openCompanionSettings(tester);
      expect(find.text('Leer la pantalla de Companion'), findsNothing);
      expect(
        find.textContaining('También se pone en hora al abrir Companion'),
        findsOneWidget,
      );
      await close(tester);
    });

    testWidgets('sin Companion (fuera de Android) no sale el interruptor', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SettingsPage(
            settings: AppSettings(prefs),
            timer: newTimer(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Partida'));
      await tester.pumpAndSettle();
      expect(find.text('Eventos de Companion'), findsNothing);
    });
  });
}
