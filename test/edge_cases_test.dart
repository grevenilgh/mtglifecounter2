// Casos límite de la lógica: lo que pasa en los bordes del rango de vidas,
// con datos guardados que no se pueden leer, con el reloj del móvil cambiado
// y con toques rápidos.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtglifecounter/app_settings.dart';
import 'package:mtglifecounter/game_state.dart';
import 'package:mtglifecounter/look.dart';
import 'package:mtglifecounter/main.dart';
import 'package:mtglifecounter/number_stepper.dart';
import 'package:mtglifecounter/player_counter.dart';
import 'package:mtglifecounter/round_timer.dart';
import 'package:mtglifecounter/skin.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  useGoogleFonts = false;

  group('PlayerState en los bordes', () {
    test('en 999 y en −999 no se mueve ni apunta nada', () {
      final player = PlayerState();
      expect(player.change(kMaxLife - kInitialLife), isTrue);
      player.commit();
      expect(player.change(1), isFalse);
      player.commit();
      expect(player.history, ['+979 = 999']);

      expect(player.change(-1998), isTrue);
      expect(player.change(-1), isFalse);
      expect(player.life, kMinLife);
      expect(player.pending, -1998);
    });

    test('un salto que se pasaría del límite no se aplica a medias', () {
      final player = PlayerState()..change(975);
      expect(player.change(10), isFalse);
      expect(player.life, 995);
    });

    test('sumar y restar lo mismo antes de apuntar no deja entrada', () {
      final player = PlayerState()
        ..change(3)
        ..change(-3)
        ..commit();
      expect(player.history, isEmpty);
    });

    test('una vida guardada fuera de rango se recorta al cargarla', () {
      final player = PlayerState()
        ..restore({
          'life': 5000,
          'committedLife': 5000,
          'history': ['+4980 = 5000'],
        });
      expect(player.life, kMaxLife);
      // Y se puede seguir jugando: antes no dejaba ni restar.
      expect(player.change(-1), isTrue);
    });
  });

  group('GameStorage con datos que no se pueden leer', () {
    for (final saved in [
      'basura',
      '[]',
      '{"top": 5}',
      '{"top": {"life": "veinte"}}',
      '{"top": {"history": [1, 2]}}',
      // El de arriba se puede leer, el de abajo no: no se carga a medias.
      '{"top": {"life": 7, "committedLife": 7}, "bottom": 5, "rotated": true}',
    ]) {
      test(saved, () async {
        SharedPreferences.setMockInitialValues({'game': saved});
        final prefs = await SharedPreferences.getInstance();
        final game = GameState();
        GameStorage(prefs, game).load();
        expect(game.top.life, kInitialLife);
        expect(game.bottom.life, kInitialLife);
        expect(game.top.history, isEmpty);
        expect(game.rotated, isFalse);
        expect(prefs.getString('game'), isNull);
      });
    }
  });

  group('AppSettings con datos que no se pueden leer', () {
    for (final saved in ['[]', '{"background": 3}', '{"top": "rojo"}', '{']) {
      test('skin personalizada $saved', () async {
        SharedPreferences.setMockInitialValues({
          'customSkin': saved,
          'skin': 'custom',
        });
        final prefs = await SharedPreferences.getInstance();
        final settings = AppSettings(prefs);
        expect(settings.skin.id, Skin.customDefault.id);
        expect(settings.skin.top, Skin.customDefault.top);
      });
    }

    test('foto de fondo que no es base64', () async {
      SharedPreferences.setMockInitialValues({'backgroundPhoto': '%%%'});
      final prefs = await SharedPreferences.getInstance();
      expect(AppSettings(prefs).backgroundPhoto, isNull);
      expect(prefs.getString('backgroundPhoto'), isNull);
    });

    test('los ajustes con rango se recortan', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settings = AppSettings(prefs)
        ..roundMinutes = 0
        ..imageOpacity = 150
        ..frameOpacity = 0
        ..barOpacity = -5
        ..historyOpacity = 101;
      expect(settings.roundMinutes, AppSettings.minRoundMinutes);
      expect(settings.imageOpacity, 100);
      expect(settings.frameOpacity, AppSettings.minFrameOpacity);
      expect(settings.barOpacity, AppSettings.minBarOpacity);
      expect(settings.historyOpacity, 100);
      settings.roundMinutes = 1000;
      expect(settings.roundMinutes, AppSettings.maxRoundMinutes);
    });
  });

  group('formatClock', () {
    for (final (seconds, text) in [
      (0, '0:00'),
      (9, '0:09'),
      (59, '0:59'),
      (60, '1:00'),
      (3599, '59:59'),
      (3600, '1:00:00'),
      (3661, '1:01:01'),
      (360000, '100:00:00'),
    ]) {
      test('$seconds s → $text', () {
        expect(formatClock(Duration(seconds: seconds)), text);
      });
    }
  });

  group('RoundTimer con el reloj del móvil cambiado', () {
    late DateTime now;
    late SharedPreferences prefs;

    setUp(() async {
      now = DateTime(2026, 10, 31, 18);
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('si el reloj va hacia atrás no sale tiempo negativo', () {
      final timer = RoundTimer(
        prefs,
        mode: TimerMode.stopwatch,
        clock: () => now,
      );
      addTearDown(timer.dispose);
      timer.start();
      now = now.subtract(const Duration(hours: 1));
      expect(timer.elapsed, Duration.zero);
      expect(formatClock(timer.shown), '0:00');

      timer.mode = TimerMode.countdown;
      expect(timer.shown, timer.roundLength);
    });

    test('al volver a abrir la app con el reloj atrasado', () {
      final first = RoundTimer(prefs, clock: () => now)..start();
      first.dispose();
      now = now.subtract(const Duration(minutes: 30));
      final reopened = RoundTimer(prefs, clock: () => now);
      addTearDown(reopened.dispose);
      expect(reopened.elapsed, Duration.zero);
      expect(reopened.shown, const Duration(minutes: 50));
    });

    testWidgets('pasar de cronómetro a cuenta atrás con más tiempo que la '
        'ronda', (tester) async {
      var finished = 0;
      final timer = RoundTimer(
        prefs,
        mode: TimerMode.stopwatch,
        clock: () => now,
      )..onFinished = () => finished++;
      timer.start();
      now = now.add(const Duration(minutes: 60));
      timer.mode = TimerMode.countdown;
      await tester.pump(const Duration(seconds: 1));
      expect(timer.finished, isTrue);
      expect(finished, 1);
      // Al acabar, la cuenta atrás se queda en la duración de la ronda: si se
      // vuelve al cronómetro, enseña 50:00 y no los 60 minutos que llevaba.
      timer.mode = TimerMode.stopwatch;
      expect(timer.shown, const Duration(minutes: 50));
      expect(timer.running, isFalse);
      timer.dispose();
    });
  });

  group('NumberStepper', () {
    testWidgets('no baja de 1 ni pasa de 99', (tester) async {
      var value = 1;
      final reset = ValueNotifier(false);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NumberStepper(
              resetNotifier: reset,
              onChanged: (v) => value = v,
            ),
          ),
        ),
      );
      final minus = find.byIcon(Icons.remove_circle);
      final plus = find.byIcon(Icons.add_circle);
      await tester.tap(minus);
      expect(value, 1);

      // Pulsación larga: de 10 en 10, sin pasarse.
      for (var i = 0; i < 8; i++) {
        await tester.longPress(plus);
        await tester.pump();
      }
      expect(value, 81);
      await tester.longPress(plus);
      await tester.pump();
      expect(value, 91);
      // De 91 no salta 10 (se pasaría de 99): la pulsación larga cuenta como
      // un toque normal.
      await tester.longPress(plus);
      await tester.pump();
      expect(value, 92);
      for (var i = 0; i < 20; i++) {
        await tester.tap(plus);
        await tester.pump();
      }
      expect(value, 99);
      expect(find.text('99'), findsOneWidget);

      await tester.longPress(minus);
      await tester.pump();
      expect(value, 89);

      reset.value = !reset.value;
      await tester.pump();
      expect(value, 1);
      expect(find.text('1'), findsOneWidget);
    });
  });

  group('la partida en la app', () {
    late SharedPreferences prefs;
    late AppSettings settings;
    late GameState game;
    late RoundTimer timer;

    Future<void> pumpApp(WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      settings = AppSettings(prefs)..showStepper = true;
      game = GameState();
      timer = RoundTimer(prefs);
      await tester.binding.setSurfaceSize(const Size(400, 860));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MyApp(
          settings: settings,
          game: game,
          storage: GameStorage(prefs, game),
          timer: timer,
        ),
      );
    }

    Future<void> finish(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
      timer.dispose();
    }

    Finder pip(int panel, {required bool plus}) {
      final pips = find.descendant(
        of: find.byType(PlayerCounter).at(panel),
        matching: find.byWidgetPredicate(
          (w) => w.runtimeType.toString() == '_Pip',
        ),
      );
      return plus ? pips.first : pips.last;
    }

    testWidgets('la cantidad por toque vale para un solo golpe', (
      tester,
    ) async {
      await pumpApp(tester);
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.byIcon(Icons.add_circle));
        await tester.pump();
      }
      await tester.tapAt(tester.getCenter(pip(1, plus: false)));
      await tester.pump();
      expect(game.bottom.life, 15);
      // El siguiente toque ya cuenta 1.
      await tester.tapAt(tester.getCenter(pip(1, plus: false)));
      await tester.pump(const Duration(milliseconds: 800));
      expect(game.bottom.life, 14);
      expect(game.bottom.history, ['-6 = 14']);
      await finish(tester);
    });

    testWidgets('reiniciar con un grupo a medias no deja entradas sueltas', (
      tester,
    ) async {
      await pumpApp(tester);
      await tester.tapAt(tester.getCenter(pip(0, plus: true)));
      await tester.pump(const Duration(milliseconds: 800));
      await tester.tapAt(tester.getCenter(pip(0, plus: true)));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byTooltip('Reiniciar partida'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aceptar'));
      await tester.pump(const Duration(milliseconds: 800));
      expect(game.top.life, kInitialLife);
      expect(game.top.history, isEmpty);
      expect(game.top.pending, 0);
      await finish(tester);
    });

    testWidgets('en 999 los toques no apuntan nada', (tester) async {
      await pumpApp(tester);
      game.top
        ..change(979)
        ..commit();
      await tester.pump();
      for (var i = 0; i < 5; i++) {
        await tester.tapAt(tester.getCenter(pip(0, plus: true)));
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pump(const Duration(milliseconds: 800));
      expect(game.top.life, 999);
      expect(game.top.history, ['+979 = 999']);
      await finish(tester);
    });

    testWidgets('muchos toques seguidos hacen una sola entrada', (
      tester,
    ) async {
      await pumpApp(tester);
      for (var i = 0; i < 50; i++) {
        await tester.tapAt(tester.getCenter(pip(1, plus: false)));
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(game.bottom.history, isEmpty);
      await tester.pump(const Duration(milliseconds: 800));
      expect(game.bottom.history, ['-50 = -30']);
      await finish(tester);
    });

    testWidgets('al pasar a segundo plano se guarda al momento', (
      tester,
    ) async {
      await pumpApp(tester);
      game.bottom
        ..change(-7)
        ..commit();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      final saved = jsonDecode(prefs.getString('game')!) as Map;
      expect((saved['bottom'] as Map)['life'], 13);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await finish(tester);
    });

    testWidgets('sin «recordar partida» no queda nada guardado', (
      tester,
    ) async {
      await pumpApp(tester);
      game.top.change(-3);
      settings.rememberGame = false;
      await tester.pump(const Duration(seconds: 1));
      expect(prefs.getString('game'), isNull);
      await finish(tester);
    });
  });
}
