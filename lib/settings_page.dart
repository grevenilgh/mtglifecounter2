import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mtglifecounter/app_settings.dart';
import 'package:mtglifecounter/skin.dart';

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

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.settings});

  final AppSettings settings;

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
    return Scaffold(
      backgroundColor: kSettingsBackground,
      appBar: AppBar(
        title: const Text('Ajustes'),
        backgroundColor: kSettingsBackground,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) {
          final custom = settings.customSkin;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 36),
            children: [
              const _SectionTitle('Aspecto'),
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
                const _Label('Imagen de fondo'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
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
              const _SectionTitle('Partida'),
              _SettingsCard(
                children: [
                  _SwitchRow(
                    title: 'Recordar la partida',
                    subtitle:
                        'Si se cierra la app, las vidas y el historial siguen igual al volver.',
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
        },
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: kMutedText,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(color: Color(0xFFD4D4D8), fontSize: 14),
      ),
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
            child: const Text('Cancelar', style: TextStyle(color: Colors.white)),
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

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: Color(0xFF2C2C2E)),
            children[i],
          ],
        ],
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
      title: Text(title, style: const TextStyle(color: Colors.white)),
      subtitle: Text(subtitle, style: const TextStyle(color: kMutedText)),
      value: value,
      onChanged: onChanged,
      activeThumbColor: Colors.white,
      activeTrackColor: kAccent,
    );
  }
}
