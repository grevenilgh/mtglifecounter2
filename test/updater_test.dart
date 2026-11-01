import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mtglifecounter/app_settings.dart';
import 'package:mtglifecounter/game_state.dart';
import 'package:mtglifecounter/main.dart';
import 'package:mtglifecounter/round_timer.dart';
import 'package:mtglifecounter/update_badge.dart';
import 'package:mtglifecounter/updater.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lo que devuelve la API de GitHub para la última release.
Map<String, Object?> githubRelease(String tag, {bool apk = true}) => {
  'tag_name': tag,
  'assets': [
    {
      'name': 'notas.txt',
      'browser_download_url': 'https://example.com/notas.txt',
      'size': 10,
    },
    if (apk)
      {
        'name': 'MTGLifeCounter.apk',
        'browser_download_url': 'https://example.com/$tag/MTGLifeCounter.apk',
        'size': 6,
      },
  ],
};

Updater updaterFor(
  http.Response Function(http.Request) respond, {
  int current = 50,
  Future<void> Function(String path)? install,
  Directory? temp,
}) => Updater(
  client: MockClient((request) async => respond(request)),
  currentBuild: () async => current,
  install: install ?? (_) async {},
  tempDir: () async => temp ?? Directory.systemTemp,
);

void main() {
  group('Release.fromGitHub', () {
    test('lee el nombre y el número de compilación de la etiqueta', () {
      final release = Release.fromGitHub(githubRelease('v2.0.0-57'))!;
      expect(release.name, '2.0.0');
      expect(release.build, 57);
      expect(release.label, '2.0.0 (57)');
      expect(
        release.apkUrl,
        'https://example.com/v2.0.0-57/MTGLifeCounter.apk',
      );
      expect(release.size, 6);
    });

    test('sin APK o con otra etiqueta no es una versión', () {
      expect(
        Release.fromGitHub(githubRelease('v2.0.0-57', apk: false)),
        isNull,
      );
      expect(Release.fromGitHub(githubRelease('v2.0.0')), isNull);
      expect(Release.fromGitHub(githubRelease('final')), isNull);
      expect(Release.fromGitHub('basura'), isNull);
      expect(Release.fromGitHub({'tag_name': 'v1-2', 'assets': 3}), isNull);
    });
  });

  group('Updater.check', () {
    test('avisa solo si el número es mayor que el instalado', () async {
      var tag = 'v2.0.0-51';
      final updater = updaterFor((request) {
        expect(request.url, Updater.latestUri);
        return http.Response(jsonEncode(githubRelease(tag)), 200);
      });
      await updater.check();
      expect(updater.available?.build, 51);

      tag = 'v2.0.0-50';
      await updater.check(force: true);
      expect(updater.available, isNull);
      expect(updater.checkFailed, isFalse);
    });

    test('sin releases no hay nada que avisar', () async {
      final updater = updaterFor((_) => http.Response('{}', 404));
      await updater.check();
      expect(updater.available, isNull);
      expect(updater.checkFailed, isFalse);
    });

    test('sin internet lo dice y no se rompe', () async {
      final updater = Updater(
        client: MockClient((_) async => throw const SocketException('sin red')),
        currentBuild: () async => 50,
      );
      await updater.check();
      expect(updater.checkFailed, isTrue);
      expect(updater.checking, isFalse);
    });

    test('no vuelve a preguntar enseguida si no se le fuerza', () async {
      var calls = 0;
      final updater = updaterFor((_) {
        calls++;
        return http.Response('{}', 404);
      });
      await updater.check();
      await updater.check();
      expect(calls, 1);
      await updater.check(force: true);
      expect(calls, 2);
    });
  });

  test('descarga la APK y abre el instalador con ella', () async {
    final temp = await Directory.systemTemp.createTemp('mtg_update');
    addTearDown(() => temp.delete(recursive: true));
    String? installed;
    final updater = updaterFor(
      (request) => request.url.path.endsWith('.apk')
          ? http.Response.bytes([1, 2, 3, 4, 5, 6], 200)
          : http.Response(jsonEncode(githubRelease('v2.0.0-60')), 200),
      install: (path) async => installed = path,
      temp: temp,
    );
    final steps = <UpdateStep>[];
    updater.addListener(() => steps.add(updater.step));

    await updater.check();
    await updater.install();

    expect(installed, '${temp.path}/updates/MTGLifeCounter.apk');
    expect(await File(installed!).readAsBytes(), [1, 2, 3, 4, 5, 6]);
    expect(
      steps,
      containsAllInOrder([
        UpdateStep.downloading,
        UpdateStep.installing,
        UpdateStep.idle,
      ]),
    );
  });

  test('si la descarga falla lo dice', () async {
    final updater = updaterFor(
      (request) => request.url.path.endsWith('.apk')
          ? http.Response('no', 500)
          : http.Response(jsonEncode(githubRelease('v2.0.0-60')), 200),
      install: (_) async => fail('no debería instalar nada'),
    );
    await updater.check();
    await updater.install();
    expect(updater.step, UpdateStep.failed);
    expect(updater.progress, isNull);
  });

  testWidgets('con versión nueva parpadea el aviso y «Acerca de» la ofrece', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'mtglifecounter',
      packageName: 'mtg.premodern.alicante.lifecounter',
      version: '2.0.0',
      buildNumber: '50',
      buildSignature: '',
    );
    final prefs = await SharedPreferences.getInstance();
    final game = GameState();
    final updater = updaterFor(
      (_) => http.Response(jsonEncode(githubRelease('v2.0.0-61')), 200),
    );

    await tester.binding.setSurfaceSize(const Size(400, 800));
    await tester.pumpWidget(
      MyApp(
        settings: AppSettings(prefs),
        game: game,
        storage: GameStorage(prefs, game),
        timer: RoundTimer(prefs),
        updater: updater,
      ),
    );
    bool blinking(String tooltip) => tester
        .widget<UpdateBadge>(
          find.ancestor(
            of: find.byTooltip(tooltip),
            matching: find.byType(UpdateBadge),
          ),
        )
        .show;

    await tester.runAsync(updater.check);
    await tester.pump();
    // En la pantalla principal no sale: solo en la ⓘ de Ajustes.
    expect(find.byType(UpdateBadge), findsNothing);

    // El parpadeo no para, así que no se puede esperar a que se calme.
    await tester.tap(find.byTooltip('Ajustes'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(blinking('Acerca de'), isTrue);
    await tester.tap(find.byTooltip('Acerca de'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Hay una versión nueva: 2.0.0 (61)'), findsOneWidget);
    expect(find.text('Actualizar'), findsOneWidget);
    expect(find.text('Versión 2.0.0 (50)'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });
}
