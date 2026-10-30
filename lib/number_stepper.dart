import 'package:flutter/material.dart';
import 'package:auto_size_text/auto_size_text.dart';

class NumberStepper extends StatefulWidget {
  final int initialValue;
  final ValueChanged<int> onChanged;
  final ValueNotifier<bool> resetNotifier;

  /// Color de los botones y del número, para que encaje con la barra del tema.
  final Color color;

  /// Versión pequeña para las barras flotantes, más bajas que la de siempre.
  final bool compact;

  const NumberStepper({
    super.key,
    this.initialValue = 1,
    required this.onChanged,
    required this.resetNotifier,
    this.color = Colors.white,
    this.compact = false,
  });

  @override
  State<NumberStepper> createState() => _NumberStepperState();
}

class _NumberStepperState extends State<NumberStepper> {
  late int _currentValue;

  @override
  void initState() {
    super.initState();
    _currentValue = widget.initialValue;
    widget.resetNotifier.addListener(_reset);
  }

  @override
  void dispose() {
    widget.resetNotifier.removeListener(_reset);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant NumberStepper oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.initialValue != oldWidget.initialValue) {
      setState(() {
        _currentValue = widget.initialValue;
      });
    }
  }

  void _reset() {
    setState(() {
      _currentValue = 1;
      widget.onChanged(_currentValue);
    });
  }

  void _increment([int cantidad = 1]) {
    setState(() {
      _currentValue = _currentValue + cantidad;
      widget.onChanged(_currentValue);
    });
  }

  void _decrement([int cantidad = 1]) {
    if (_currentValue > 1) {
      setState(() {
        _currentValue = _currentValue - cantidad;
        widget.onChanged(_currentValue);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final iconSize = widget.compact ? 26.0 : 40.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(Icons.remove_circle, color: widget.color, size: iconSize),
          visualDensity: widget.compact ? VisualDensity.compact : null,
          onPressed: _currentValue > 1 ? _decrement : null,
          onLongPress: _currentValue > 10 ? () => _decrement(10) : null,
        ),
        SizedBox(
          width: widget.compact ? 40 : 56,
          child: AutoSizeText(
            '$_currentValue',
            style: TextStyle(
              color: widget.color,
              fontSize: widget.compact ? 30 : 50,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            minFontSize: 18,
          ),
        ),
        IconButton(
          icon: Icon(Icons.add_circle, color: widget.color, size: iconSize),
          visualDensity: widget.compact ? VisualDensity.compact : null,
          onPressed: _currentValue < 99 ? _increment : null,
          onLongPress: _currentValue < 90 ? () => _increment(10) : null,
        ),
      ],
    );
  }
}
