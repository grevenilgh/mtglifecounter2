import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mtglifecounter/about_page.dart';
import 'package:mtglifecounter/app_settings.dart';
import 'package:mtglifecounter/center_bar.dart';
import 'package:mtglifecounter/counter_layout.dart';
import 'package:mtglifecounter/game_state.dart';
import 'package:mtglifecounter/hold_to_repeat.dart';
import 'package:mtglifecounter/look.dart';
import 'package:mtglifecounter/number_stepper.dart';
import 'package:mtglifecounter/round_timer.dart';
import 'package:mtglifecounter/skin.dart';
import 'package:mtglifecounter/timer_view.dart';
import 'package:mtglifecounter/update_badge.dart';
import 'package:mtglifecounter/updater.dart';

const Color kSettingsBackground = Color(0xFF111113);
const Color kCardColor = Color(0xFF1C1C1E);
const Color kAccent = Color(0xFFE8B64C);
const Color kMutedText = Color(0xFFA1A1AA);

/// Colores que se ofrecen de un toque en la skin personalizada. Para cualquier
/// otro está el botón de la paleta.
const List<Color> kSwatches = [
  Color(0xFF673AB7),
  Color(0xFF4CAF50),
  Color(0xFF9B1D20),
  Color(0xFF3D2B3D),
  Color(0xFF1E3A5F),
  Color(0xFF8C2B34),
  Color(0xFF0F766E),
  Color(0xFFB45309),
  Color(0xFFBE185D),
  Color(0xFF2563EB),
  Color(0xFF37342D),
  Color(0xFF424242),
];

/// Los temas tal como se eligen: el borde nuevo sale ya con su variante.
const kThemeChoices = [
  ('Original', AppTheme.original, null),
  ('Cristal', AppTheme.modern, ModernVariant.glass),
  ('Tarjetas', AppTheme.modern, ModernVariant.cards),
  ('Old Border', AppTheme.classic, null),
];

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.settings,
    required this.timer,
    this.updater,
  });

  final AppSettings settings;

  /// Para el puntito de versión nueva en la ⓘ y el botón de «Acerca de».
  final Updater? updater;

  /// El reloj de la partida, para que la miniatura lo enseñe igual.
  final RoundTimer timer;

  /// Abre la galería y pone la foto elegida de fondo. Se pide ya reducida
  /// porque se guarda en las preferencias.
  Future<void> _pickPhoto(BuildContext context) async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1440,
      maxHeight: 1440,
      imageQuality: 85,
    );
    if (file == null) return;
    settings.backgroundPhoto = await file.readAsBytes();
  }

  @override
  Widget build(BuildContext context) {
    // Dos pestañas: cómo se ve la app y cómo se juega con ella.
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: kSettingsBackground,
        appBar: AppBar(
          title: const Text('Ajustes'),
          backgroundColor: kSettingsBackground,
          foregroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          actions: [
            ListenableBuilder(
              listenable: updater ?? const AlwaysStoppedAnimation(0),
              builder: (context, _) => UpdateBadge(
                show: updater?.available != null,
                child: IconButton(
                  icon: const Icon(Icons.info_outline),
                  tooltip: 'Acerca de',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => AboutPage(updater: updater),
                    ),
                  ),
                ),
              ),
            ),
          ],
          bottom: const TabBar(
            indicatorColor: kAccent,
            labelColor: Colors.white,
            unselectedLabelColor: kMutedText,
            dividerColor: Color(0xFF2C2C2E),
            tabs: [
              Tab(icon: Icon(Icons.palette_outlined), text: 'Diseño'),
              Tab(icon: Icon(Icons.casino_outlined), text: 'Partida'),
            ],
          ),
        ),
        body: ListenableBuilder(
          listenable: settings,
          builder: (context, _) =>
              TabBarView(children: [_design(context), _game(context)]),
        ),
      ),
    );
  }

  Widget _design(BuildContext context) {
    final custom = settings.customSkin;
    // El tema y la miniatura van fijos arriba: así se ve el resultado de
    // todo lo que se toca más abajo sin salir de Ajustes. Con poca pantalla
    // o la letra del sistema muy grande no cabrían (en el Old Border, con su
    // explicación, se desbordaba): entonces suben con lo demás.
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxHeight < 520 || textScale > 1.3) {
          return _designOptions(
            context,
            custom,
            header: _designHeader(inList: true),
          );
        }
        return Column(
          children: [
            _designHeader(),
            const Divider(height: 1, color: Color(0xFF2C2C2E)),
            Expanded(child: _designOptions(context, custom)),
          ],
        );
      },
    );
  }

  Widget _designHeader({bool inList = false}) {
    return Padding(
      padding: inList
          ? const EdgeInsets.only(bottom: 12)
          : const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: CounterPreview(settings: settings, timer: timer),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.style_outlined, color: kAccent, size: 20),
                    SizedBox(width: 10),
                    Text(
                      'Tema',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _Choices(
                  children: [
                    for (final (label, theme, variant) in kThemeChoices)
                      SettingsChip(
                        label: label,
                        selected:
                            settings.theme == theme &&
                            (variant == null ||
                                settings.modernVariant == variant),
                        onTap: () {
                          if (variant != null) {
                            settings.modernVariant = variant;
                          }
                          settings.theme = theme;
                        },
                      ),
                  ],
                ),
                if (settings.theme == AppTheme.classic)
                  const _Help(
                    'Cada jugador es una carta antigua tumbada, con el '
                    'marco que mejor va con su color.',
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Las opciones de diseño. Con [header], el tema y la miniatura van al
  /// principio de la lista en vez de fijos.
  Widget _designOptions(BuildContext context, Skin custom, {Widget? header}) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
      children: [
        if (header != null) ...[
          header,
          const Divider(height: 1, color: Color(0xFF2C2C2E)),
          const SizedBox(height: 16),
        ],
        _Group(
          title: 'Skin',
          icon: Icons.color_lens_outlined,
          children: [
            // De dos en dos: con las cuatro en fila no cabían los nombres.
            for (final (i, pair) in _pairs([...Skin.presets, custom]).indexed)
              Padding(
                padding: EdgeInsets.only(top: i == 0 ? 0 : 10),
                child: Row(
                  children: [
                    for (final (j, skin) in pair.indexed) ...[
                      if (j > 0) const SizedBox(width: 10),
                      Expanded(
                        child: SkinCard(
                          skin: skin,
                          image: settings.backgroundOf(skin),
                          selected: settings.skinId == skin.id,
                          onTap: () => settings.skinId = skin.id,
                        ),
                      ),
                    ],
                    if (pair.length == 1) ...[
                      const SizedBox(width: 10),
                      const Expanded(child: SizedBox()),
                    ],
                  ],
                ),
              ),
            const _Help(
              'En Android, el icono y el nombre de la app cambian con la skin '
              'al salir de ella.',
            ),
            if (settings.skinId == Skin.customDefault.id) ...[
              _ColorRow(
                label: 'Jugador de arriba',
                color: custom.top,
                onChanged: (c) => settings.customSkin = custom.copyWith(top: c),
              ),
              _ColorRow(
                label: 'Jugador de abajo',
                color: custom.bottom,
                onChanged: (c) =>
                    settings.customSkin = custom.copyWith(bottom: c),
              ),
              _ColorRow(
                label: 'Barra central',
                color: custom.bar,
                onChanged: (c) => settings.customSkin = custom.copyWith(bar: c),
              ),
              const _Label('Imagen de la skin'),
              _Choices(
                children: [
                  for (final background in SkinBackground.values)
                    if (background != SkinBackground.photo)
                      SettingsChip(
                        label: background.label,
                        selected: custom.background == background,
                        onTap: () => settings.customSkin = custom.copyWith(
                          background: background,
                        ),
                      ),
                  SettingsChip(
                    label: settings.backgroundPhoto == null
                        ? 'Elegir imagen…'
                        : SkinBackground.photo.label,
                    selected: custom.background == SkinBackground.photo,
                    onTap: () {
                      if (settings.backgroundPhoto == null) {
                        _pickPhoto(context);
                      } else {
                        settings.customSkin = custom.copyWith(
                          background: SkinBackground.photo,
                        );
                      }
                    },
                  ),
                ],
              ),
              if (custom.background == SkinBackground.photo)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      TextButton.icon(
                        onPressed: () => _pickPhoto(context),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Cambiar imagen'),
                        style: TextButton.styleFrom(foregroundColor: kAccent),
                      ),
                      TextButton.icon(
                        onPressed: () => settings.backgroundPhoto = null,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Quitar'),
                        style: TextButton.styleFrom(
                          foregroundColor: kMutedText,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
        _Group(
          title: 'Imagen de fondo',
          icon: Icons.image_outlined,
          children: [
            _Choices(
              children: [
                for (final mode in BackgroundMode.values)
                  SettingsChip(
                    label: mode.label,
                    selected: settings.backgroundMode == mode,
                    onTap: () => settings.backgroundMode = mode,
                  ),
              ],
            ),
            const _Help(
              'Con una para cada jugador, los dos la ven entera y derecha '
              'desde su lado de la mesa.',
            ),
            const _Label('Opacidad de la imagen'),
            _PercentSlider(
              value: settings.imageOpacity,
              min: 0,
              label: 'Opacidad de la imagen',
              onChanged: (v) => settings.imageOpacity = v,
            ),
            _Choices(
              children: [
                for (final (name, value) in const [
                  ('Nítida', 100),
                  ('Suave', 60),
                  ('Tenue', 30),
                ])
                  SettingsChip(
                    label: '$name · $value %',
                    selected: settings.imageOpacity == value,
                    onTap: () => settings.imageOpacity = value,
                  ),
              ],
            ),
            const _Help(
              'Cuanto más baja, más se ve el color del jugador y mejor se lee '
              'el número.',
            ),
            SettingsSwitch(
              title: 'Foco en el número',
              subtitle: 'Oscurece la imagen solo detrás del número.',
              value: settings.focus,
              onChanged: (v) => settings.focus = v,
            ),
          ],
        ),
        _Group(
          title: 'Paneles',
          icon: Icons.splitscreen_outlined,
          children: [
            const _Label('Mitad que suma y mitad que resta', first: true),
            _Choices(
              children: [
                for (final marks in ZoneMarks.values)
                  SettingsChip(
                    label: marks.label,
                    selected: settings.zoneMarks == marks,
                    onTap: () => settings.zoneMarks = marks,
                  ),
              ],
            ),
            SettingsSwitch(
              title: 'Animaciones al cambiar vidas',
              subtitle:
                  'Al perder, el número se sacude y el borde se tiñe de rojo; '
                  'al ganar, brilla en verde.',
              value: settings.animations,
              onChanged: (v) => settings.animations = v,
            ),
          ],
        ),
        _Group(
          title: 'Transparencia',
          icon: Icons.opacity_outlined,
          children: [
            const _Label('Barra central', first: true),
            _PercentSlider(
              value: settings.barOpacity,
              min: AppSettings.minBarOpacity,
              label: 'Opacidad de la barra central',
              onChanged: (v) => settings.barOpacity = v,
            ),
            if (settings.showHistory) ...[
              const _Label('Historial'),
              _PercentSlider(
                value: settings.historyOpacity,
                min: 0,
                label: 'Opacidad del historial',
                onChanged: (v) => settings.historyOpacity = v,
              ),
            ],
            if (settings.theme == AppTheme.classic) ...[
              const _Label('Marco'),
              _PercentSlider(
                value: settings.frameOpacity,
                min: AppSettings.minFrameOpacity,
                label: 'Opacidad del marco',
                onChanged: (v) => settings.frameOpacity = v,
              ),
            ],
            const _Help(
              'Por debajo de 100 % se transparenta la imagen de fondo. El '
              'número y los botones + y − siempre van opacos.',
            ),
          ],
        ),
        Center(
          child: TextButton.icon(
            onPressed: () => _confirmResetLook(context),
            icon: const Icon(Icons.restart_alt),
            label: const Text('Volver al aspecto por defecto'),
            style: TextButton.styleFrom(foregroundColor: kAccent),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmResetLook(BuildContext context) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kCardColor,
        title: const Text(
          'Volver al aspecto por defecto',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'La imagen de fondo, el foco, las mitades, las transparencias y las '
          'animaciones vuelven a lo que trae cada tema. El tema, la skin y '
          'la partida se quedan como están.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Colors.white),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Restablecer', style: TextStyle(color: kAccent)),
          ),
        ],
      ),
    );
    if (accepted == true) await settings.resetLook();
  }

  /// Activa o quita el reloj de ajedrez. Al quitarlo, si el reloj de la
  /// partida es de ajedrez se reinicia (y vuelve a lo de por defecto); si ya
  /// había empezado, pregunta antes.
  Future<void> _setChess(BuildContext context, bool value) async {
    if (!value && timer.chess && timer.started) {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: kCardColor,
          title: const Text(
            'Quitar el reloj de ajedrez',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'El reloj de esta partida es de ajedrez y ya ha empezado. Al '
            'quitarlo se reinicia.',
            style: TextStyle(color: kMutedText),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: kAccent),
              child: const Text('Quitar y reiniciar'),
            ),
          ],
        ),
      );
      if (accepted != true) return;
    }
    settings.chessEnabled = value;
    if (!value && timer.chess) timer.reset();
  }

  Widget _game(BuildContext context) {
    final mode = settings.timerMode;
    final chess = settings.chessClock;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
      children: [
        // Lo que se ve en la pantalla de la partida, en el orden de la
        // bienvenida.
        _Group(
          title: 'En pantalla',
          icon: Icons.visibility_outlined,
          children: [
            SettingsSwitch(
              title: 'Historial de vidas',
              subtitle:
                  'Oculto se sigue apuntando: al volver a enseñarlo sale '
                  'entero. Sin él, el número se centra en el panel.',
              value: settings.showHistory,
              onChanged: (v) => settings.showHistory = v,
            ),
            SettingsSwitch(
              title: 'Temporizador de ronda',
              subtitle: chess
                  ? 'El reloj en la barra. Con el reloj de ajedrez tiene que '
                        'estar: ahí se pone el tiempo y se pausa.'
                  : 'El reloj en la barra.',
              value: settings.showTimer,
              onChanged: chess ? null : (v) => settings.showTimer = v,
            ),
            SettingsSwitch(
              title: 'Cantidad por toque (− 1 +)',
              subtitle:
                  'Para sumar o restar más de una vida de golpe. Sin ella, '
                  'cada toque cuenta 1.',
              value: settings.showStepper,
              onChanged: (v) => settings.showStepper = v,
            ),
          ],
        ),
        _Group(
          title: 'Temporizador',
          icon: Icons.timer_outlined,
          children: [
            // Activa la función: sin esto no se puede elegir «Ajedrez» ni
            // aquí ni en el reloj de la barra.
            SettingsSwitch(
              title: 'Reloj de ajedrez',
              subtitle:
                  'Reparte el tiempo de la ronda entre los dos, con un botón '
                  'en cada panel. Activado, se puede elegir aquí y en el '
                  'reloj de la barra.',
              value: settings.chessEnabled,
              onChanged: (v) => _setChess(context, v),
            ),
            const SizedBox(height: 8),
            const Text(
              'Modo por defecto',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            // Lo de aquí es lo de por defecto: no toca el reloj de la partida
            // de ahora, que lo coge al reiniciarse.
            const _Help(
              'Así empieza el reloj cada vez que lo reinicias. Cambiarlo no '
              'toca el de la partida de ahora: ese se cambia en el reloj de '
              'la barra.',
            ),
            const SizedBox(height: 8),
            _Choices(
              children: [
                for (final m in TimerMode.values)
                  if (m != TimerMode.chess || settings.chessEnabled)
                    SettingsChip(
                      label: m.label,
                      selected: mode == m,
                      onTap: () => settings.timerMode = m,
                    ),
              ],
            ),
            _Help(switch (mode) {
              TimerMode.countdown =>
                'Cuenta hacia cero el tiempo de la ronda. En la partida '
                    'también se cambia desde el reloj de la barra.',
              TimerMode.stopwatch =>
                'Cuenta hacia delante lo que dura la partida, sin límite '
                    'ni aviso.',
              TimerMode.chess =>
                'El tiempo de la ronda se reparte entre los dos. Cada uno '
                    'tiene un botón en su panel: al pulsarlo se para su reloj '
                    'y corre el del otro. Lo arranca quien no empieza. Quien '
                    'se pasa sigue contando, en rojo.',
            }),
            if (mode != TimerMode.stopwatch) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Duración de la ronda',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                        Text(
                          chess
                              ? '${formatClock(Duration(minutes: settings.roundMinutes) ~/ 2)} '
                                    'para cada jugador'
                              : 'Por defecto, 50 minutos',
                          style: const TextStyle(
                            color: kMutedText,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Builder(
                    builder: (context) {
                      final step =
                          settings.roundMinutes > AppSettings.minRoundMinutes
                          ? () => settings.roundMinutes -= 1
                          : null;
                      return HoldToRepeat(
                        onStep: step,
                        label: 'Un minuto menos',
                        child: IconButton(
                          color: Colors.white,
                          onPressed: step,
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                      );
                    },
                  ),
                  SizedBox(
                    width: 58,
                    child: Text(
                      '${settings.roundMinutes} min',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Builder(
                    builder: (context) {
                      final step =
                          settings.roundMinutes < AppSettings.maxRoundMinutes
                          ? () => settings.roundMinutes += 1
                          : null;
                      return HoldToRepeat(
                        onStep: step,
                        label: 'Un minuto más',
                        child: IconButton(
                          color: Colors.white,
                          onPressed: step,
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      );
                    },
                  ),
                ],
              ),
              SettingsSwitch(
                title: chess
                    ? 'Avisar a falta de 2 minutos'
                    : 'Avisar a falta de 5 minutos',
                subtitle: chess
                    ? 'El botón de cada jugador se pone ámbar.'
                    : 'El reloj de la barra se pone ámbar.',
                value: settings.timerWarning,
                onChanged: (v) => settings.timerWarning = v,
              ),
              SettingsSwitch(
                title: chess
                    ? 'Vibrar al pulsar y al acabarse'
                    : 'Vibrar al acabar el tiempo',
                subtitle: chess
                    ? 'Un toque corto al pasar el turno y tres si a alguien '
                          'se le acaba el suyo.'
                    : 'Un aviso que se nota con el móvil en la mesa.',
                value: settings.timerVibrate,
                onChanged: (v) => settings.timerVibrate = v,
              ),
            ],
            // Si el reloj de ahora va con otra cosa, se dice hasta cuándo.
            ListenableBuilder(
              listenable: timer.modeListenable,
              builder: (context, _) {
                final length = Duration(minutes: settings.roundMinutes);
                final same =
                    timer.mode == mode &&
                    (mode == TimerMode.stopwatch ||
                        timer.roundLength == length);
                if (same) return const SizedBox.shrink();
                final now = timer.mode == TimerMode.stopwatch
                    ? 'Cronómetro'
                    : '${timer.mode.label} de '
                          '${formatClock(timer.roundLength)}';
                return _Help(
                  'La partida de ahora sigue con $now hasta que reinicies el '
                  'reloj desde la barra.',
                );
              },
            ),
          ],
        ),
        _Group(
          title: 'Partida',
          icon: Icons.save_outlined,
          children: [
            SettingsSwitch(
              title: 'Recordar la partida',
              subtitle:
                  'Si se cierra la app, las vidas y el historial siguen igual '
                  'al volver.',
              value: settings.rememberGame,
              onChanged: (v) => settings.rememberGame = v,
            ),
            SettingsSwitch(
              title: 'Mantener la pantalla encendida',
              subtitle: 'Para que no se apague con el móvil en la mesa.',
              value: settings.keepScreenOn,
              onChanged: (v) => settings.keepScreenOn = v,
            ),
          ],
        ),
      ],
    );
  }
}

/// Un grupo de ajustes: una tarjeta con su título.
class _Group extends StatelessWidget {
  const _Group({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    // Un Material y no una caja de color: si no, el brillo al tocar los
    // interruptores queda por debajo de la tarjeta y no se ve.
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: kCardColor,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Icon(icon, color: kAccent, size: 20),
                    const SizedBox(width: 10),
                    // Con la letra del sistema grande, el título salta de
                    // línea en vez de salirse de la tarjeta.
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

/// Una fila de chips que salta de línea si no cabe.
class _Choices extends StatelessWidget {
  const _Choices({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 8, runSpacing: 8, children: children);
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text, {this.first = false});

  final String text;

  /// Si es lo primero del grupo, va pegada al título.
  final bool first;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: first ? 0 : 16, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(color: Color(0xFFD4D4D8), fontSize: 14),
      ),
    );
  }
}

class _Help extends StatelessWidget {
  const _Help(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        text,
        style: const TextStyle(color: kMutedText, fontSize: 13, height: 1.4),
      ),
    );
  }
}

/// Deslizador de porcentaje de 5 en 5, con el valor al lado.
class _PercentSlider extends StatelessWidget {
  const _PercentSlider({
    required this.value,
    required this.min,
    required this.label,
    required this.onChanged,
  });

  final int value;
  final int min;
  final String label;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Slider(
            value: value.toDouble(),
            min: min.toDouble(),
            max: 100,
            divisions: (100 - min) ~/ 5,
            label: '$value %',
            semanticFormatterCallback: (v) => '$label: ${v.round()} %',
            activeColor: kAccent,
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
        SizedBox(
          width: 52,
          child: Text(
            '$value %',
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

/// Tarjeta de una skin con una miniatura del contador: fondo, los dos
/// paneles y la barra.
List<List<T>> _pairs<T>(List<T> items) => [
  for (var i = 0; i < items.length; i += 2)
    items.sublist(i, (i + 2).clamp(0, items.length)),
];

class SkinCard extends StatelessWidget {
  const SkinCard({
    super.key,
    required this.skin,
    required this.image,
    required this.selected,
    required this.onTap,
    this.imageHeight = 84,
  });

  final Skin skin;
  final ImageProvider? image;
  final bool selected;
  final VoidCallback onTap;

  /// El alto de la muestra; en la bienvenida va más baja.
  final double imageHeight;

  @override
  Widget build(BuildContext context) {
    final image = this.image;
    return Semantics(
      button: true,
      selected: selected,
      label: 'Skin ${skin.name}',
      child: Material(
        color: kCardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: selected ? kAccent : Colors.transparent,
            width: 2,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: imageHeight,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(8),
                    image: image == null
                        ? null
                        : DecorationImage(image: image, fit: BoxFit.cover),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: ColoredBox(color: skin.topPanel)),
                      SizedBox(
                        height: 10,
                        child: ColoredBox(color: skin.barColor),
                      ),
                      Expanded(child: ColoredBox(color: skin.bottomPanel)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  skin.name,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Fila de muestras de color más un botón para elegir cualquier otro.
class _ColorRow extends StatelessWidget {
  const _ColorRow({
    required this.label,
    required this.color,
    required this.onChanged,
  });

  final String label;
  final Color color;
  final ValueChanged<Color> onChanged;

  Future<void> _pickColor(BuildContext context) async {
    var picked = color;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kCardColor,
        title: Text(label, style: const TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: color,
            onColorChanged: (c) => picked = c,
            enableAlpha: false,
            labelTypes: const [],
            pickerAreaHeightPercent: 0.7,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Colors.white),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Aceptar', style: TextStyle(color: kAccent)),
          ),
        ],
      ),
    );
    if (accepted == true) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final isCustom = !kSwatches.any((s) => s.toARGB32() == color.toARGB32());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(label),
        Wrap(
          spacing: 9,
          runSpacing: 9,
          children: [
            for (final swatch in kSwatches)
              _Swatch(
                color: swatch,
                selected: swatch.toARGB32() == color.toARGB32(),
                onTap: () => onChanged(swatch),
              ),
            _Swatch(
              color: isCustom ? color : const Color(0xFF2C2C2E),
              selected: isCustom,
              icon: Icons.palette_outlined,
              semanticLabel: 'Otro color para ${label.toLowerCase()}',
              onTap: () => _pickColor(context),
            ),
          ],
        ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.onTap,
    this.icon,
    this.semanticLabel,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel ?? 'Color',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? kAccent : Colors.white24,
              width: selected ? 3 : 1.5,
            ),
          ),
          child: icon == null
              ? null
              : Icon(icon, size: 18, color: Colors.white),
        ),
      ),
    );
  }
}

class SettingsChip extends StatelessWidget {
  const SettingsChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;

  /// Null si ahora no se puede elegir.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final onTap = this.onTap;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: onTap == null ? null : (_) => onTap(),
      showCheckmark: false,
      backgroundColor: const Color(0xFF2C2C2E),
      selectedColor: kAccent,
      side: BorderSide.none,
      shape: const StadiumBorder(),
      labelStyle: TextStyle(
        color: selected
            ? const Color(0xFF1A1306)
            : Colors.white.withValues(alpha: onTap == null ? 0.38 : 1),
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class SettingsSwitch extends StatelessWidget {
  const SettingsSwitch({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;

  /// La explicación de debajo; sin ella la fila es más baja.
  final String? subtitle;
  final bool value;

  /// Null si no se puede cambiar.
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(color: Colors.white)),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, style: const TextStyle(color: kMutedText)),
      value: value,
      onChanged: onChanged,
      activeThumbColor: Colors.white,
      activeTrackColor: kAccent,
    );
  }
}

/// Miniatura del contador con los ajustes de ahora y una partida de ejemplo.
/// Es la pantalla de verdad en pequeño, así que no responde a toques.
class CounterPreview extends StatefulWidget {
  const CounterPreview({
    super.key,
    required this.settings,
    required this.timer,
  });

  final AppSettings settings;
  final RoundTimer timer;

  @override
  State<CounterPreview> createState() => _CounterPreviewState();
}

class _CounterPreviewState extends State<CounterPreview> {
  // Tamaño de pantalla de un móvil normal; luego se encoge a la miniatura.
  static const Size _screen = Size(412, 880);

  final GameState _game = GameState();
  final ValueNotifier<bool> _reset = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _game.top
      ..change(-5)
      ..commit()
      ..change(2)
      ..commit();
    _game.bottom
      ..change(-3)
      ..commit()
      ..change(-6)
      ..commit();
    _game.toggleRotation();
  }

  @override
  void dispose() {
    _game.dispose();
    _reset.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;
    final look = settings.look;
    void none() {}
    final bar = CenterBar(
      look: look,
      color: barColorFor(settings),
      players: settings.skin.cardFrames,
      alpha: settings.barOpacity / 100,
      leading: [
        BarAction(Icons.refresh, 'Reiniciar partida', none),
        BarAction(Icons.swap_vert, 'Girar el panel de arriba', none),
      ],
      timer: settings.showTimer || widget.timer.chess
          ? TimerButton(
              timer: widget.timer,
              look: look,
              warningEnabled: settings.timerWarning,
              onTap: none,
            )
          : null,
      // La cantidad por toque, si está activada: no se toca, solo se ve.
      stepper: settings.showStepper
          ? (color, compact, mana) => NumberStepper(
              resetNotifier: _reset,
              color: color,
              compact: compact,
              mana: mana,
              onChanged: (_) {},
            )
          : null,
      trailing: [
        BarAction(Icons.shuffle, 'Sorteos', none),
        BarAction(Icons.settings_outlined, 'Ajustes', none),
      ],
    );
    return Semantics(
      label: 'Vista previa del contador',
      child: ExcludeSemantics(
        child: IgnorePointer(
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: const Color(0xFF2C2C2E),
              borderRadius: BorderRadius.circular(14),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: AspectRatio(
                aspectRatio: _screen.width / _screen.height,
                child: FittedBox(
                  child: SizedBox.fromSize(
                    size: _screen,
                    child: MediaQuery.removePadding(
                      context: context,
                      removeTop: true,
                      removeBottom: true,
                      child: ColoredBox(
                        color: Colors.black,
                        child: CounterLayout(
                          settings: settings,
                          game: _game,
                          bar: bar,
                          timer: widget.timer,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
