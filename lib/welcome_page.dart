import 'package:flutter/material.dart';
import 'package:mtglifecounter/app_settings.dart';
import 'package:mtglifecounter/look.dart';
import 'package:mtglifecounter/round_timer.dart';
import 'package:mtglifecounter/settings_page.dart';
import 'package:mtglifecounter/skin.dart';

/// Abre la bienvenida a pantalla completa. Al cerrarla, con «Empezar» o
/// «Saltar», queda apuntado que ya se vio y no vuelve a salir.
Future<void> showWelcome(
  BuildContext context, {
  required AppSettings settings,
  required RoundTimer timer,
}) {
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, animation, _) => FadeTransition(
        opacity: animation,
        child: WelcomePage(settings: settings, timer: timer),
      ),
    ),
  );
}

/// La bienvenida de la primera vez: todo en una pantalla, con la miniatura
/// del contador arriba para ver cómo queda. Se elige la skin (solo las tres
/// publicadas: la personalizada necesita foto y colores, y se hace en
/// Ajustes), el tema y lo de la partida. Lo elegido se aplica al momento;
/// «Saltar» deja lo que había al abrirla (lo de por defecto o, si la app ya
/// estaba instalada, lo que tuviera).
class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key, required this.settings, required this.timer});

  final AppSettings settings;

  /// Para que la miniatura enseñe el reloj.
  final RoundTimer timer;

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  // Lo que había al abrirla, para «Saltar».
  late final String _skinId;
  late final AppTheme _theme;
  late final ModernVariant _variant;
  late final bool _showHistory;
  late final bool _showStepper;
  late final bool _showTimer;

  @override
  void initState() {
    super.initState();
    final settings = widget.settings;
    _skinId = settings.skinId;
    _theme = settings.theme;
    _variant = settings.modernVariant;
    _showHistory = settings.showHistory;
    _showStepper = settings.showStepper;
    _showTimer = settings.showTimer;
  }

  void _finish({required bool keep}) {
    final settings = widget.settings;
    if (!keep) {
      settings
        ..skinId = _skinId
        ..modernVariant = _variant
        ..theme = _theme
        ..showHistory = _showHistory
        ..showStepper = _showStepper
        ..showTimer = _showTimer;
    }
    settings.welcomeDone = true;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;
    return PopScope(
      // Volver atrás es saltarla.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finish(keep: false);
      },
      child: Scaffold(
        backgroundColor: kSettingsBackground,
        body: SafeArea(
          child: ListenableBuilder(
            listenable: settings,
            builder: (context, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Bienvenido',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => _finish(keep: false),
                        style: TextButton.styleFrom(
                          foregroundColor: kMutedText,
                        ),
                        child: const Text('Saltar'),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 2, 20, 0),
                  child: Text(
                    'Elige cómo quieres verla. Todo se puede cambiar luego en '
                    'Ajustes.',
                    style: TextStyle(color: kMutedText, fontSize: 14),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                    children: [
                      _lookRow(settings),
                      const _Label('Skin'),
                      _skins(settings),
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'También puedes crear la tuya, con tus colores y una '
                          'foto, en Ajustes.',
                          style: TextStyle(color: kMutedText, fontSize: 13),
                        ),
                      ),
                      const _Label('Partida'),
                      SettingsSwitch(
                        title: 'Historial de vidas',
                        value: settings.showHistory,
                        onChanged: (v) => settings.showHistory = v,
                      ),
                      SettingsSwitch(
                        title: 'Temporizador',
                        value: settings.showTimer,
                        onChanged: (v) => settings.showTimer = v,
                      ),
                      SettingsSwitch(
                        title: 'Cantidad por toque',
                        value: settings.showStepper,
                        onChanged: (v) => settings.showStepper = v,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                  child: FilledButton(
                    onPressed: () => _finish(keep: true),
                    style: FilledButton.styleFrom(
                      backgroundColor: kAccent,
                      foregroundColor: const Color(0xFF1A1306),
                      minimumSize: const Size.fromHeight(52),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: const Text('Empezar'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // La miniatura y, a su lado, los temas: como arriba en Ajustes.
  Widget _lookRow(AppSettings settings) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 104,
          child: CounterPreview(settings: settings, timer: widget.timer),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tema',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (label, theme, variant) in kThemeChoices)
                    SettingsChip(
                      label: label,
                      selected:
                          settings.theme == theme &&
                          (variant == null ||
                              settings.modernVariant == variant),
                      onTap: () {
                        if (variant != null) settings.modernVariant = variant;
                        settings.theme = theme;
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _skins(AppSettings settings) {
    return Row(
      children: [
        for (final (i, skin) in Skin.presets.indexed) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: SkinCard(
              skin: skin,
              image: settings.backgroundOf(skin),
              imageHeight: 56,
              selected: settings.skinId == skin.id,
              onTap: () => settings.skinId = skin.id,
            ),
          ),
        ],
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
