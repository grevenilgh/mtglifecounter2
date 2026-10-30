import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mtglifecounter/app_icon.dart';
import 'package:mtglifecounter/app_settings.dart';
import 'package:mtglifecounter/center_bar.dart';
import 'package:mtglifecounter/draws.dart';
import 'package:mtglifecounter/game_state.dart';
import 'package:mtglifecounter/look.dart';
import 'package:mtglifecounter/number_stepper.dart';
import 'package:mtglifecounter/player_counter.dart';
import 'package:mtglifecounter/round_timer.dart';
import 'package:mtglifecounter/settings_page.dart';
import 'package:mtglifecounter/skin.dart';
import 'package:mtglifecounter/timer_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Asegura que la barra de estado y la barra de navegación estén visibles
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: SystemUiOverlay.values,
  );

  // 2. Configura el estilo de la barra de estado
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.black, // Fondo negro para la barra de estado
      statusBarIconBrightness: Brightness.light, // Iconos blancos
      systemNavigationBarColor: Colors.black, // Fondo de la barra de navegación
      systemNavigationBarIconBrightness:
          Brightness.light, // Iconos de navegación blancos
    ),
  );

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  final prefs = await SharedPreferences.getInstance();
  final settings = AppSettings(prefs)..applyWakelock();
  final game = GameState();
  final storage = GameStorage(prefs, game);
  if (settings.rememberGame) storage.load();
  final timer = RoundTimer(
    prefs,
    mode: settings.timerMode,
    roundLength: Duration(minutes: settings.roundMinutes),
  );

  runApp(MyApp(settings: settings, game: game, storage: storage, timer: timer));
}

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    required this.settings,
    required this.game,
    required this.storage,
    required this.timer,
  });

  final AppSettings settings;
  final GameState game;
  final GameStorage storage;
  final RoundTimer timer;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MTG Life Counter',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: kAccent,
          brightness: Brightness.dark,
        ),
      ),
      home: MyHomePage(
        settings: settings,
        game: game,
        storage: storage,
        timer: timer,
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({
    super.key,
    required this.settings,
    required this.game,
    required this.storage,
    required this.timer,
  });

  final AppSettings settings;
  final GameState game;
  final GameStorage storage;
  final RoundTimer timer;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver {
  final ValueNotifier<bool> _resetNotifier = ValueNotifier<bool>(false);
  // La pantalla entera, para que los paneles enseñen su trozo de la imagen.
  final GlobalKey _screenKey = GlobalKey();
  int _lifeChangeAmount = 1;
  // La barra enseña los sorteos en vez de sus botones normales.
  bool _drawsOpen = false;
  String? _iconSkin;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.settings.addListener(_syncSettings);
    _syncSettings();
    widget.timer.onFinished = _onTimeUp;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.settings.removeListener(_syncSettings);
    _resetNotifier.dispose();
    super.dispose();
  }

  // Al pasar a segundo plano se guarda al momento: puede que la app no vuelva.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) widget.storage.flush();
  }

  void _syncSettings() {
    final settings = widget.settings;
    widget.storage.enabled = settings.rememberGame;
    widget.timer
      ..mode = settings.timerMode
      ..setRoundLength(Duration(minutes: settings.roundMinutes));
    // El icono del lanzador sigue a la skin.
    if (settings.skinId != _iconSkin) {
      _iconSkin = settings.skinId;
      setAppIcon(settings.skinId);
    }
  }

  // Al acabar la ronda el móvil vibra tres veces, para notarlo en la mesa.
  Future<void> _onTimeUp() async {
    if (!widget.settings.timerVibrate) return;
    for (var i = 0; i < 3; i++) {
      await HapticFeedback.vibrate();
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
  }

  void _openTimer() {
    showTimerSheet(context, timer: widget.timer, settings: widget.settings);
  }

  void _openDraw(
    Future<void> Function(BuildContext, {required bool flipTop}) draw,
  ) {
    setState(() => _drawsOpen = false);
    draw(context, flipTop: widget.game.rotated);
  }

  void _resetGame() {
    _lifeChangeAmount = 1;
    widget.game.reset();
    _resetNotifier.value = !_resetNotifier.value;
  }

  void _onLifeChanged() {
    setState(() {
      _lifeChangeAmount = 1;
    });
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => SettingsPage(settings: widget.settings),
      ),
    );
  }

  void _showResetConfirmationDialog() {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[800],
          title: const Text(
            'Reiniciar partida',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            '¿Estás seguro de que quieres reiniciar la partida? Se perderán todos los datos.',
            style: TextStyle(color: Colors.white),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Colors.white),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text(
                'Aceptar',
                style: TextStyle(color: Colors.white),
              ),
              onPressed: () {
                _resetGame();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;
    final game = widget.game;
    return ListenableBuilder(
      listenable: Listenable.merge([settings, game]),
      builder: (context, _) {
        final skin = settings.skin;
        final look = settings.look;
        final style = PanelStyle(
          look: look,
          background: settings.backgroundOf(skin),
          backgroundMode: settings.backgroundMode,
          imageOpacity: settings.imageOpacity / 100,
          frameOpacity: settings.frameOpacity / 100,
          historyOpacity: settings.historyOpacity / 100,
          zoneMarks: settings.zoneMarks,
          focus: settings.focus,
          animations: settings.animations,
          screenKey: _screenKey,
        );
        // Sin la cantidad por toque en la barra, cada toque cuenta 1.
        final amount = settings.showStepper ? _lifeChangeAmount : 1;
        // En el borde antiguo la barra es de cuero, salvo en la personalizada.
        final barColor = look.isClassic && skin.id != Skin.customDefault.id
            ? const Color(0xFF4A3420)
            : skin.bar;
        final bar = CenterBar(
          look: look,
          color: barColor,
          alpha: settings.barOpacity / 100,
          leading: _drawsOpen
              ? [
                  BarAction(
                    Icons.arrow_back,
                    'Volver',
                    () => setState(() => _drawsOpen = false),
                  ),
                ]
              : [
                  BarAction(
                    Icons.refresh,
                    'Reiniciar partida',
                    _showResetConfirmationDialog,
                  ),
                  BarAction(
                    Icons.swap_vert,
                    'Girar el panel de arriba',
                    game.toggleRotation,
                  ),
                ],
          timer: settings.showTimer && !_drawsOpen
              ? TimerButton(
                  timer: widget.timer,
                  look: look,
                  warningEnabled: settings.timerWarning,
                  onTap: _openTimer,
                )
              : null,
          stepper: settings.showStepper && !_drawsOpen
              ? (color, compact) => NumberStepper(
                  resetNotifier: _resetNotifier,
                  initialValue: _lifeChangeAmount,
                  color: color,
                  compact: compact,
                  onChanged: (newValue) {
                    setState(() {
                      _lifeChangeAmount = newValue;
                    });
                  },
                )
              : null,
          // Los sorteos van tras un botón que despliega la barra.
          trailing: _drawsOpen
              ? [
                  BarAction(
                    Icons.monetization_on_outlined,
                    'Lanzar moneda',
                    () => _openDraw(showCoinFlip),
                  ),
                  BarAction(
                    Icons.hexagon_outlined,
                    'Tirar el dado D20',
                    () => _openDraw(showDiceRoll),
                  ),
                  BarAction(
                    Icons.style_outlined,
                    'Duelo: piedra, papel o tijera',
                    () => _openDraw(showDuel),
                  ),
                ]
              : [
                  BarAction(
                    Icons.casino_outlined,
                    'Sorteos: moneda, dado y duelo',
                    () => setState(() => _drawsOpen = true),
                  ),
                  BarAction(Icons.settings_outlined, 'Ajustes', _openSettings),
                ],
        );
        // En el borde antiguo cada jugador lleva el marco de carta que mejor
        // va con su color, y nunca el mismo que el otro.
        final frames = CardFrame.forPlayers(skin.top, skin.bottom);
        Widget panel(PlayerState player, Color color, CardFrame frame) =>
            PlayerCounter(
              player: player,
              color: color,
              frame: frame,
              style: style,
              lifeChangeAmount: amount,
              onLifeChanged: _onLifeChanged,
            );
        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            key: _screenKey,
            fit: StackFit.expand,
            children: [
              ScreenBackground(skin: skin, style: style),
              // El contenido de la app se coloca dentro de un SafeArea
              SafeArea(
                child: Padding(
                  padding: switch (look.theme) {
                    AppTheme.original => EdgeInsets.zero,
                    AppTheme.modern =>
                      look.isCards ? const EdgeInsets.all(12) : EdgeInsets.zero,
                    // El marco de carta es gordo: ocupa el margen de antes.
                    AppTheme.classic => const EdgeInsets.all(5),
                  },
                  child: Stack(
                    children: [
                      Column(
                        children: [
                          Expanded(
                            child: Transform.rotate(
                              angle: game.rotated ? pi : 0,
                              child: panel(game.top, skin.top, frames.$1),
                            ),
                          ),
                          SizedBox(height: look.barGap),
                          Expanded(
                            child: panel(game.bottom, skin.bottom, frames.$2),
                          ),
                        ],
                      ),
                      // La barra va centrada: en el hueco entre los paneles
                      // o, en cristal, flotando encima.
                      Align(child: bar),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
