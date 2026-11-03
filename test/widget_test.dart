import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtglifecounter/about_page.dart';
import 'package:mtglifecounter/app_icon.dart';
import 'package:mtglifecounter/app_settings.dart';
import 'package:mtglifecounter/game_state.dart';
import 'package:mtglifecounter/hold_to_repeat.dart';
import 'package:mtglifecounter/look.dart';
import 'package:mtglifecounter/main.dart';
import 'package:mtglifecounter/player_counter.dart';
import 'package:mtglifecounter/round_timer.dart';
import 'package:mtglifecounter/skin.dart';
import 'package:mtglifecounter/timer_view.dart';
import 'package:package_info_plus/package_info_plus.dart';
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

    test(
      'volver al aspecto por defecto no toca tema, skin ni partida',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final settings = AppSettings(prefs)
          ..theme = AppTheme.classic
          ..skinId = Skin.oldSchool.id
          ..showHistory = false
          ..backgroundMode = BackgroundMode.perPlayer
          ..imageOpacity = 100
          ..focus = false
          ..frameOpacity = 60
          ..barOpacity = 30
          ..historyOpacity = 0
          ..zoneMarks = ZoneMarks.strong
          ..animations = false;

        await settings.resetLook();
        final fresh = AppSettings(prefs);
        for (final s in [settings, fresh]) {
          expect(s.theme, AppTheme.classic);
          expect(s.skinId, Skin.oldSchool.id);
          expect(s.showHistory, isFalse);
          expect(s.backgroundMode, BackgroundMode.screen);
          expect(s.imageOpacity, 60);
          expect(s.focus, s.look.focusByDefault);
          expect(s.frameOpacity, 92);
          expect(s.barOpacity, s.look.defaultBarOpacity);
          expect(s.historyOpacity, s.look.defaultHistoryOpacity);
          expect(s.zoneMarks, ZoneMarks.none);
          expect(s.animations, isTrue);
        }
      },
    );

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
      // Por defecto (lo de Ajustes), para que al reiniciar siga en 5.
      final timer = RoundTimer(prefs, clock: () => now)
        ..setDefaults(TimerMode.countdown, const Duration(minutes: 5))
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

  group('Reloj de ajedrez', () {
    late DateTime now;
    late SharedPreferences prefs;

    setUp(() async {
      now = DateTime(2026, 11, 3, 18);
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    RoundTimer chessTimer({int minutes = 50}) {
      final timer = RoundTimer(
        prefs,
        mode: TimerMode.chess,
        roundLength: Duration(minutes: minutes),
        clock: () => now,
      );
      addTearDown(timer.dispose);
      return timer;
    }

    test('reparte la ronda y lo arranca quien no empieza', () {
      final timer = chessTimer(minutes: 45);
      expect(timer.leftFor(Seat.top), const Duration(minutes: 22, seconds: 30));
      expect(timer.turn, isNull);

      // Desde la hoja no se puede arrancar: no se sabe a quién le toca.
      timer.start();
      expect(timer.running, isFalse);

      // Pulsa el de arriba: empieza el de abajo.
      expect(timer.press(Seat.top), isTrue);
      expect(timer.turn, Seat.bottom);
      now = now.add(const Duration(minutes: 3));
      expect(
        timer.leftFor(Seat.bottom),
        const Duration(minutes: 19, seconds: 30),
      );
      expect(timer.leftFor(Seat.top), const Duration(minutes: 22, seconds: 30));
      expect(timer.totalLeft, const Duration(minutes: 42));
    });

    test('solo vale el botón del que tiene el turno', () {
      final timer = chessTimer()..press(Seat.top);
      now = now.add(const Duration(minutes: 1));
      expect(timer.press(Seat.top), isFalse); // ya ha pasado
      expect(timer.turn, Seat.bottom);

      expect(timer.press(Seat.bottom), isTrue);
      expect(timer.turn, Seat.top);
      now = now.add(const Duration(minutes: 2));
      expect(timer.leftFor(Seat.bottom), const Duration(minutes: 24));
      expect(timer.leftFor(Seat.top), const Duration(minutes: 23));
    });

    test('la pausa para a los dos y sigue el mismo', () {
      final timer = chessTimer()..press(Seat.bottom); // empieza arriba
      now = now.add(const Duration(minutes: 5));
      timer.pause();
      now = now.add(const Duration(minutes: 10)); // en pausa no cuenta
      expect(timer.press(Seat.top), isFalse); // en pausa no pasa el turno
      expect(timer.leftFor(Seat.top), const Duration(minutes: 20));

      timer.start();
      expect(timer.turn, Seat.top);
      now = now.add(const Duration(minutes: 1));
      expect(timer.leftFor(Seat.top), const Duration(minutes: 19));
      expect(timer.leftFor(Seat.bottom), const Duration(minutes: 25));
    });

    testWidgets('quien se pasa sigue contando y avisa una vez', (tester) async {
      var flags = 0;
      // Sin el addTearDown de chessTimer: hay que pararlo antes de que acabe
      // el test, o su temporizador quedaría pendiente.
      final timer = RoundTimer(
        prefs,
        mode: TimerMode.chess,
        roundLength: const Duration(minutes: 10),
        clock: () => now,
      )..onFinished = () => flags++;
      timer.press(Seat.top);
      now = now.add(const Duration(minutes: 5, seconds: 42));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(timer.running, isTrue);
      expect(timer.overtime(Seat.bottom), isTrue);
      expect(formatSignedClock(timer.leftFor(Seat.bottom)), '−0:42');
      expect(flags, 1);

      // Pasa el turno y al de arriba también se le acaba: otro aviso.
      timer.press(Seat.bottom);
      now = now.add(const Duration(minutes: 6));
      await tester.pump(const Duration(seconds: 1));
      expect(flags, 2);
      expect(formatSignedClock(timer.totalLeft), '−1:42');
      timer.dispose();
    });

    test('poco tiempo a falta de 2 minutos', () {
      final timer = chessTimer(minutes: 10)..press(Seat.top);
      now = now.add(const Duration(minutes: 2, seconds: 59));
      expect(timer.warningFor(Seat.bottom), isFalse);
      now = now.add(const Duration(seconds: 1));
      expect(timer.warningFor(Seat.bottom), isTrue);
      expect(timer.warningFor(Seat.top), isFalse);
    });

    test('sobrevive a cerrar la app y se reinicia entero', () {
      final timer = chessTimer()..press(Seat.top);
      now = now.add(const Duration(minutes: 4));
      timer.press(Seat.bottom);
      now = now.add(const Duration(minutes: 1));

      final reopened = chessTimer();
      expect(reopened.turn, Seat.top);
      expect(reopened.running, isTrue);
      expect(reopened.leftFor(Seat.bottom), const Duration(minutes: 21));
      expect(reopened.leftFor(Seat.top), const Duration(minutes: 24));

      reopened.reset();
      expect(reopened.turn, isNull);
      expect(reopened.started, isFalse);
      expect(reopened.leftFor(Seat.bottom), const Duration(minutes: 25));
    });

    test('lo de Ajustes no toca el reloj empezado: llega al reiniciar', () {
      final timer = RoundTimer(prefs, clock: () => now)..start();
      addTearDown(timer.dispose);
      now = now.add(const Duration(minutes: 5));
      timer.setDefaults(TimerMode.chess, const Duration(minutes: 40));
      expect(timer.mode, TimerMode.countdown);
      expect(timer.roundLength, const Duration(minutes: 50));
      expect(timer.remaining, const Duration(minutes: 45));

      // Cerrar y abrir la app tampoco lo cambia.
      final reopened = RoundTimer(
        prefs,
        mode: TimerMode.chess,
        roundLength: const Duration(minutes: 40),
        clock: () => now,
      );
      addTearDown(reopened.dispose);
      expect(reopened.mode, TimerMode.countdown);
      expect(reopened.roundLength, const Duration(minutes: 50));

      reopened.reset();
      expect(reopened.mode, TimerMode.chess);
      expect(reopened.roundLength, const Duration(minutes: 40));
      expect(reopened.leftFor(Seat.top), const Duration(minutes: 20));
    });

    test('sin empezar, lo de Ajustes llega al momento', () {
      final timer = RoundTimer(prefs, clock: () => now);
      addTearDown(timer.dispose);
      timer.setDefaults(TimerMode.chess, const Duration(minutes: 30));
      expect(timer.mode, TimerMode.chess);
      expect(timer.share, const Duration(minutes: 15));
    });

    test('fuera del modo ajedrez los botones no hacen nada', () {
      final timer = RoundTimer(prefs, clock: () => now);
      addTearDown(timer.dispose);
      expect(timer.press(Seat.top), isFalse);
      expect(timer.started, isFalse);
    });

    test('desactivado por defecto; al quitarlo vuelve a la cuenta atrás', () {
      final settings = AppSettings(prefs);
      expect(settings.chessEnabled, isFalse);
      settings
        ..chessEnabled = true
        ..timerMode = TimerMode.chess;
      settings.chessEnabled = false;
      expect(settings.timerMode, TimerMode.countdown);
    });

    testWidgets('en la hoja de la barra, Ajedrez solo si está activado', (
      tester,
    ) async {
      final settings = AppSettings(prefs);
      final timer = RoundTimer(prefs, clock: () => now)..start();
      now = now.add(const Duration(minutes: 5));
      timer.pause();
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  showTimerSheet(context, timer: timer, settings: settings),
              child: const Text('Reloj'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Reloj'));
      await tester.pumpAndSettle();
      expect(find.text('Ajedrez'), findsNothing);

      settings.chessEnabled = true;
      await tester.pumpAndSettle();
      // Con el reloj empezado, pasar a ajedrez pregunta y lo reinicia.
      await tester.tap(find.text('Ajedrez'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(timer.mode, TimerMode.countdown);
      expect(timer.started, isTrue);

      await tester.tap(find.text('Ajedrez'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reiniciar y cambiar'));
      await tester.pumpAndSettle();
      expect(timer.mode, TimerMode.chess);
      expect(timer.started, isFalse);
      // Lo de Ajustes no cambia: es lo de por defecto.
      expect(settings.timerMode, TimerMode.countdown);
      timer.dispose();
    });
  });

  test(
    'con el reloj de ajedrez la barra enseña siempre el temporizador',
    () async {
      SharedPreferences.setMockInitialValues({});
      final settings = AppSettings(await SharedPreferences.getInstance())
        ..showTimer = false;
      expect(settings.showTimer, isFalse);
      settings.timerMode = TimerMode.chess;
      expect(settings.showTimer, isTrue);
      expect(settings.chessClock, isTrue);
    },
  );

  test('Old School lleva los marcos azul y blanco', () {
    expect(Skin.oldSchool.cardFrames, (CardFrame.azul, CardFrame.blanco));
    expect(
      Skin.alicante.cardFrames,
      CardFrame.forPlayers(Skin.alicante.top, Skin.alicante.bottom),
    );
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

  test('la barra copia la caja de texto de cada tierra doble', () {
    const f = CardFrame.values;
    // (línea de fuera, del medio, primer cuadrado), medido en Revised.
    final duals = {
      'Tundra': (f[1], f[0], f[1], f[1]),
      'Underground Sea': (f[0], f[2], f[0], f[2]),
      'Badlands': (f[2], f[3], f[3], f[3]),
      'Taiga': (f[3], f[4], f[3], f[3]),
      'Savannah': (f[4], f[1], f[4], f[1]),
      'Scrubland': (f[1], f[2], f[2], f[2]),
      'Volcanic Island': (f[0], f[3], f[3], f[3]),
      'Bayou': (f[2], f[4], f[4], f[2]),
      'Plateau': (f[3], f[1], f[3], f[3]),
      'Tropical Island': (f[4], f[0], f[4], f[0]),
    };
    expect(f.take(5), [
      CardFrame.azul,
      CardFrame.blanco,
      CardFrame.negro,
      CardFrame.rojo,
      CardFrame.verde,
    ]);
    for (final MapEntry(key: name, value: (a, b, line, band))
        in duals.entries) {
      // Da igual quién esté arriba.
      for (final d in [CardFrame.dual(a, b), CardFrame.dual(b, a)]) {
        expect(d.line, line, reason: name);
        expect({d.line, d.middle}, {a, b}, reason: name);
        expect(d.band, band, reason: name);
        expect({d.band, d.other}, {a, b}, reason: name);
      }
    }
  });

  test('ningún jugador lleva el marco de la barra', () {
    // Todos los colores, de 12 en 12 grados y con poca y mucha luz y color,
    // y también los dos jugadores con el mismo.
    final colors = [
      for (var h = 0.0; h < 360; h += 12)
        for (final s in [0.1, 0.6, 1.0])
          for (final v in [0.1, 0.5, 0.9])
            HSVColor.fromAHSV(1, h, s, v).toColor(),
    ];
    for (final top in colors) {
      for (final bottom in [
        top,
        colors[(colors.indexOf(top) * 7) % colors.length],
      ]) {
        final (a, b) = CardFrame.forPlayers(top, bottom);
        expect([a, b], isNot(contains(CardFrame.bar)));
        expect(a, isNot(b));
      }
    }
    for (final skin in [...Skin.presets, Skin.customDefault]) {
      final (a, b) = skin.cardFrames;
      expect([a, b], isNot(contains(CardFrame.bar)), reason: skin.name);
    }
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
    // Con tono en las mitades, para comprobar que cubre el panel.
    final settings = AppSettings(prefs)..zoneMarks = ZoneMarks.soft;
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

  testWidgets('Ajustes abre «Acerca de» con la versión y el aviso legal', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'mtglifecounter',
      packageName: 'mtg.premodern.alicante.lifecounter',
      version: '1.2.3',
      buildNumber: '4',
      buildSignature: '',
    );
    final prefs = await SharedPreferences.getInstance();
    final settings = AppSettings(prefs);
    final game = GameState();
    final storage = GameStorage(prefs, game);
    final timer = RoundTimer(prefs);

    await tester.binding.setSurfaceSize(const Size(400, 800));
    await tester.pumpWidget(
      MyApp(settings: settings, game: game, storage: storage, timer: timer),
    );
    await tester.tap(find.byTooltip('Ajustes'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Acerca de'));
    await tester.pumpAndSettle();

    expect(find.text('Versión 1.2.3 (4)'), findsOneWidget);
    expect(find.textContaining('greven.il'), findsOneWidget);
    for (final link in communityLinks) {
      expect(Uri.parse(link.url).scheme, 'https');
    }
    await tester.scrollUntilVisible(find.text('Old School MTG Channel'), 200);
    expect(find.text('Full Tapped'), findsOneWidget);
    expect(find.textContaining('Política de contenido de fans'), findsOne);
    await tester.scrollUntilVisible(
      find.text('Ver licencias de software'),
      200,
    );
    expect(find.text('Ver licencias de software'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('los minutos van de uno en uno y siguen al mantener pulsado', (
    tester,
  ) async {
    var minutes = 50;
    late StateSetter refresh;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              refresh = setState;
              final step = minutes < 60
                  ? () => setState(() => minutes++)
                  : null;
              return HoldToRepeat(
                onStep: step,
                label: 'Un minuto más',
                child: IconButton(onPressed: step, icon: const Icon(Icons.add)),
              );
            },
          ),
        ),
      ),
    );
    final button = find.byType(IconButton);

    // Un toque, un minuto.
    await tester.tap(button);
    await tester.pump();
    expect(minutes, 51);

    // Mantenido: al medio segundo empieza y sigue mientras no se suelte.
    final gesture = await tester.startGesture(tester.getCenter(button));
    await tester.pump(const Duration(milliseconds: 520));
    expect(minutes, 52);
    for (var i = 0; i < 3; i++) {
      await tester.pump(HoldToRepeat.slow);
    }
    expect(minutes, 55);
    await gesture.up();
    await tester.pump(const Duration(seconds: 1));
    // Al soltar para, y no suma el toque de más.
    expect(minutes, 55);

    // Se para solo en el límite.
    refresh(() => minutes = 58);
    final again = await tester.startGesture(tester.getCenter(button));
    // A pasos cortos, para que entre medias se redibuje como en el móvil.
    for (var i = 0; i < 40; i++) {
      await tester.pump(HoldToRepeat.fast);
    }
    expect(minutes, 60);
    await again.up();
    await tester.pump();
  });
}
