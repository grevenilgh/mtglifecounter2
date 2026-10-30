import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mtglifecounter/app_settings.dart';
import 'package:mtglifecounter/game_state.dart';
import 'package:mtglifecounter/number_stepper.dart';
import 'package:mtglifecounter/player_counter.dart';
import 'package:mtglifecounter/settings_page.dart';
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

  Widget _barButton(IconData icon, String tooltip, VoidCallback onPressed) {
    return IconButton(
      icon: Icon(icon, color: Colors.white, size: 28),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      onPressed: onPressed,
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
        final background = settings.backgroundOf(skin);
        return Scaffold(
          backgroundColor: Colors.black,
          body: Container(
            // La imagen de fondo solo se aplica al body del Scaffold
            decoration: BoxDecoration(
              image: background == null
                  ? null
                  : DecorationImage(image: background, fit: BoxFit.cover),
            ),
            // El contenido de la app se coloca dentro de un SafeArea
            child: SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: Transform.rotate(
                      angle: game.rotated ? pi : 0,
                      child: PlayerCounter(
                        player: game.top,
                        color: skin.topPanel,
                        lifeChangeAmount: _lifeChangeAmount,
                        onLifeChanged: _onLifeChanged,
                      ),
                    ),
                  ),
                  Container(
                    height: 78,
                    color: skin.barColor,
                    // Si la pantalla es muy estrecha la barra se encoge en
                    // vez de desbordarse.
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: SizedBox(
                        width: max(MediaQuery.sizeOf(context).width, 340),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _barButton(
                              Icons.refresh,
                              'Reiniciar partida',
                              _showResetConfirmationDialog,
                            ),
                            _barButton(
                              Icons.crop_rotate,
                              'Girar el panel de arriba',
                              game.toggleRotation,
                            ),
                            NumberStepper(
                              resetNotifier: _resetNotifier,
                              initialValue: _lifeChangeAmount,
                              onChanged: (newValue) {
                                setState(() {
                                  _lifeChangeAmount = newValue;
                                });
                              },
                            ),
                            _barButton(
                              Icons.monetization_on,
                              'Lanzar moneda',
                              _coinFlip,
                            ),
                            _barButton(Icons.casino, 'Lanzar dado', _rollDice),
                            _barButton(
                              Icons.settings,
                              'Ajustes',
                              _openSettings,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: PlayerCounter(
                      player: game.bottom,
                      color: skin.bottomPanel,
                      lifeChangeAmount: _lifeChangeAmount,
                      onLifeChanged: _onLifeChanged,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
