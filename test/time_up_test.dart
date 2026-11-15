// El aviso de «¡Tiempo!» al acabar la ronda, y que el reloj se queda en 0:00.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtglifecounter/look.dart';
import 'package:mtglifecounter/round_timer.dart';
import 'package:mtglifecounter/time_up.dart';

import 'layout_test.dart'
    show Screen, TestApp, loadFonts, pumpApp, tearDownApp, themes;

const Screen phone = Screen('Pixel 7 412x915', 412, 915, bottom: 24);

Future<void> runOut(WidgetTester tester, TestApp app) async {
  app.settings.showTimer = true;
  app.timer.start();
  await tester.pump();
  app.now = app.now.add(const Duration(minutes: 50, seconds: 42));
  await tester.pump(const Duration(seconds: 1));
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

  for (final theme in themes) {
    testWidgets('${theme.$1} · sale el aviso, se va solo y el reloj se queda '
        'en 0:00', (tester) async {
      final app = await pumpApp(tester, phone, theme);
      await runOut(tester, app);
      expect(find.byType(TimeUpOverlay), findsOneWidget);
      expect(find.text('¡TIEMPO!'), findsNWidgets(2));
      expect(timerLabel(app.timer), '0:00');
      // El botón de la barra lleva además una plantilla invisible de ceros.
      expect(find.text('0:00'), findsWidgets);
      expect(app.timer.running, isFalse);

      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(TimeUpOverlay.duration);
      await tester.pump();
      expect(find.byType(TimeUpOverlay), findsNothing);
      app.now = app.now.add(const Duration(minutes: 5));
      await tester.pump(const Duration(seconds: 1));
      expect(timerLabel(app.timer), '0:00');
      // El botón de la barra lleva además una plantilla invisible de ceros.
      expect(find.text('0:00'), findsWidgets);
      await tearDownApp(tester, app);
    });
  }

  testWidgets('tocar el aviso lo quita sin tocar las vidas', (tester) async {
    final app = await pumpApp(tester, phone, themes.first);
    await runOut(tester, app);
    await tester.tapAt(const Offset(206, 800));
    await tester.pump();
    expect(find.byType(TimeUpOverlay), findsNothing);
    expect(app.game.bottom.life, 20);
    expect(app.game.top.life, 20);
    await tearDownApp(tester, app);
  });

  testWidgets('sin animaciones sale quieto y también se va solo', (
    tester,
  ) async {
    final app = await pumpApp(tester, phone, themes.first);
    app.settings.animations = false;
    await runOut(tester, app);
    expect(find.text('¡TIEMPO!'), findsNWidgets(2));
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pump(TimeUpOverlay.duration);
    await tester.pump();
    expect(find.byType(TimeUpOverlay), findsNothing);
    await tearDownApp(tester, app);
  });
}
