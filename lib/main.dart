import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mtglifecounter/app_settings.dart';
import 'package:mtglifecounter/center_bar.dart';
import 'package:mtglifecounter/game_state.dart';
import 'package:mtglifecounter/look.dart';
import 'package:mtglifecounter/number_stepper.dart';
import 'package:mtglifecounter/player_counter.dart';
import 'package:mtglifecounter/settings_page.dart';
import 'package:mtglifecounter/skin.dart';
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

  runApp(MyApp(settings: settings, game: game, storage: storage));
}

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    required this.settings,
    required this.game,
    required this.storage,
  });

  final AppSettings settings;
  final GameState game;
  final GameStorage storage;

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
      home: MyHomePage(settings: settings, game: game, storage: storage),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({
    super.key,
    required this.settings,
    required this.game,
    required this.storage,
  });

  final AppSettings settings;
  final GameState game;
  final GameStorage storage;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver {
  final ValueNotifier<bool> _resetNotifier = ValueNotifier<bool>(false);
  // La pantalla entera, para que los paneles enseñen su trozo de la imagen.
  final GlobalKey _screenKey = GlobalKey();
  final Random _random = Random();
  int _lifeChangeAmount = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.settings.addListener(_syncStorage);
    _syncStorage();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.settings.removeListener(_syncStorage);
    _resetNotifier.dispose();
    super.dispose();
  }

  // Al pasar a segundo plano se guarda al momento: puede que la app no vuelva.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) widget.storage.flush();
  }

  void _syncStorage() {
    widget.storage.enabled = widget.settings.rememberGame;
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

  void _coinFlip() {
    final result = _random.nextBool() ? 'Cara' : 'Cruz';
    _showResultDialog('Lanzamiento de moneda', result, 40);
  }

  void _rollDice() {
    final diceRoll = _random.nextInt(20) + 1;
    _showResultDialog('Lanzamiento de dado D20', '$diceRoll', 80);
  }

  void _showResultDialog(String title, String result, double fontSize) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey[800],
          title: Text(title, style: const TextStyle(color: Colors.white)),
          content: Text(
            result,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          actions: <Widget>[
            TextButton(
              child: const Text(
                'Cerrar',
                style: TextStyle(color: Colors.white),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
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
          alpha: style.frameOpacity,
          leading: [
            BarAction(Icons.refresh, 'Reiniciar partida', _showResetConfirmationDialog),
            BarAction(Icons.swap_vert, 'Girar el panel de arriba', game.toggleRotation),
          ],
          stepper: settings.showStepper
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
          trailing: [
            BarAction(Icons.monetization_on_outlined, 'Lanzar moneda', _coinFlip),
            BarAction(Icons.casino_outlined, 'Lanzar dado', _rollDice),
            BarAction(Icons.settings_outlined, 'Ajustes', _openSettings),
          ],
        );
        Widget panel(PlayerState player, Color color) => PlayerCounter(
          player: player,
          color: color,
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
                    AppTheme.classic => const EdgeInsets.fromLTRB(13, 11, 13, 11),
                  },
                  child: Stack(
                    children: [
                      Column(
                        children: [
                          Expanded(
                            child: Transform.rotate(
                              angle: game.rotated ? pi : 0,
                              child: panel(game.top, skin.top),
                            ),
                          ),
                          SizedBox(height: look.barGap),
                          Expanded(child: panel(game.bottom, skin.bottom)),
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
