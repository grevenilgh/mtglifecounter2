import 'dart:math';

import 'package:flutter/material.dart';
import 'package:mtglifecounter/app_settings.dart';
import 'package:mtglifecounter/chess_clock.dart';
import 'package:mtglifecounter/game_state.dart';
import 'package:mtglifecounter/look.dart';
import 'package:mtglifecounter/player_counter.dart';
import 'package:mtglifecounter/round_timer.dart';

/// Color de la barra central. El borde antiguo no lo usa: su barra es una
/// carta dorada en todas las skins.
Color barColorFor(AppSettings settings) => settings.skin.bar;

/// La pantalla del contador: el fondo, los dos paneles y la barra. La usan la
/// pantalla principal y la miniatura de Ajustes.
class CounterLayout extends StatefulWidget {
  const CounterLayout({
    super.key,
    required this.settings,
    required this.game,
    required this.bar,
    this.lifeChangeAmount = 1,
    this.onLifeChanged,
    this.timer,
  });

  final AppSettings settings;
  final GameState game;
  final Widget bar;
  final int lifeChangeAmount;
  final VoidCallback? onLifeChanged;

  /// Con el reloj de ajedrez activado, cada panel lleva su botón.
  final RoundTimer? timer;

  @override
  State<CounterLayout> createState() => _CounterLayoutState();
}

class _CounterLayoutState extends State<CounterLayout> {
  // Con «una imagen para toda la pantalla» cada panel pinta su trozo
  // alineado con esta caja.
  final GlobalKey _screenKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;
    final game = widget.game;
    final skin = settings.skin;
    final look = settings.look;
    final style = PanelStyle(
      look: look,
      background: settings.backgroundOf(skin),
      backgroundMode: settings.backgroundMode,
      imageOpacity: settings.imageOpacity / 100,
      frameOpacity: settings.frameOpacity / 100,
      historyOpacity: settings.historyOpacity / 100,
      showHistory: settings.showHistory,
      zoneMarks: settings.zoneMarks,
      focus: settings.focus,
      animations: settings.animations,
      screenKey: _screenKey,
    );
    // En el borde antiguo cada jugador lleva el marco de carta que mejor va
    // con su color, y nunca el mismo que el otro (o el que elija la skin).
    final frames = skin.cardFrames;
    final timer = widget.timer;
    Widget panel(PlayerState player, Color color, CardFrame frame, Seat seat) =>
        PlayerCounter(
          player: player,
          color: color,
          frame: frame,
          style: style,
          lifeChangeAmount: widget.lifeChangeAmount,
          onLifeChanged: widget.onLifeChanged ?? () {},
          clock: timer != null && timer.chess
              ? ChessClockButton(
                  timer: timer,
                  seat: seat,
                  look: look,
                  color: color,
                  // En el borde antiguo, sin historial va sobre la ilustración.
                  darkInk: !settings.showHistory || frame.darkTextBox,
                  warningEnabled: settings.timerWarning,
                  vibrate: settings.timerVibrate,
                  animations: settings.animations,
                )
              : null,
        );
    return Stack(
      key: _screenKey,
      fit: StackFit.expand,
      children: [
        ScreenBackground(skin: skin, style: style),
        SafeArea(
          child: Padding(
            padding: switch (look.theme) {
              AppTheme.original => EdgeInsets.zero,
              AppTheme.modern =>
                look.isCards ? const EdgeInsets.all(12) : EdgeInsets.zero,
              // El marco de carta es gordo: ocupa el margen de antes.
              AppTheme.classic => const EdgeInsets.all(3),
            },
            child: Stack(
              children: [
                Column(
                  children: [
                    Expanded(
                      child: Transform.rotate(
                        angle: game.rotated ? pi : 0,
                        child: panel(game.top, skin.top, frames.$1, Seat.top),
                      ),
                    ),
                    SizedBox(height: look.barGap),
                    Expanded(
                      child: panel(
                        game.bottom,
                        skin.bottom,
                        frames.$2,
                        Seat.bottom,
                      ),
                    ),
                  ],
                ),
                // La barra va centrada: en el hueco entre los paneles o, en
                // cristal, flotando encima.
                Align(child: widget.bar),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
