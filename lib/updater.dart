import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

// Las versiones nuevas las publica el action de GitHub en cada push a main:
// la APK va en una release cuya etiqueta acaba en el número de compilación
// (v2.0.0-57). La app pregunta por la última y, si su número es mayor que el
// suyo, avisa y la instala encima. Solo en Android: la web ya está siempre
// al día.

/// Una versión publicada en GitHub.
class Release {
  const Release({
    required this.name,
    required this.build,
    required this.apkUrl,
    this.size = 0,
  });

  final String name;
  final int build;
  final String apkUrl;

  /// Lo que pesa la APK, en bytes (0 si no se sabe).
  final int size;

  String get label => '$name ($build)';

  /// La release que devuelve la API de GitHub, o null si no lleva APK o su
  /// etiqueta no acaba en el número de compilación.
  static Release? fromGitHub(Object? json) {
    if (json is! Map) return null;
    final tag = json['tag_name'];
    final match = tag is String
        ? RegExp(r'^v?(.+)-(\d+)$').firstMatch(tag)
        : null;
    if (match == null) return null;
    final assets = json['assets'];
    if (assets is! List) return null;
    for (final asset in assets) {
      if (asset is! Map) continue;
      final name = asset['name'];
      final url = asset['browser_download_url'];
      if (name is String && name.endsWith('.apk') && url is String) {
        return Release(
          name: match.group(1)!,
          build: int.parse(match.group(2)!),
          apkUrl: url,
          size: asset['size'] is int ? asset['size'] as int : 0,
        );
      }
    }
    return null;
  }
}

enum UpdateStep { idle, downloading, installing, failed }

/// Busca versiones nuevas y las instala.
class Updater extends ChangeNotifier {
  Updater({
    http.Client? client,
    Future<int> Function()? currentBuild,
    Future<void> Function(String path)? install,
    Future<Directory> Function()? tempDir,
  }) : _client = client ?? http.Client(),
       _currentBuild = currentBuild ?? _installedBuild,
       _install = install ?? _openInstaller,
       _tempDir = tempDir ?? getTemporaryDirectory;

  static const String repo = 'grevenilgh/mtglifecounter2';
  static final Uri latestUri = Uri.https(
    'api.github.com',
    '/repos/$repo/releases/latest',
  );

  /// La página de la última versión, para bajarla a mano si falla la app.
  static const String releasesPage = 'https://github.com/$repo/releases/latest';

  /// Cada cuánto se vuelve a preguntar al volver a la app.
  static const Duration _recheck = Duration(minutes: 30);

  static const MethodChannel _channel = MethodChannel('mtglifecounter/update');

  /// Solo la app de Android: la web se carga nueva cada vez.
  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  final http.Client _client;
  final Future<int> Function() _currentBuild;
  final Future<void> Function(String path) _install;

  /// Dónde se descarga la APK: la caché de la app, que es lo que comparte
  /// el FileProvider (res/xml/update_paths.xml).
  final Future<Directory> Function() _tempDir;

  /// La versión nueva, si la hay.
  Release? available;

  bool checking = false;

  /// Si la última vez no se pudo preguntar (sin internet, por ejemplo).
  bool checkFailed = false;

  DateTime? _lastCheck;

  UpdateStep step = UpdateStep.idle;

  /// Lo descargado, de 0 a 1 (null si no se sabe el total).
  double? progress;

  /// Pregunta a GitHub por la última versión. Sin [force], no repite si ya
  /// preguntó hace poco.
  Future<void> check({bool force = false}) async {
    final last = _lastCheck;
    if (checking ||
        (!force &&
            last != null &&
            DateTime.now().difference(last) < _recheck)) {
      return;
    }
    checking = true;
    notifyListeners();
    try {
      final response = await _client
          .get(latestUri, headers: {'Accept': 'application/vnd.github+json'})
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 404) {
        // Aún no hay ninguna publicada.
        available = null;
      } else if (response.statusCode == 200) {
        final release = Release.fromGitHub(jsonDecode(response.body));
        final current = await _currentBuild();
        available = release != null && release.build > current ? release : null;
      } else {
        throw HttpException('GitHub respondió ${response.statusCode}');
      }
      checkFailed = false;
      _lastCheck = DateTime.now();
    } catch (_) {
      checkFailed = true;
    } finally {
      checking = false;
      notifyListeners();
    }
  }

  /// Descarga la versión nueva y abre el instalador de Android, que pregunta
  /// antes de instalarla encima.
  Future<void> install() async {
    final release = available;
    if (release == null || step == UpdateStep.downloading) return;
    step = UpdateStep.downloading;
    progress = 0;
    notifyListeners();
    try {
      final dir = Directory('${(await _tempDir()).path}/updates');
      await dir.create(recursive: true);
      final file = File('${dir.path}/MTGLifeCounter.apk');
      if (await file.exists()) await file.delete();

      final response = await _client.send(
        http.Request('GET', Uri.parse(release.apkUrl)),
      );
      if (response.statusCode != 200) {
        throw HttpException('La descarga respondió ${response.statusCode}');
      }
      final total = response.contentLength ?? release.size;
      final sink = file.openWrite();
      var received = 0;
      var shown = -1;
      try {
        await for (final chunk in response.stream) {
          sink.add(chunk);
          received += chunk.length;
          if (total > 0) {
            progress = received / total;
            // Se avisa a cada 1 %, no a cada trozo.
            final percent = (progress! * 100).floor();
            if (percent != shown) {
              shown = percent;
              notifyListeners();
            }
          }
        }
      } finally {
        await sink.close();
      }

      step = UpdateStep.installing;
      notifyListeners();
      await _install(file.path);
      step = UpdateStep.idle;
    } catch (_) {
      step = UpdateStep.failed;
    }
    progress = null;
    notifyListeners();
  }

  static Future<int> _installedBuild() async =>
      int.tryParse((await PackageInfo.fromPlatform()).buildNumber) ?? 0;

  static Future<void> _openInstaller(String path) =>
      _channel.invokeMethod<void>('install', path);
}
