import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mtglifecounter/app_icon.dart';
import 'package:mtglifecounter/app_settings.dart';
import 'package:mtglifecounter/center_bar.dart';
import 'package:mtglifecounter/companion.dart';
import 'package:mtglifecounter/counter_layout.dart';
import 'package:mtglifecounter/draws.dart';
import 'package:mtglifecounter/game_state.dart';
import 'package:mtglifecounter/number_stepper.dart';
import 'package:mtglifecounter/round_timer.dart';
import 'package:mtglifecounter/settings_page.dart';
import 'package:mtglifecounter/themed_dialog.dart';
import 'package:mtglifecounter/time_up.dart';
import 'package:mtglifecounter/timer_view.dart';
import 'package:mtglifecounter/updater.dart';
import 'package:mtglifecounter/vibration.dart';
import 'package:mtglifecounter/welcome_page.dart';
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

  // Solo en Android: pregunta si hay versión nueva al abrir la app.
  final updater = Updater.supported ? (Updater()..check()) : null;

  // Solo en Android: el reloj puede seguir los avisos de ronda de Companion.
  final companion = CompanionLink.supported
      ? CompanionLink(prefs, timer, enabled: settings.companionEnabled)
      : null;

  runApp(
    MyApp(
      settings: settings,
      game: game,
      storage: storage,
      timer: timer,
      updater: updater,
      companion: companion,
      // Con --dart-define=WELCOME=true sale siempre, para probarla.
      showWelcome:
          !settings.welcomeDone || const bool.fromEnvironment('WELCOME'),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    required this.settings,
    required this.game,
    required this.storage,
    required this.timer,
    this.updater,
    this.companion,
    this.showWelcome = false,
  });

  final AppSettings settings;
  final GameState game;
  final GameStorage storage;
  final RoundTimer timer;

  /// Busca versiones nuevas; null fuera de Android y en los tests.
  final Updater? updater;

  /// Los avisos de ronda de Companion; null fuera de Android.
  final CompanionLink? companion;

  /// Si sale la bienvenida de la primera vez ([WelcomePage]) al abrir.
  final bool showWelcome;

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
        updater: updater,
        companion: companion,
        showWelcome: showWelcome,
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
    this.updater,
    this.companion,
    this.showWelcome = false,
  });

  final AppSettings settings;
  final GameState game;
  final GameStorage storage;
  final RoundTimer timer;

  /// Busca versiones nuevas; null fuera de Android y en los tests.
  final Updater? updater;

  /// Los avisos de ronda de Companion; null fuera de Android.
  final CompanionLink? companion;

  /// Si sale la bienvenida de la primera vez ([WelcomePage]) al abrir.
  final bool showWelcome;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver {
  final ValueNotifier<bool> _resetNotifier = ValueNotifier<bool>(false);
  // La pantalla entera, para que los paneles enseñen su trozo de la imagen.
  int _lifeChangeAmount = 1;
  // Si se está enseñando el aviso de «¡Tiempo!».
  bool _timeUp = false;
  String? _iconSkin;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.settings.addListener(_syncSettings);
    _syncSettings();
    widget.timer.onFinished = _onTimeUp;
    // Los avisos de Companion que llegaron con la app cerrada.
    widget.companion?.sync();
    if (widget.showWelcome) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => showWelcome(
          context,
          settings: widget.settings,
          timer: widget.timer,
        ),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.settings.removeListener(_syncSettings);
    _resetNotifier.dispose();
    super.dispose();
  }

  // Al pasar a segundo plano se guarda al momento: puede que la app no vuelva.
  // Al volver no se buscan actualizaciones: eso solo al abrir la app y con el
  // botón de «Acerca de».
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      widget.storage.flush();
    } else {
      // Al volver de Companion, la ronda puede haber empezado.
      widget.companion?.sync();
    }
  }

  void _syncSettings() {
    final settings = widget.settings;
    widget.storage.enabled = settings.rememberGame;
    // Lo de Ajustes es lo de por defecto: al reloj de ahora solo le llega si
    // no ha empezado.
    widget.timer.setDefaults(
      settings.timerMode,
      Duration(minutes: settings.roundMinutes),
    );
    // Sin el reloj de ajedrez activado en Ajustes no puede quedar uno (al
    // abrir la app o al quitarlo): vuelve a lo de por defecto.
    if (widget.timer.chess && !settings.chessEnabled) widget.timer.reset();
    widget.companion?.enabled = settings.companionEnabled;
    // El icono del lanzador sigue a la skin.
    if (settings.skinId != _iconSkin) {
      _iconSkin = settings.skinId;
      setAppIcon(settings.skinId);
    }
  }

  // En el navegador, la pantalla encendida solo se concede tras un toque (en
  // el iPhone, sobre todo) y se pierde al cambiar de app: se vuelve a pedir
  // al tocar, como mucho cada medio minuto.
  DateTime? _wakelockAsked;
  void _retryWakelock() {
    if (!kIsWeb) return;
    final now = DateTime.now();
    final last = _wakelockAsked;
    if (last != null && now.difference(last) < const Duration(seconds: 30)) {
      return;
    }
    _wakelockAsked = now;
    widget.settings.applyWakelock();
  }

  // Al acabar la ronda sale el aviso de fin de ronda y el móvil vibra tres
  // veces, para notarlo en la mesa: el aviso va al ritmo de las vibraciones
  // (kTimeUpBuzzes) y se va al acabar la última. En el reloj de ajedrez,
  // cuando a un jugador se le acaba el suyo, solo vibra: la ronda sigue y el
  // aviso de los dos no toca.
  Future<void> _onTimeUp() async {
    // En el reloj de ajedrez, al que se le acaba solo le vibra (el otro sigue
    // jugando con lo suyo); el aviso sale cuando se les acaba a los dos, que
    // es cuando se acaba la ronda.
    final timer = widget.timer;
    final roundOver =
        !timer.chess ||
        (timer.outOfTime(Seat.top) && timer.outOfTime(Seat.bottom));
    if (mounted && roundOver) setState(() => _timeUp = true);
    if (!widget.settings.timerVibrate) return;
    var at = Duration.zero;
    for (final buzz in kTimeUpBuzzes) {
      await Future<void>.delayed(buzz - at);
      at = buzz;
      await vibrate(kTimeUpBuzzLength);
    }
  }

  void _openTimer() {
    showTimerSheet(
      context,
      timer: widget.timer,
      settings: widget.settings,
      companion: widget.companion,
    );
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
        builder: (context) => SettingsPage(
          settings: widget.settings,
          timer: widget.timer,
          updater: widget.updater,
          companion: widget.companion,
        ),
      ),
    );
  }

  Future<void> _showResetConfirmationDialog() async {
    final accepted = await showThemedConfirm(
      context,
      settings: widget.settings,
      icon: Icons.restart_alt,
      title: '¿Reiniciar la partida?',
      message:
          'Las vidas vuelven a $kInitialLife y se borra el historial. '
          'El reloj de la ronda sigue como está.',
      confirmLabel: 'Reiniciar',
      destructive: true,
    );
    if (accepted && mounted) _resetGame();
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;
    final game = widget.game;
    return ListenableBuilder(
      // El modo del reloj, para poner o quitar los botones del de ajedrez.
      listenable: Listenable.merge([
        settings,
        game,
        widget.timer.modeListenable,
      ]),
      builder: (context, _) {
        final look = settings.look;
        // Sin la cantidad por toque en la barra, cada toque cuenta 1.
        final amount = settings.showStepper ? _lifeChangeAmount : 1;
        final bar = CenterBar(
          look: look,
          color: barColorFor(settings),
          players: settings.skin.cardFrames,
          alpha: settings.barOpacity / 100,
          leading: [
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
          timer: settings.showTimer || widget.timer.chess
              ? TimerButton(
                  timer: widget.timer,
                  look: look,
                  warningEnabled: settings.timerWarning,
                  companion: widget.companion,
                  onTap: _openTimer,
                )
              : null,
          stepper: settings.showStepper
              ? (color, compact, mana) => NumberStepper(
                  resetNotifier: _resetNotifier,
                  initialValue: _lifeChangeAmount,
                  color: color,
                  compact: compact,
                  mana: mana,
                  onChanged: (newValue) {
                    setState(() {
                      _lifeChangeAmount = newValue;
                    });
                  },
                )
              : null,
          // Los sorteos se abren en el dado y dentro se cambia de pestaña.
          trailing: [
            BarAction(
              Icons.shuffle,
              'Sorteos: moneda, dado y duelo',
              () => showDraws(context, flipTop: game.rotated),
            ),
            BarAction(Icons.settings_outlined, 'Ajustes', _openSettings),
          ],
        );
        return Scaffold(
          backgroundColor: Colors.black,
          body: Listener(
            onPointerUp: (_) => _retryWakelock(),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CounterLayout(
                    settings: settings,
                    game: game,
                    bar: bar,
                    lifeChangeAmount: amount,
                    onLifeChanged: _onLifeChanged,
                    timer: widget.timer,
                  ),
                ),
                if (_timeUp)
                  Positioned.fill(
                    child: TimeUpOverlay(
                      style: settings.timeUpStyle,
                      lives: (game.top.life, game.bottom.life),
                      roundMinutes: widget.timer.roundLength.inMinutes,
                      look: look,
                      flipTop: game.rotated,
                      animate: settings.animations,
                      stays: settings.timeUpStays,
                      onDone: () => setState(() => _timeUp = false),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
