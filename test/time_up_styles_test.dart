// Los avisos de fin de ronda: que cada uno se dibuja entero en todo momento
// sin desbordarse, que se acaba y no deja nada pidiendo fotogramas, y qué se
// puede elegir con cada skin.
//
// Con `--dart-define=SHOTS=<carpeta>` guarda una captura de cada aviso en
// varios momentos.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtglifecounter/app_settings.dart';
import 'package:mtglifecounter/look.dart';
import 'package:mtglifecounter/time_up.dart';
import 'package:mtglifecounter/time_up_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'layout_test.dart' show loadFonts, shotsDir;

Future<void> _precache(WidgetTester tester, BuildContext context) async {
  final assets = [
    ...Directory('assets/images/avisos').listSync(),
    ...Directory('assets/images/marcos').listSync(),
    File('assets/images/sorteos/moneda-cara.jpg'),
  ].whereType<File>().map((f) => f.path.replaceAll(r'\', '/'));
  await tester.runAsync(() async {
    for (final asset in assets) {
      await precacheImage(AssetImage(asset), context);
    }
  });
}

Future<void> _save(WidgetTester tester, GlobalKey key, String name) async {
  if (shotsDir.isEmpty) return;
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1.5);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    File('$shotsDir/aviso_$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  useGoogleFonts = false;
  setUpAll(loadFonts);

  final looks = {
    'original': Look.of(AppTheme.original, ModernVariant.glass),
    'oldborder': Look.of(AppTheme.classic, ModernVariant.glass),
  };

  // Con «No se va solo» el aviso se para a los 5/6 y se queda así hasta que
  // lo tocan: para entonces ya no puede quedar nada a medias (una onda a
  // medio desvanecer, un trozo en el aire). Lo que se ve a los 5/6 tiene que
  // ser lo mismo que la escena entera (TimeUpScene.still).
  for (final style in TimeUpStyle.values) {
    testWidgets('${style.name} · se queda quieto y entero al pararse', (
      tester,
    ) async {
      final key = GlobalKey();
      var t = TimeUpScene.still;
      late StateSetter setT;
      await tester.binding.setSurfaceSize(const Size(360, 360));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              setT = setState;
              return RepaintBoundary(
                key: key,
                child: ColoredBox(
                  color: Colors.black,
                  child: TimeUpScene(
                    style: style,
                    t: t,
                    look: looks['original']!,
                    lives: (20, 17),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await _precache(tester, key.currentContext!);
      Future<List<int>> pixels() async {
        await tester.pump();
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        return (await tester.runAsync(() async {
          final image = await boundary.toImage();
          final data = await image.toByteData();
          image.dispose();
          return data!.buffer.asUint8List().toList();
        }))!;
      }

      final whole = await pixels();
      setT(() => t = 5 / 6);
      final stopped = await pixels();
      var different = 0;
      for (var i = 0; i < whole.length; i++) {
        if ((whole[i] - stopped[i]).abs() > 8) different++;
      }
      expect(
        different,
        0,
        reason: 'a los 5/6 aún se mueve algo ($different bytes distintos)',
      );
    });
  }

  // El número de episodio de Tapeados es lo que duraba la ronda.
  for (final (minutes, title) in [
    (30, '30."SE ACABÓ LA RONDA"'),
    (null, '50."SE ACABÓ LA RONDA"'),
  ]) {
    testWidgets('Tapeados con ${minutes ?? 'sin'} minutos dice $title', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TimeUpScene(
            style: TimeUpStyle.fullTapped,
            t: TimeUpScene.still,
            look: looks['original']!,
            roundMinutes: minutes,
          ),
        ),
      );
      expect(find.text(title), findsOneWidget);
    });
  }

  for (final style in TimeUpStyle.values) {
    for (final MapEntry(key: lookName, value: look) in looks.entries) {
      testWidgets('${style.name} · $lookName · se dibuja sin desbordarse', (
        tester,
      ) async {
        tester.view
          ..physicalSize = const Size(412, 440)
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final key = GlobalKey();
        var t = 0.0;
        late StateSetter setT;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              backgroundColor: const Color(0xFF2A2A30),
              body: RepaintBoundary(
                key: key,
                child: StatefulBuilder(
                  builder: (context, setState) {
                    setT = setState;
                    return TimeUpScene(
                      style: style,
                      t: t,
                      look: look,
                      lives: (20, 17),
                    );
                  },
                ),
              ),
            ),
          ),
        );
        await _precache(tester, key.currentContext!);
        for (final moment in [
          0.02,
          0.1,
          0.2,
          0.36,
          0.5,
          0.7,
          0.75,
          TimeUpScene.still,
          0.95,
        ]) {
          setT(() => t = moment);
          await tester.pump();
          expect(tester.takeException(), isNull, reason: 'en t = $moment');
          if (lookName == 'oldborder' || style != TimeUpStyle.stamp) {
            await _save(
              tester,
              key,
              '${style.name}_${lookName}_${(moment * 100).round()}',
            );
          }
        }
      });
    }

    testWidgets('${style.name} · se va solo y no deja fotogramas', (
      tester,
    ) async {
      var done = false;
      await tester.pumpWidget(
        MaterialApp(
          home: TimeUpOverlay(
            style: style,
            look: looks['original']!,
            flipTop: true,
            animate: true,
            lives: (20, 17),
            onDone: () => done = true,
          ),
        ),
      );
      // El primer fotograma arranca la animación.
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(TimeUpOverlay.duration);
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(done, isTrue);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  }

  testWidgets('como los colores, solo se elige con la skin personalizada', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'skin': 'oldschool'});
    final settings = AppSettings(await SharedPreferences.getInstance());
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ListenableBuilder(
              listenable: settings,
              builder: (context, _) => TimeUpPicker(settings: settings),
            ),
          ),
        ),
      ),
    );
    // Con una skin de comunidad, solo el suyo, que al tocarlo se ve.
    expect(find.byType(TimeUpCard), findsOneWidget);
    expect(settings.timeUpStyle, TimeUpStyle.oldSchool);
    await tester.tap(find.byType(TimeUpCard));
    await tester.pump();
    expect(settings.timeUpStyle, TimeUpStyle.oldSchool);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(TimeUpOverlay.duration);

    // Con la personalizada salen todos, también los de las comunidades.
    settings.skinId = 'custom';
    await tester.pump();
    expect(find.byType(TimeUpCard), findsNWidgets(TimeUpStyle.values.length));
    expect(settings.timeUpStyle, TimeUpStyle.stamp);

    await tester.ensureVisible(find.text(TimeUpStyle.bell.label));
    await tester.pump();
    await tester.tap(find.text(TimeUpStyle.bell.label));
    await tester.pump();
    expect(settings.timeUpStyle, TimeUpStyle.bell);
    // Al tocarlo se ve una vez y se para solo.
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(TimeUpOverlay.duration);
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);

    // También el de una comunidad. Con otra skin va el de esa skin, y al
    // volver a la personalizada sigue el elegido.
    await tester.ensureVisible(find.text(TimeUpStyle.oldSchool.label));
    await tester.tap(find.text(TimeUpStyle.oldSchool.label));
    await tester.pump();
    expect(settings.timeUpStyle, TimeUpStyle.oldSchool);
    settings.skinId = 'alicante';
    expect(settings.timeUpStyle, TimeUpStyle.defaultFor('alicante'));
    settings.skinId = 'custom';
    expect(settings.timeUpStyle, TimeUpStyle.oldSchool);
    await tester.pump(TimeUpOverlay.duration);
  });

  test('cada skin lleva el suyo si no se ha elegido otro', () {
    expect(TimeUpStyle.defaultFor('oldschool'), TimeUpStyle.oldSchool);
    expect(TimeUpStyle.defaultFor('alicante'), TimeUpStyle.alicante);
    expect(TimeUpStyle.defaultFor('fulltapped'), TimeUpStyle.fullTapped);
    expect(TimeUpStyle.defaultFor('custom'), TimeUpStyle.stamp);
  });
}
