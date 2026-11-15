// Cuánto trabaja la app con la pantalla quieta, que es como está casi todo
// el tiempo en un torneo: cuántos fotogramas pide por segundo y cuánto pinta
// en cada uno.
//
//   flutter test test/battery_test.dart

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtglifecounter/look.dart';
import 'package:mtglifecounter/round_timer.dart';
import 'package:mtglifecounter/time_up.dart';

import 'layout_test.dart'
    show Screen, TestApp, loadFonts, pumpApp, tearDownApp, themes;

const Screen phone = Screen('Pixel 7 412x915', 412, 915, bottom: 24);

/// Lo que pasa en [seconds] segundos con la pantalla quieta, mirando a 60 Hz.
class Usage {
  Usage(this.frames, this.paints, this.seconds);

  final int frames;
  final int paints;
  final int seconds;

  double get framesPerSecond => frames / seconds;
  double get paintsPerSecond => paints / seconds;

  @override
  String toString() =>
      '${framesPerSecond.toStringAsFixed(1).padLeft(5)} fotogramas/s, '
      '${paintsPerSecond.toStringAsFixed(0).padLeft(5)} pintados/s';
}

Future<Usage> measure(
  WidgetTester tester,
  TestApp app, {
  int seconds = 10,
}) async {
  var paints = 0;
  var frames = 0;
  debugOnProfilePaint = (_) => paints++;
  addTearDown(() => debugOnProfilePaint = null);
  const step = Duration(microseconds: 16667);
  final steps = seconds * 60;
  for (var i = 0; i < steps; i++) {
    app.now = app.now.add(step);
    // Hay fotograma si ya estaba pedido o si algo (el segundero) lo pide
    // durante este paso y se pinta.
    final before = paints;
    final scheduled = tester.binding.hasScheduledFrame;
    await tester.pump(step);
    if (scheduled || paints > before) frames++;
  }
  debugOnProfilePaint = null;
  return Usage(frames, paints, seconds);
}

/// Cuánto puede gastar cada situación con la pantalla quieta.
class Budget {
  const Budget(this.framesPerSecond, this.paintsPerSecond);

  /// Fotogramas por segundo: 0 quieta, 1 con el segundero.
  final double framesPerSecond;

  /// Lo que se repinta por segundo. Toda la pantalla son unos 320: con el
  /// segundero solo debe repintarse el botón del reloj (unos 20) o, en el
  /// tema Original, cuyo LayoutBuilder reparte los botones, la barra (unos
  /// 120). Nunca los paneles.
  final double paintsPerSecond;
}

void main() {
  useGoogleFonts = false;
  setUpAll(loadFonts);
  setUp(() {
    for (final channel in [
      'dev.fluttercommunity.plus/sensors/method',
      'dev.fluttercommunity.plus/sensors/accelerometer',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(channel), (_) async => null);
    }
  });

  final report = <String>[];
  tearDownAll(() => debugPrint('\n${report.join('\n')}'));

  const still = Budget(0, 0);
  const ticking = Budget(1.05, 150);
  // Con el reloj de ajedrez se repintan además los dos botones de los
  // paneles y su columna (unos 60 más), pero nunca los paneles enteros.
  const chessTicking = Budget(1.05, 200);

  for (final theme in themes) {
    void scenario(
      String name,
      Budget budget,
      Future<void> Function(WidgetTester tester, TestApp app) setup,
    ) {
      testWidgets('${theme.$1} · $name', (tester) async {
        final app = await pumpApp(tester, phone, theme);
        await setup(tester, app);
        // Que acaben las animaciones de un solo golpe (el aviso de «¡Tiempo!»
        // dura 3,2 s) y lo que haya pendiente.
        await tester.pump(const Duration(seconds: 5));
        final usage = await measure(tester, app);
        report.add('${theme.$1.padRight(10)} ${name.padRight(28)} $usage');
        expect(
          usage.framesPerSecond,
          lessThanOrEqualTo(budget.framesPerSecond),
          reason: 'Algo se anima sin parar: $usage',
        );
        expect(
          usage.paintsPerSecond,
          lessThanOrEqualTo(budget.paintsPerSecond),
          reason: 'Se repinta más de la cuenta: $usage',
        );
        await tearDownApp(tester, app);
      });
    }

    scenario('en reposo', still, (tester, app) async {});
    scenario('con el reloj quieto', still, (tester, app) async {
      app.settings.showTimer = true;
      await tester.pump();
    });
    scenario('con el reloj en marcha', ticking, (tester, app) async {
      app.settings.showTimer = true;
      app.timer.start();
      await tester.pump();
    });
    // Acabado, el reloj se para en 0:00: no gasta nada.
    scenario('con el tiempo acabado', still, (tester, app) async {
      app.settings.showTimer = true;
      app.timer.start();
      app.now = app.now.add(const Duration(minutes: 51));
      await tester.pump(const Duration(seconds: 1));
      // Ha salido el aviso; al medir ya se ha ido solo.
      expect(find.byType(TimeUpScene), findsNWidgets(2));
    });
    scenario('tras tocar una vida', still, (tester, app) async {
      app.game.bottom.change(-3);
      await tester.pump();
    });
    // El reloj de ajedrez en marcha, con el brillo y la arena del que tiene
    // el turno: con una animación sin fin gastaba un 76 % en el móvil.
    scenario('con el reloj de ajedrez', chessTicking, (tester, app) async {
      app.settings
        ..chessEnabled = true
        ..timerMode = TimerMode.chess;
      await tester.pump();
      app.timer.press(Seat.top);
      await tester.pump();
      expect(app.timer.turn, Seat.bottom);
    });
  }
}
