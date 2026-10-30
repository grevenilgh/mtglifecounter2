import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtglifecounter/app_settings.dart';
import 'package:mtglifecounter/game_state.dart';
import 'package:mtglifecounter/look.dart';
import 'package:mtglifecounter/main.dart';
import 'package:mtglifecounter/player_counter.dart';
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
    });
  });

  testWidgets('tocar arriba suma y abajo resta', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settings = AppSettings(prefs);
    final game = GameState();
    final storage = GameStorage(prefs, game);

    await tester.binding.setSurfaceSize(const Size(400, 800));
    await tester.pumpWidget(
      MyApp(settings: settings, game: game, storage: storage),
    );

    // El panel de abajo ocupa la mitad inferior de la pantalla.
    final bottomPanel = tester.getRect(find.byType(PlayerCounter).last);
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
}
