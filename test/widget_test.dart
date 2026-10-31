import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtglifecounter/app_icon.dart';
import 'package:mtglifecounter/app_settings.dart';
import 'package:mtglifecounter/game_state.dart';
import 'package:mtglifecounter/look.dart';
import 'package:mtglifecounter/main.dart';
import 'package:mtglifecounter/player_counter.dart';
import 'package:mtglifecounter/round_timer.dart';
import 'package:mtglifecounter/skin.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // En los tests no hay red para descargar fuentes.
  useGoogleFonts = false;

  group('PlayerState', () {
    test('agrupa los cambios en una sola entrada del historial', () {
      final player = PlayerState();
      player.change(-1);
      player.change(-1);
      player.change(-3);
      expect(player.life, 15);
      expect(player.pending, -5);
      expect(player.history, isEmpty);

      player.commit();
      expect(player.history, ['-5 = 15']);
      expect(player.pending, 0);

      player.change(2);
      player.commit();
      expect(player.history, ['-5 = 15', '+2 = 17']);
    });

    test('no sale del rango [-999, 999]', () {
      final player = PlayerState();
      expect(player.change(979), isTrue);
      expect(player.change(1), isFalse);
      expect(player.life, 999);
    });

    test('al recuperar una partida apunta el grupo que quedó a medias', () {
      final player = PlayerState()
        ..restore({
          'life': 12,
          'committedLife': 15,
          'history': ['-5 = 15'],
        });
      expect(player.history, ['-5 = 15', '-3 = 12']);
      expect(player.pending, 0);
    });
  });

  group('GameStorage', () {
    test('guarda y recupera la partida', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final game = GameState();
      final storage = GameStorage(prefs, game)..enabled = true;
      game.top
        ..change(-4)
        ..commit();
      game.toggleRotation();
      storage.flush();

      final restored = GameState();
      GameStorage(prefs, restored).load();
      expect(restored.top.life, 16);
      expect(restored.top.history, ['-4 = 16']);
      expect(restored.rotated, isTrue);

      storage.enabled = false;
      expect(prefs.getString('game'), isNull);
    });
  });

  group('AppSettings', () {
    test('recuerda la skin elegida y los colores personalizados', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final settings = AppSettings(prefs)
        ..skinId = Skin.customDefault.id
        ..customSkin = Skin.customDefault.copyWith(
          top: const Color(0xFF0F766E),
          background: SkinBackground.fullTapped,
        );

      final reloaded = AppSettings(prefs);
      expect(reloaded.skin.id, 'custom');
      expect(reloaded.skin.top.toARGB32(), 0xFF0F766E);
      expect(reloaded.skin.background, SkinBackground.fullTapped);
      expect(settings.backgroundOf(reloaded.skin), isA<AssetImage>());
    });

    test('la barra y el historial tienen su propia opacidad', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settings = AppSettings(prefs);

      // Sin tocarlas, cada tema trae las suyas.
      expect(settings.historyOpacity, 50);
      settings.theme = AppTheme.modern;
      expect(settings.historyOpacity, 30);

      settings
        ..barOpacity = 10
        ..historyOpacity = 80;
      final reloaded = AppSettings(prefs);
      expect(reloaded.barOpacity, AppSettings.minBarOpacity);
      expect(reloaded.historyOpacity, 80);
      expect(reloaded.frameOpacity, 92);
    });

    test('el golpe contrasta con el color del panel', () {
      const green = Color(0xFF4ADE80);
      const red = Color(0xFFF85050);
      // Morado de AlicanteMTG: verde al ganar y rojo al perder.
      expect(hitColor(up: true, panel: Skin.alicante.top), green);
      expect(hitColor(up: false, panel: Skin.alicante.top), red);
      // Sobre el verde de AlicanteMTG el verde no se vería.
      expect(hitColor(up: true, panel: Skin.alicante.bottom), isNot(green));
      // Sobre el granate de Full Tapped el rojo tampoco.
      expect(hitColor(up: false, panel: Skin.fullTapped.top), isNot(red));
    });

    test('las skins publicadas no cambian por error', () {
      expect(Skin.alicante.top.toARGB32(), 0xFF673AB7);
      expect(Skin.fullTapped.top.toARGB32(), 0xFF9B1D20);
      expect(Skin.fullTapped.bottom.toARGB32(), 0xFF3D2B3D);
      expect(Skin.oldSchool.top.toARGB32(), 0xFF006AA9);
      expect(Skin.oldSchool.bottom.toARGB32(), 0xFF484848);
      expect(Skin.oldSchool.bar.toARGB32(), 0xFF1F2020);
    });
  });

  group('RoundTimer', () {
    late DateTime now;
    late SharedPreferences prefs;

    setUp(() async {
      now = DateTime(2026, 10, 30, 18);
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('la cuenta atrás descuenta las pausas', () {
      final timer = RoundTimer(prefs, clock: () => now);
      addTearDown(timer.dispose);
      expect(timer.shown, const Duration(minutes: 50));

      timer.start();
      now = now.add(const Duration(minutes: 20));
      timer.pause();
      now = now.add(const Duration(minutes: 10)); // en pausa no cuenta
      expect(timer.remaining, const Duration(minutes: 30));
      expect(formatClock(timer.shown), '30:00');

      // Con la ronda empezada no se cambia la duración.
      timer.setRoundLength(const Duration(minutes: 40));
      expect(timer.roundLength, const Duration(minutes: 50));

      timer.start();
      now = now.add(const Duration(minutes: 26));
      expect(timer.warning, isTrue);
      now = now.add(const Duration(minutes: 5));
      timer.pause();
      timer.start(); // ya acabada, no vuelve a arrancar
      expect(timer.finished, isTrue);
      expect(timer.running, isFalse);
      expect(timer.shown, Duration.zero);
    });

    testWidgets('al llegar a cero avisa una sola vez', (tester) async {
      var finishedCalls = 0;
      final timer = RoundTimer(prefs, clock: () => now)
        ..setRoundLength(const Duration(minutes: 5))
        ..onFinished = () => finishedCalls++;
      timer.start();
      now = now.add(const Duration(minutes: 6));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 3));
      expect(finishedCalls, 1);
      expect(timer.elapsed, const Duration(minutes: 5));

      timer.reset();
      expect(timer.started, isFalse);
      expect(timer.shown, const Duration(minutes: 5));
      timer.dispose();
    });

    test('el cronómetro cuenta hacia delante y sobrevive a cerrar la app', () {
      final timer = RoundTimer(
        prefs,
        mode: TimerMode.stopwatch,
        clock: () => now,
      );
      addTearDown(timer.dispose);
      timer.start();
      now = now.add(const Duration(hours: 1, minutes: 2, seconds: 3));
      expect(formatClock(timer.shown), '1:02:03');
      expect(timer.warning, isFalse);
      expect(timer.finished, isFalse);

      final reopened = RoundTimer(
        prefs,
        mode: TimerMode.stopwatch,
        clock: () => now,
      );
      addTearDown(reopened.dispose);
      expect(reopened.running, isTrue);
      expect(
        reopened.elapsed,
        const Duration(hours: 1, minutes: 2, seconds: 3),
      );
    });
  });

  test('cada jugador lleva un marco de carta distinto', () {
    // Lo que se decidió con el usuario para las skins publicadas.
    expect(CardFrame.forPlayers(Skin.alicante.top, Skin.alicante.bottom), (
      CardFrame.negro,
      CardFrame.verde,
    ));
    expect(CardFrame.forPlayers(Skin.fullTapped.top, Skin.fullTapped.bottom), (
      CardFrame.rojo,
      CardFrame.artefacto,
    ));
    expect(
      CardFrame.forPlayers(Skin.customDefault.top, Skin.customDefault.bottom),
      (CardFrame.azul, CardFrame.rojo),
    );
    // Con el mismo color, el de abajo se queda con su segunda opción.
    const red = Color(0xFFC62828);
    expect(CardFrame.forPlayers(red, red), (
      CardFrame.rojo,
      CardFrame.artefacto,
    ));
    // Dorado y amarillo, multicolor; naranja, artefacto.
    expect(CardFrame.rankFor(const Color(0xFFD4AF37)).first, CardFrame.oro);
    expect(
      CardFrame.rankFor(const Color(0xFFB45309)).first,
      CardFrame.artefacto,
    );
  });

  test('cada skin lleva su icono', () {
    expect(appIconFor(Skin.alicante.id), 'alicante');
    expect(appIconFor(Skin.fullTapped.id), 'fulltapped');
    expect(appIconFor(Skin.oldSchool.id), 'oldschool');
    expect(appIconFor(Skin.customDefault.id), 'mesa');
  });

  testWidgets('tocar arriba suma y abajo resta', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settings = AppSettings(prefs);
    final game = GameState();
    final storage = GameStorage(prefs, game);
    final timer = RoundTimer(prefs);

    await tester.binding.setSurfaceSize(const Size(400, 800));
    await tester.pumpWidget(
      MyApp(settings: settings, game: game, storage: storage, timer: timer),
    );

    // El panel de abajo ocupa la mitad inferior de la pantalla.
    final bottomPanel = tester.getRect(find.byType(PlayerCounter).last);

    // El tono de la mitad que suma cubre el panel a lo ancho (se quedaba
    // con 0 de ancho y no se veía).
    final addHalf = find.descendant(
      of: find.byType(PlayerCounter).last,
      matching: find.byWidgetPredicate(
        (w) =>
            w is ColoredBox && w.color == Colors.white.withValues(alpha: 0.1),
      ),
    );
    expect(tester.getSize(addHalf).width, greaterThan(bottomPanel.width / 2));
    await tester.tapAt(Offset(bottomPanel.left + 60, bottomPanel.top + 40));
    await tester.pump();
    expect(game.bottom.life, 21);

    await tester.tapAt(Offset(bottomPanel.left + 60, bottomPanel.bottom - 40));
    await tester.tapAt(Offset(bottomPanel.left + 60, bottomPanel.bottom - 40));
    await tester.pump(const Duration(milliseconds: 800));
    expect(game.bottom.life, 19);
    expect(game.bottom.history, ['-1 = 19']);

    // Deja que acaben los temporizadores pendientes.
    await tester.pump(const Duration(seconds: 1));
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('sin historial se sigue apuntando y todo el panel cuenta', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settings = AppSettings(prefs)..showHistory = false;
    expect(AppSettings(prefs).showHistory, isFalse);
    final game = GameState();
    final storage = GameStorage(prefs, game);
    final timer = RoundTimer(prefs);

    await tester.binding.setSurfaceSize(const Size(400, 800));
    await tester.pumpWidget(
      MyApp(settings: settings, game: game, storage: storage, timer: timer),
    );
    final panel = find.byType(PlayerCounter).last;
    final list = find.descendant(of: panel, matching: find.byType(ListView));
    expect(list, findsNothing);

    // Donde iba el historial ahora se suma.
    final rect = tester.getRect(panel);
    await tester.tapAt(Offset(rect.right - 20, rect.top + 40));
    await tester.pump(const Duration(milliseconds: 800));
    expect(game.bottom.life, 21);
    expect(game.bottom.history, ['+1 = 21']);

    // Al volver a enseñarlo está todo lo apuntado.
    settings.showHistory = true;
    await tester.pump();
    expect(list, findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    await tester.binding.setSurfaceSize(null);
  });
}
