import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtglifecounter/app_settings.dart';
import 'package:mtglifecounter/game_state.dart';
import 'package:mtglifecounter/look.dart';
import 'package:mtglifecounter/main.dart';
import 'package:mtglifecounter/round_timer.dart';
import 'package:mtglifecounter/skin.dart';
import 'package:mtglifecounter/welcome_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppSettings> openApp(
  WidgetTester tester, {
  Map<String, Object> saved = const {},
  Size size = const Size(400, 860),
}) async {
  SharedPreferences.setMockInitialValues(saved);
  final prefs = await SharedPreferences.getInstance();
  final settings = AppSettings(prefs);
  final game = GameState();
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MyApp(
      settings: settings,
      game: game,
      storage: GameStorage(prefs, game),
      timer: RoundTimer(prefs),
      showWelcome: !settings.welcomeDone,
    ),
  );
  await tester.pumpAndSettle();
  return settings;
}

void main() {
  useGoogleFonts = false;

  testWidgets('la primera vez sale y «Empezar» guarda lo elegido', (
    tester,
  ) async {
    final settings = await openApp(tester);
    expect(find.byType(WelcomePage), findsOneWidget);
    // Lo de por defecto, ya marcado.
    expect(settings.skinId, Skin.alicante.id);
    expect(settings.showHistory, isTrue);
    expect(settings.showTimer, isTrue);
    expect(settings.showStepper, isFalse);
    // La personalizada no se ofrece aquí: va en Ajustes.
    expect(find.text('Personalizada'), findsNothing);

    await tester.tap(find.text('Full Tapped'));
    await tester.tap(find.text('Old Border'));
    await tester.pump();
    await tester.ensureVisible(find.text('Cantidad por toque'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cantidad por toque'));
    await tester.pump();
    await tester.tap(find.text('Empezar'));
    await tester.pumpAndSettle();

    expect(find.byType(WelcomePage), findsNothing);
    expect(settings.skinId, Skin.fullTapped.id);
    expect(settings.theme, AppTheme.classic);
    expect(settings.showStepper, isTrue);
    expect(settings.welcomeDone, isTrue);
    // Queda guardado: al volver a abrir la app ya no sale.
    final prefs = await SharedPreferences.getInstance();
    expect(AppSettings(prefs).welcomeDone, isTrue);
  });

  testWidgets('«Saltar» deja lo que había, aunque se haya tocado algo', (
    tester,
  ) async {
    // Una app ya instalada, con lo suyo y sin haber visto la bienvenida.
    final settings = await openApp(
      tester,
      saved: {
        'flutter.skin': Skin.oldSchool.id,
        'flutter.theme': AppTheme.modern.name,
        'flutter.showHistory': false,
        'flutter.showTimer': false,
      },
    );
    expect(find.byType(WelcomePage), findsOneWidget);
    expect(settings.skinId, Skin.oldSchool.id);

    await tester.tap(find.text('AlicanteMTG'));
    await tester.tap(find.text('Original'));
    await tester.pump();
    expect(settings.skinId, Skin.alicante.id);

    await tester.tap(find.text('Saltar'));
    await tester.pumpAndSettle();

    expect(find.byType(WelcomePage), findsNothing);
    expect(settings.skinId, Skin.oldSchool.id);
    expect(settings.theme, AppTheme.modern);
    expect(settings.showHistory, isFalse);
    expect(settings.showTimer, isFalse);
    expect(settings.welcomeDone, isTrue);
  });

  testWidgets('si ya se vio, no sale', (tester) async {
    await openApp(tester, saved: {'flutter.welcomeDone': true});
    expect(find.byType(WelcomePage), findsNothing);
  });

  for (final (name, size, scale) in [
    ('móvil pequeño', const Size(320, 568), 1.0),
    ('letra al 200 %', const Size(400, 860), 2.0),
  ]) {
    testWidgets('cabe en un $name', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: TextScaler.linear(scale),
            ),
            child: WelcomePage(
              settings: AppSettings(prefs),
              timer: RoundTimer(prefs),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // «Empezar» siempre a la vista, aunque lo demás haya que bajarlo.
      expect(find.text('Empezar').hitTestable(), findsOneWidget);
    });
  }
}
