// Puedes crear este widget en un archivo separado para mayor orden

import 'package:flutter/material.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'dart:async';

class PlayerCounter extends StatefulWidget {
  final int initialLife;
  final Color color;
  final ValueNotifier<bool> resetNotifier;
  final int lifeChangeAmount;
  final VoidCallback onLifeChanged;

  const PlayerCounter({
    super.key,
    required this.initialLife,
    required this.color,
    required this.resetNotifier,
    required this.lifeChangeAmount,
    required this.onLifeChanged,
  });

  @override
  State<PlayerCounter> createState() => _PlayerCounterState();
}

class _PlayerCounterState extends State<PlayerCounter> {
  late int _life;
  late int _lifeOld;
  List<String> _history = [];
  final ScrollController _scrollController = ScrollController();

  // Variables para la lógica de debounce
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _life = widget.initialLife;
    _lifeOld = widget.initialLife;
    widget.resetNotifier.addListener(_reset);
  }

  @override
  void dispose() {
    // 3. ¡Muy importante! Se desuscribe cuando el widget se elimina
    widget.resetNotifier.removeListener(_reset);
    _scrollController.dispose(); // También liberamos el controlador de scroll
    _debounceTimer
        ?.cancel(); // Cancelamos el temporizador al salir para evitar errores
    super.dispose();
  }

  void _reset() {
    setState(() {
      _life = widget.initialLife;
      _lifeOld = widget.initialLife;
      _history = [];
    });
  }

  void _onTap(TapDownDetails details) {
    final width = context.size!.width;
    final height = context.size!.height;
    final tapX = details.localPosition.dx;
    final tapY = details.localPosition.dy;
    int change;
    if (tapX < width - 78) {
      if (tapY < height / 2) {
        change = widget.lifeChangeAmount; // Toca la mitad izquierda, resta
      } else {
        change = -1 * (widget.lifeChangeAmount); // Toca la mitad derecha, suma
      }

      // Calcula el nuevo valor de vida
      final newLife = _life + change;

      // Comprueba si el nuevo valor está dentro del rango permitido
      if (newLife >= -999 && newLife <= 999) {
        setState(() {
          _life += change;

          // Llamamos al callback para notificar al padre
          widget.onLifeChanged();
        });
      }

      // Cancelamos el temporizador anterior si existe
      _debounceTimer?.cancel();

      // Creamos un nuevo temporizador que se disparará en 750ms
      _debounceTimer = Timer(const Duration(milliseconds: 750), _finalizeTap);
    }
  }

  // Este método se ejecuta cuando el usuario deja de pulsar por XXXms
  void _finalizeTap() {
    if (_life != _lifeOld) {
      setState(() {
        final change = _life - _lifeOld;
        _lifeOld = _life;
        // Añadimos el cambio acumulado al historial
        final sign = change > 0 ? '+' : '';
        _history.add('$sign$change = $_life');

        // Realizamos el scroll al final del historial
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        });
        widget.onLifeChanged();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTap,
      child: Container(
        color: widget.color,
        child: Row(
          children: [
            // El contador de vida (ocupa 2/3 del espacio, por ejemplo)
            Expanded(
              flex: 4,
              child: Stack(
                // <--- Se usa Stack en lugar de Column
                children: [
                  // El número de vida (se centra en toda la pantalla y se ajusta)
                  Center(
                    child: AutoSizeText(
                      '$_life',
                      style: const TextStyle(
                        fontSize:
                            500, // Un valor inicial grande para que se ajuste al máximo
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      minFontSize:
                          80, // Un mínimo bajo para evitar desbordamientos
                      textScaleFactor:
                          1.0, // Ignora el tamaño de fuente del sistema
                    ),
                  ),
                  // Icono visual para sumar (se alinea arriba, independientemente del texto)
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
                  // Icono visual para restar (se alinea abajo)
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
                  Center(
                    child: AnimatedOpacity(
                      opacity: (_life - _lifeOld) != 0
                          ? 1.0
                          : 0.0, // Visible si hay cambios
                      duration: const Duration(milliseconds: 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          (_life - _lifeOld) > 0
                              ? '+${_life - _lifeOld}'
                              : '${_life - _lifeOld}',
                          style: TextStyle(
                            color: (_life - _lifeOld) > 0
                                ? Colors.greenAccent
                                : (_life - _lifeOld) < 0
                                ? Colors.redAccent
                                : Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // El panel del historial (ocupa 1/3 del espacio)
            SizedBox(
              width: 76,
              child: Container(
                color: Colors.black.withOpacity(0.5),
                child: Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        controller: _scrollController,
                        itemCount: _history.length,
                        itemBuilder: (context, index) {
                          return AutoSizeText(
                            _history[index],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                            ),
                            textAlign: TextAlign.left,
                            maxLines: 1,
                            minFontSize:
                                12, // Un mínimo bajo para evitar desbordamientos
                            textScaleFactor: 1.0,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
