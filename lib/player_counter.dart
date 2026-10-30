import 'dart:async';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:mtglifecounter/game_state.dart';

/// Ancho de la franja del historial. No cuenta como zona de toque.
const double kHistoryWidth = 76;

class PlayerCounter extends StatefulWidget {
  final PlayerState player;
  final Color color;
  final int lifeChangeAmount;
  final VoidCallback onLifeChanged;

  const PlayerCounter({
    super.key,
    required this.player,
    required this.color,
    required this.lifeChangeAmount,
    required this.onLifeChanged,
  });

  @override
  State<PlayerCounter> createState() => _PlayerCounterState();
}

class _PlayerCounterState extends State<PlayerCounter> {
  final ScrollController _scrollController = ScrollController();

  // Variables para la lógica de debounce
  Timer? _debounceTimer;
  int _historyLength = 0;

  @override
  void initState() {
    super.initState();
    _historyLength = widget.player.history.length;
    widget.player.addListener(_onPlayerChanged);
    // Si la partida se ha recuperado, el historial empieza mostrando lo último.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    widget.player.removeListener(_onPlayerChanged);
    _scrollController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onPlayerChanged() {
    final length = widget.player.history.length;
    if (length < _historyLength) {
      // Se ha reiniciado la partida: lo que estuviera agrupándose ya no vale.
      _debounceTimer?.cancel();
    } else if (length > _historyLength) {
      // Realizamos el scroll al final del historial
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) return;
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
    _historyLength = length;
  }

  void _onTap(TapDownDetails details) {
    final width = context.size!.width;
    final height = context.size!.height;
    final tapX = details.localPosition.dx;
    final tapY = details.localPosition.dy;
    if (tapX >= width - kHistoryWidth) return;

    // La mitad de arriba suma y la de abajo resta.
    final change = tapY < height / 2
        ? widget.lifeChangeAmount
        : -widget.lifeChangeAmount;
    if (widget.player.change(change)) {
      widget.onLifeChanged();
    }

    // Los toques seguidos se agrupan: 750 ms después del último se apunta
    // una sola entrada en el historial.
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 750), _finalizeTap);
  }

  void _finalizeTap() {
    if (widget.player.pending == 0) return;
    widget.player.commit();
    widget.onLifeChanged();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTap,
      child: Container(
        color: widget.color,
        child: ListenableBuilder(
          listenable: widget.player,
          builder: (context, _) {
            final player = widget.player;
            final pending = player.pending;
            return Row(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      // El número de vida (se centra y se ajusta al hueco)
                      Center(
                        child: AutoSizeText(
                          '${player.life}',
                          style: const TextStyle(
                            fontSize: 500,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          minFontSize: 80,
                          textScaleFactor: 1.0,
                        ),
                      ),
                      // Icono visual para sumar
                      const Align(
                        alignment: Alignment.topCenter,
                        child: Padding(
                          padding: EdgeInsets.only(top: 10),
                          child: Icon(
                            Icons.add_circle,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                      // Icono visual para restar
                      const Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: EdgeInsets.only(bottom: 10),
                          child: Icon(
                            Icons.remove_circle,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                      // Burbuja con el cambio que aún no está en el historial
                      if (pending != 0)
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              pending > 0 ? '+$pending' : '$pending',
                              style: TextStyle(
                                color: pending > 0
                                    ? Colors.greenAccent
                                    : Colors.redAccent,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // El panel del historial
                SizedBox(
                  width: kHistoryWidth,
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.5),
                    child: ListView.builder(
                      controller: _scrollController,
                      itemCount: player.history.length,
                      itemBuilder: (context, index) {
                        return AutoSizeText(
                          player.history[index],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                          ),
                          textAlign: TextAlign.left,
                          maxLines: 1,
                          minFontSize: 12,
                          textScaleFactor: 1.0,
                        );
                      },
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
