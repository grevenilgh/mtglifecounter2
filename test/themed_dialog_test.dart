// El diálogo de confirmación vestido con cada tema (reiniciar la partida).

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtglifecounter/game_state.dart';
import 'package:mtglifecounter/look.dart';
import 'package:mtglifecounter/themed_dialog.dart';

import 'layout_test.dart' show Screen, loadFonts, pumpApp, tearDownApp, themes;

const Screen phone = Screen('Pixel 7 412x915', 412, 915, bottom: 24);

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
    testWidgets('${theme.$1} · reiniciar pregunta con el diálogo del tema', (
      tester,
    ) async {
      final app = await pumpApp(tester, phone, theme);
      app.game.top
        ..change(-5)
        ..commit();
      await tester.pump();

      Future<void> open() async {
        await tester.tap(find.byTooltip('Reiniciar partida'));
        await tester.pumpAndSettle();
        expect(find.byType(ThemedDialog), findsOneWidget);
        expect(find.text('¿Reiniciar la partida?'), findsOneWidget);
      }

      // Cancelar no toca nada.
      await open();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.byType(ThemedDialog), findsNothing);
      expect(app.game.top.life, kInitialLife - 5);

      // Tocar fuera, tampoco.
      await open();
      await tester.tapAt(const Offset(20, 60));
      await tester.pumpAndSettle();
      expect(find.byType(ThemedDialog), findsNothing);
      expect(app.game.top.life, kInitialLife - 5);

      // Reiniciar, sí.
      await open();
      await tester.tap(find.text('Reiniciar'));
      await tester.pumpAndSettle();
      expect(find.byType(ThemedDialog), findsNothing);
      expect(app.game.top.life, kInitialLife);
      expect(app.game.top.history, isEmpty);
      await tearDownApp(tester, app);
    });
  }
}
