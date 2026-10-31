// Pruebas de la pantalla en muchos tamaños: que no se desborde nada, que el
// número quepa entero, que la barra no tape los botones ni el número y que los
// toques sumen y resten donde toca.
//
// Con `--dart-define=SHOTS=<carpeta>` guarda además una captura de cada caso
// para revisarla a ojo:
//
//   flutter test test/layout_test.dart --dart-define=SHOTS=build/shots

import 'dart:io';
import 'dart:ui' as ui;

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtglifecounter/app_settings.dart';
import 'package:mtglifecounter/center_bar.dart';
import 'package:mtglifecounter/game_state.dart';
import 'package:mtglifecounter/look.dart';
import 'package:mtglifecounter/main.dart';
import 'package:mtglifecounter/player_counter.dart';
import 'package:mtglifecounter/round_timer.dart';
import 'package:mtglifecounter/timer_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String shotsDir = String.fromEnvironment('SHOTS');

/// Una pantalla: tamaño lógico y los márgenes de las barras del sistema.
class Screen {
  const Screen(
    this.name,
    this.width,
    this.height, {
    this.top = 24,
    this.bottom = 0,
    this.supported = true,
  });

  final String name;
  final double width;
  final double height;
  final double top;
  final double bottom;

  /// Si la app tiene que verse bien en ella. Las que no, se prueban para
  /// saber qué pasa, pero solo se exige que no se rompa nada.
  final bool supported;
}

const List<Screen> screens = [
  Screen('Fold cerrado 280x653', 280, 653),
  Screen('Muy pequeña 320x480', 320, 480, supported: false),
  Screen('iPhone SE 320x568', 320, 568, top: 20),
  Screen('Android pequeño 360x640', 360, 640),
  Screen('iPhone 8 375x667', 375, 667, top: 20),
  Screen('Android 20x9 360x800', 360, 800, bottom: 48),
  Screen('iPhone 14 390x844', 390, 844, top: 47, bottom: 34),
  Screen('Pixel 7 412x915', 412, 915, bottom: 24),
  Screen('iPhone Pro Max 430x932', 430, 932, top: 59, bottom: 34),
  Screen('Tablet 7 600x960', 600, 960),
  Screen('iPad 768x1024', 768, 1024, top: 20),
  Screen('iPad Pro 1024x1366', 1024, 1366, bottom: 20),
  Screen('Pantalla partida 360x380', 360, 380, supported: false),
  Screen('Horizontal 915x412', 915, 412, supported: false),
];

/// Los cuatro temas que se eligen en Ajustes.
const List<(String, AppTheme, ModernVariant)> themes = [
  ('De siempre', AppTheme.original, ModernVariant.glass),
  ('Cristal', AppTheme.modern, ModernVariant.glass),
  ('Tarjetas', AppTheme.modern, ModernVariant.cards),
  ('Old Border', AppTheme.classic, ModernVariant.glass),
];

/// Lo que hay en la partida al hacer la captura.
class Scenario {
  const Scenario(this.name, this.setup, {this.textScale = 1});

  final String name;
  final double textScale;
  final void Function(TestApp app) setup;
}

final List<Scenario> scenarios = [
  Scenario('inicio', (_) {}),
  // Lo más largo que puede salir: −999 y 999, historial lleno de entradas
  // de cuatro cifras, una burbuja de +1998, la cantidad por toque y un
  // cronómetro de más de 100 horas. Y el panel de arriba girado.
  Scenario('extremo', (app) {
    app.settings
      ..showStepper = true
      ..timerMode = TimerMode.stopwatch;
    app.timer.mode = TimerMode.stopwatch;
    final top = app.game.top;
    for (var i = 0; i < 30; i++) {
      top
        ..change(i.isEven ? -987 : 987)
        ..commit();
    }
    top
      ..change(-1019)
      ..commit();
    app.game.bottom
      ..change(-1019)
      ..commit()
      ..change(1998);
    app.game.toggleRotation();
    app.timer.start();
    app.now = app.now.add(const Duration(hours: 123, minutes: 45, seconds: 6));
    app.timer.pause();
  }),
  // El tamaño de letra del sistema al máximo (accesibilidad).
  Scenario('texto 200%', textScale: 2, (app) {
    app.settings.showStepper = true;
    app.game.top
      ..change(-13)
      ..commit()
      ..change(-2);
  }),
];

class TestApp {
  TestApp(this.settings, this.game, this.timer);

  final AppSettings settings;
  final GameState game;
  final RoundTimer timer;
  DateTime now = DateTime(2026, 10, 31, 18);
}

/// Carga Roboto y los iconos del SDK de Flutter para que el texto mida lo
/// que mide de verdad (sin esto los tests pintan cada letra como un
/// cuadrado). Las fuentes de Google Fonts no están sin red: se prueban con
/// las más parecidas que trae el SDK.
Future<void> loadFonts() async {
  final root =
      Platform.environment['FLUTTER_ROOT'] ??
      () {
        final exe = Platform.resolvedExecutable.replaceAll(r'\', '/');
        final i = exe.indexOf('/bin/cache/');
        return i < 0 ? null : exe.substring(0, i);
      }();
  if (root == null) return;
  final dir = '$root/bin/cache/artifacts/material_fonts';
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final name in files) {
      final file = File('$dir/$name');
      if (!file.existsSync()) continue;
      loader.addFont(
        Future.value(ByteData.sublistView(file.readAsBytesSync())),
      );
    }
    await loader.load();
  }

  await load('Roboto', [
    'roboto-regular.ttf',
    'roboto-medium.ttf',
    'roboto-bold.ttf',
    'roboto-black.ttf',
  ]);
  await load('MaterialIcons', ['materialicons-regular.otf']);
  await load('Barlow Condensed', ['robotocondensed-bold.ttf']);
  await load('Outfit', ['roboto-bold.ttf']);
  await load('Vollkorn', ['roboto-black.ttf']);
}

Future<TestApp> pumpApp(
  WidgetTester tester,
  Screen screen,
  (String, AppTheme, ModernVariant) theme, {
  Scenario? scenario,
}) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = Size(screen.width, screen.height)
    ..padding = FakeViewPadding(top: screen.top, bottom: screen.bottom)
    ..viewPadding = FakeViewPadding(top: screen.top, bottom: screen.bottom);
  addTearDown(tester.view.reset);
  final textScale = scenario?.textScale ?? 1;
  if (textScale != 1) {
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }

  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final settings = AppSettings(prefs)
    ..theme = theme.$2
    ..modernVariant = theme.$3;
  late final TestApp app;
  final timer = RoundTimer(prefs, clock: () => app.now);
  app = TestApp(settings, GameState(), timer);
  scenario?.setup(app);
  final storage = GameStorage(prefs, app.game);

  await tester.pumpWidget(
    MyApp(settings: settings, game: app.game, storage: storage, timer: timer),
  );
  await tester.pump();
  if (shotsDir.isNotEmpty) await _precacheImages(tester);
  return app;
}

/// Desmonta la app y deja que acaben los temporizadores pendientes.
Future<void> tearDownApp(WidgetTester tester, TestApp app) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 2));
  app.timer.dispose();
}

/// Junta los errores de Flutter (los desbordamientos, sobre todo) en vez de
/// parar en el primero.
Future<List<String>> collectErrors(Future<void> Function() body) async {
  final errors = <String>[];
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    // Con --dart-define=VERBOSE=true se ve el error entero, con el widget.
    if (const bool.fromEnvironment('VERBOSE')) debugPrint('$details');
    final text = details.exceptionAsString().split('\n').first;
    if (!errors.contains(text)) errors.add(text);
  };
  try {
    await body();
  } finally {
    FlutterError.onError = previous;
  }
  return errors;
}

Finder _private(String type) =>
    find.byWidgetPredicate((w) => w.runtimeType.toString() == type);

Rect _globalRect(RenderBox box, Rect local) =>
    MatrixUtils.transformRect(box.getTransformTo(null), local);

bool _overlaps(Rect a, Rect b) {
  final i = a.intersect(b);
  return i.width > 0.5 && i.height > 0.5;
}

bool _contains(Rect outer, Rect inner) =>
    inner.left >= outer.left - 0.5 &&
    inner.top >= outer.top - 0.5 &&
    inner.right <= outer.right + 0.5 &&
    inner.bottom <= outer.bottom + 0.5;

/// Lo que se ha medido en la pantalla del contador.
class CounterReport {
  final List<String> issues = [];
  final List<double> numberSizes = [];
  double smallestButton = double.infinity;

  @override
  String toString() =>
      'número ${numberSizes.map((s) => s.round()).join('/')} px · '
      'botón más pequeño ${smallestButton.round()} px'
      '${issues.isEmpty ? '' : ' · ${issues.join('; ')}'}';
}

CounterReport checkCounter(WidgetTester tester) {
  final report = CounterReport();
  final view = tester.view;
  final screenRect = Offset.zero & view.physicalSize / view.devicePixelRatio;
  final barFinder = find.byType(CenterBar);
  final bar = tester.getRect(
    find.descendant(of: barFinder, matching: find.byType(Container)).first,
  );
  if (!_contains(screenRect, bar)) report.issues.add('la barra se sale');

  // Botones de la barra: lo pequeños que quedan tras encogerla.
  for (final finder in [
    find.descendant(of: barFinder, matching: find.byType(IconButton)),
    find.descendant(of: barFinder, matching: find.byType(InkWell)),
    find.descendant(of: barFinder, matching: find.byType(TimerButton)),
  ]) {
    for (final element in finder.evaluate()) {
      final box = element.renderObject! as RenderBox;
      final rect = _globalRect(box, Offset.zero & box.size);
      final side = rect.shortestSide;
      if (side < report.smallestButton) report.smallestButton = side;
    }
  }
  // El tamaño de los botones solo se apunta: con la cantidad por toque y el
  // reloj a la vez la barra se encoge en los móviles estrechos, y eso es
  // cosa del diseño, no un fallo.

  for (final (i, name) in ['arriba', 'abajo'].indexed) {
    final panelFinder = find.byType(PlayerCounter).at(i);
    final panel = tester.getRect(panelFinder);
    if (!_contains(screenRect, panel)) report.issues.add('$name: se sale');

    // El número: el tamaño al que lo ha dejado AutoSizeText y si cabe entero.
    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(
        of: find.descendant(
          of: panelFinder,
          matching: find.byType(AutoSizeText),
        ),
        matching: find.byType(RichText),
      ),
    );
    report.numberSizes.add(paragraph.text.style?.fontSize ?? 0);
    final textSize = paragraph.textSize;
    if (paragraph.didExceedMaxLines ||
        textSize.width > paragraph.size.width + 0.5 ||
        textSize.height > paragraph.size.height + 0.5) {
      report.issues.add(
        '$name: el número no cabe '
        '(${textSize.width.round()}x${textSize.height.round()} en '
        '${paragraph.size.width.round()}x${paragraph.size.height.round()})',
      );
    }
    final glyphs = _globalRect(
      paragraph,
      Rect.fromLTWH(
        (paragraph.size.width - textSize.width) / 2,
        0,
        textSize.width,
        textSize.height,
      ),
    );
    if (!_contains(panel, glyphs)) {
      report.issues.add('$name: el número se sale del panel');
    }
    if (_overlaps(glyphs, bar)) {
      report.issues.add('$name: la barra tapa el número');
    }

    final pips = _private('_Pip');
    final plus = tester.getRect(
      find.descendant(of: panelFinder, matching: pips).first,
    );
    final minus = tester.getRect(
      find.descendant(of: panelFinder, matching: pips).last,
    );
    for (final (sign, pip) in [('+', plus), ('−', minus)]) {
      if (!_contains(panel, pip)) report.issues.add('$name: $sign se sale');
      if (_overlaps(pip, bar)) {
        report.issues.add('$name: la barra tapa el $sign');
      }
      if (_overlaps(pip, glyphs)) {
        report.issues.add('$name: el $sign pisa el número');
      }
    }
    if (_overlaps(plus, minus)) report.issues.add('$name: + y − se pisan');

    final history = tester.getRect(
      find.descendant(of: panelFinder, matching: _private('_History')),
    );
    if (_overlaps(glyphs, history)) {
      report.issues.add('$name: el número pisa el historial');
    }
    if (_overlaps(history, bar)) {
      report.issues.add('$name: la barra tapa el historial');
    }

    final bubble = find.descendant(
      of: panelFinder,
      matching: _private('_Bubble'),
    );
    if (bubble.evaluate().isNotEmpty) {
      final rect = tester.getRect(bubble);
      if (!_contains(panel, rect)) report.issues.add('$name: burbuja se sale');
      if (_overlaps(rect, bar)) {
        report.issues.add('$name: la barra tapa la burbuja');
      }
      if (_overlaps(rect, history)) {
        report.issues.add('$name: la burbuja pisa el historial');
      }
    }
  }
  return report;
}

Future<void> _precacheImages(WidgetTester tester) async {
  final context = tester.element(find.byType(MyHomePage));
  final assets = Directory('assets/images')
      .listSync(recursive: true)
      .whereType<File>()
      .map((f) => f.path.replaceAll(r'\', '/'))
      .where((p) => p.endsWith('.png') || p.endsWith('.jpg'));
  await tester.runAsync(() async {
    for (final asset in assets) {
      await precacheImage(AssetImage(asset), context);
    }
  });
  await tester.pump();
  await tester.pump();
}

/// Guarda lo que hay en pantalla en [shotsDir].
Future<void> shot(WidgetTester tester, String name) async {
  if (shotsDir.isEmpty) return;
  final view = tester.binding.renderViews.first;
  final layer = view.debugLayer! as OffsetLayer;
  await tester.runAsync(() async {
    final image = await layer.toImage(Offset.zero & tester.view.physicalSize);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final safe = name.replaceAll(RegExp(r'[^\w\-]+'), '_');
    File('$shotsDir/$safe.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  useGoogleFonts = false;
  setUpAll(loadFonts);
  // Los sorteos escuchan el acelerómetro, que en los tests no existe.
  setUp(() {
    for (final channel in [
      'dev.fluttercommunity.plus/sensors/method',
      'dev.fluttercommunity.plus/sensors/accelerometer',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(channel), (_) async => null);
    }
  });

  group('el contador cabe', () {
    for (final screen in screens) {
      for (final theme in themes) {
        for (final scenario in scenarios) {
          final name = '${screen.name} · ${theme.$1} · ${scenario.name}';
          testWidgets(name, (tester) async {
            late CounterReport report;
            late TestApp app;
            final errors = await collectErrors(() async {
              app = await pumpApp(tester, screen, theme, scenario: scenario);
              report = checkCounter(tester);
              await shot(tester, name);
            });
            await tearDownApp(tester, app);
            // ignore: avoid_print
            print('RESULT|$name|$report|${errors.join('; ')}');
            expect(errors, isEmpty, reason: 'errores de Flutter');
            if (screen.supported) expect(report.issues, isEmpty);
          });
        }
      }
    }
  });

  group('los toques suman y restan', () {
    for (final screen in screens.where((s) => s.supported)) {
      for (final theme in themes) {
        for (final rotated in [false, true]) {
          final name =
              '${screen.name} · ${theme.$1}${rotated ? ' · girado' : ''}';
          testWidgets(name, (tester) async {
            final app = await pumpApp(tester, screen, theme);
            if (rotated) app.game.toggleRotation();
            await tester.pump();
            for (final (i, player) in [app.game.top, app.game.bottom].indexed) {
              final panel = find.byType(PlayerCounter).at(i);
              final pips = find.descendant(
                of: panel,
                matching: _private('_Pip'),
              );
              await tester.tapAt(tester.getCenter(pips.first));
              await tester.pump(const Duration(milliseconds: 800));
              expect(player.life, 21, reason: 'el + del panel $i');
              await tester.tapAt(tester.getCenter(pips.last));
              await tester.tapAt(tester.getCenter(pips.last));
              await tester.pump(const Duration(milliseconds: 800));
              expect(player.life, 19, reason: 'el − del panel $i');
              // El historial no cuenta como toque.
              await tester.tapAt(
                tester.getCenter(
                  find.descendant(of: panel, matching: _private('_History')),
                ),
              );
              await tester.pump(const Duration(milliseconds: 800));
              expect(player.life, 19, reason: 'el historial del panel $i');
              expect(player.history, ['+1 = 21', '-2 = 19']);
            }
            await tearDownApp(tester, app);
          });
        }
      }
    }
  });

  group('las otras pantallas no se desbordan', () {
    for (final screen in screens) {
      for (final textScale in [1.0, 2.0]) {
        final scenario = Scenario(
          'texto ${(textScale * 100).round()}%',
          textScale: textScale,
          (_) {},
        );
        final name = '${screen.name} · ${scenario.name}';
        testWidgets(name, (tester) async {
          late TestApp app;
          final steps = <String, List<String>>{};
          Future<void> step(String label, Future<void> Function() body) async {
            steps[label] = await collectErrors(body);
          }

          await step('arranque', () async {
            app = await pumpApp(
              tester,
              screen,
              themes.first,
              scenario: scenario,
            );
          });

          await step('reiniciar', () async {
            await tester.tap(find.byTooltip('Reiniciar partida'));
            await tester.pumpAndSettle();
            await shot(tester, '$name · reiniciar');
            await tester.tap(find.text('Cancelar'));
            await tester.pumpAndSettle();
          });

          await step('temporizador', () async {
            await tester.tap(find.byType(TimerButton));
            await tester.pumpAndSettle();
            await shot(tester, '$name · temporizador');
            tester.state<NavigatorState>(find.byType(Navigator)).pop();
            await tester.pumpAndSettle();
          });

          for (final tab in ['Diseño', 'Partida']) {
            await step('ajustes $tab', () async {
              await tester.tap(find.byTooltip('Ajustes'));
              await tester.pumpAndSettle();
              await tester.tap(find.text(tab));
              await tester.pumpAndSettle();
              await shot(tester, '$name · ajustes $tab');
              // Recorre la pestaña entera hasta abajo.
              final list = find.byType(Scrollable).hitTestable().last;
              for (var i = 0; i < 30; i++) {
                await tester.drag(list, const Offset(0, -300));
                await tester.pumpAndSettle();
              }
              await shot(tester, '$name · ajustes $tab final');
              tester.state<NavigatorState>(find.byType(Navigator)).pop();
              await tester.pumpAndSettle();
            });
          }

          for (final (label, tab) in [
            ('moneda', 'Moneda'),
            ('dado', 'Dado'),
            ('duelo', 'Duelo'),
          ]) {
            await step('sorteo $label', () async {
              await tester.tap(find.byTooltip('Sorteos: moneda, dado y duelo'));
              // Sin pumpAndSettle: el dado se tira solo al abrir.
              for (var i = 0; i < 40; i++) {
                await tester.pump(const Duration(milliseconds: 100));
              }
              await tester.tap(find.text(tab));
              for (var i = 0; i < 40; i++) {
                await tester.pump(const Duration(milliseconds: 100));
              }
              await shot(tester, '$name · sorteo $label');
              tester.state<NavigatorState>(find.byType(Navigator)).pop();
              await tester.pumpAndSettle();
            });
          }

          await tearDownApp(tester, app);
          final failed = {
            for (final e in steps.entries)
              if (e.value.isNotEmpty) e.key: e.value,
          };
          // ignore: avoid_print
          print('SCREENS|$name|$failed');
          if (screen.supported) expect(failed, isEmpty);
        });
      }
    }
  });
}
