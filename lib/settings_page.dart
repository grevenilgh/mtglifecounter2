import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mtglifecounter/app_settings.dart';
import 'package:mtglifecounter/center_bar.dart';
import 'package:mtglifecounter/counter_layout.dart';
import 'package:mtglifecounter/game_state.dart';
import 'package:mtglifecounter/look.dart';
import 'package:mtglifecounter/round_timer.dart';
import 'package:mtglifecounter/skin.dart';
import 'package:mtglifecounter/timer_view.dart';

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
const _themeChoices = [
  ('De siempre', AppTheme.original, null),
  ('Cristal', AppTheme.modern, ModernVariant.glass),
  ('Tarjetas', AppTheme.modern, ModernVariant.cards),
  ('Old Border', AppTheme.classic, null),
];

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.settings, required this.timer});

  final AppSettings settings;

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
              TabBarView(children: [_design(context), _game()]),
        ),
      ),
    );
  }

  Widget _design(BuildContext context) {
    final custom = settings.customSkin;
    // El tema y la miniatura van fijos arriba: así se ve el resultado de
    // todo lo que se toca más abajo sin salir de Ajustes.
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 104,
                child: _Preview(settings: settings, timer: timer),
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
                        for (final (label, theme, variant) in _themeChoices)
                          _Chip(
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
        ),
        const Divider(height: 1, color: Color(0xFF2C2C2E)),
        Expanded(child: _designOptions(context, custom)),
      ],
    );
  }

  Widget _designOptions(BuildContext context, Skin custom) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
      children: [
        _Group(
          title: 'Skin',
          icon: Icons.color_lens_outlined,
          children: [
            Row(
              children: [
                for (final skin in [...Skin.presets, custom]) ...[
                  if (skin != Skin.presets.first) const SizedBox(width: 10),
                  Expanded(
                    child: _SkinCard(
                      skin: skin,
                      image: settings.backgroundOf(skin),
                      selected: settings.skinId == skin.id,
                      onTap: () => settings.skinId = skin.id,
                    ),
                  ),
                ],
              ],
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
                      _Chip(
                        label: background.label,
                        selected: custom.background == background,
                        onTap: () => settings.customSkin = custom.copyWith(
                          background: background,
                        ),
                      ),
                  _Chip(
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
                  _Chip(
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
                  _Chip(
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
            _SwitchRow(
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
                  _Chip(
                    label: marks.label,
                    selected: settings.zoneMarks == marks,
                    onTap: () => settings.zoneMarks = marks,
                  ),
              ],
            ),
            _SwitchRow(
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
            const _Label('Historial'),
            _PercentSlider(
              value: settings.historyOpacity,
              min: 0,
              label: 'Opacidad del historial',
              onChanged: (v) => settings.historyOpacity = v,
            ),
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
      ],
    );
  }

  Widget _game() {
    final countdown = settings.timerMode == TimerMode.countdown;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
      children: [
        _Group(
          title: 'Barra central',
          icon: Icons.view_agenda_outlined,
          children: [
            _SwitchRow(
              title: 'Cantidad por toque (− 1 +)',
              subtitle:
                  'Para sumar o restar más de una vida de golpe. Sin ella, '
                  'cada toque cuenta 1.',
              value: settings.showStepper,
              onChanged: (v) => settings.showStepper = v,
            ),
            _SwitchRow(
              title: 'Temporizador de ronda',
              subtitle: 'El reloj en la barra.',
              value: settings.showTimer,
              onChanged: (v) => settings.showTimer = v,
            ),
          ],
        ),
        _Group(
          title: 'Temporizador',
          icon: Icons.timer_outlined,
          children: [
            _Choices(
              children: [
                for (final mode in TimerMode.values)
                  _Chip(
                    label: mode.label,
                    selected: settings.timerMode == mode,
                    onTap: () => settings.timerMode = mode,
                  ),
              ],
            ),
            _Help(
              countdown
                  ? 'Cuenta hacia cero el tiempo de la ronda. También se cambia '
                        'desde el reloj de la barra.'
                  : 'Cuenta hacia delante lo que dura la partida, sin límite '
                        'ni aviso.',
            ),
            if (countdown) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Duración de la ronda',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                        Text(
                          'Por defecto, 50 minutos',
                          style: TextStyle(color: kMutedText, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cinco minutos menos',
                    color: Colors.white,
                    onPressed:
                        settings.roundMinutes > AppSettings.minRoundMinutes
                        ? () => settings.roundMinutes -= 5
                        : null,
                    icon: const Icon(Icons.remove_circle_outline),
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
                  IconButton(
                    tooltip: 'Cinco minutos más',
                    color: Colors.white,
                    onPressed:
                        settings.roundMinutes < AppSettings.maxRoundMinutes
                        ? () => settings.roundMinutes += 5
                        : null,
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
              _SwitchRow(
                title: 'Avisar a falta de 5 minutos',
                subtitle: 'El reloj de la barra se pone ámbar.',
                value: settings.timerWarning,
                onChanged: (v) => settings.timerWarning = v,
              ),
              _SwitchRow(
                title: 'Vibrar al acabar el tiempo',
                subtitle: 'Un aviso que se nota con el móvil en la mesa.',
                value: settings.timerVibrate,
                onChanged: (v) => settings.timerVibrate = v,
              ),
            ],
          ],
        ),
        _Group(
          title: 'Partida',
          icon: Icons.save_outlined,
          children: [
            _SwitchRow(
              title: 'Recordar la partida',
              subtitle:
                  'Si se cierra la app, las vidas y el historial siguen igual '
                  'al volver.',
              value: settings.rememberGame,
              onChanged: (v) => settings.rememberGame = v,
            ),
            _SwitchRow(
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
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Icon(icon, color: kAccent, size: 20),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          ...children,
        ],
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
class _SkinCard extends StatelessWidget {
  const _SkinCard({
    required this.skin,
    required this.image,
    required this.selected,
    required this.onTap,
  });

  final Skin skin;
  final ImageProvider? image;
  final bool selected;
  final VoidCallback onTap;

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
                  height: 100,
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

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      backgroundColor: const Color(0xFF2C2C2E),
      selectedColor: kAccent,
      side: BorderSide.none,
      shape: const StadiumBorder(),
      labelStyle: TextStyle(
        color: selected ? const Color(0xFF1A1306) : Colors.white,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(color: Colors.white)),
      subtitle: Text(subtitle, style: const TextStyle(color: kMutedText)),
      value: value,
      onChanged: onChanged,
      activeThumbColor: Colors.white,
      activeTrackColor: kAccent,
    );
  }
}

/// Miniatura del contador con los ajustes de ahora y una partida de ejemplo.
/// Es la pantalla de verdad en pequeño, así que no responde a toques.
class _Preview extends StatefulWidget {
  const _Preview({required this.settings, required this.timer});

  final AppSettings settings;
  final RoundTimer timer;

  @override
  State<_Preview> createState() => _PreviewState();
}

class _PreviewState extends State<_Preview> {
  // Tamaño de pantalla de un móvil normal; luego se encoge a la miniatura.
  static const Size _screen = Size(412, 880);

  final GameState _game = GameState();

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
      alpha: settings.barOpacity / 100,
      leading: [
        BarAction(Icons.refresh, 'Reiniciar partida', none),
        BarAction(Icons.swap_vert, 'Girar el panel de arriba', none),
      ],
      timer: settings.showTimer
          ? TimerButton(
              timer: widget.timer,
              look: look,
              warningEnabled: settings.timerWarning,
              onTap: none,
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
