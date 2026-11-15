import 'package:flutter/material.dart';
import 'package:mtglifecounter/app_settings.dart';
import 'package:mtglifecounter/themed_style.dart';

export 'package:mtglifecounter/themed_style.dart' show kDangerRed;

/// Pide confirmación con un diálogo vestido como el tema elegido (ver
/// [ThemedStyle]): el gris de la barra en Original, un panel de cristal, una
/// tarjeta oscura con los colores de los jugadores o, en el Old Border, una
/// carta antigua con botones de maná.
///
/// Devuelve `true` solo si se pulsa [confirmLabel]. Con [destructive] ese
/// botón va en rojo. Entra con una animación corta que se acaba sola.
Future<bool> showThemedConfirm(
  BuildContext context, {
  required AppSettings settings,
  required IconData icon,
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancelar',
  bool destructive = false,
}) async {
  final accepted = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: cancelLabel,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, _, _) => ThemedDialog(
      style: ThemedStyle.of(settings.look, settings.skin),
      icon: icon,
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      destructive: destructive,
    ),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeIn,
      );
      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.88, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
  return accepted ?? false;
}

/// El diálogo de [showThemedConfirm].
class ThemedDialog extends StatelessWidget {
  const ThemedDialog({
    super.key,
    required this.style,
    required this.icon,
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.destructive,
  });

  final ThemedStyle style;
  final IconData icon;
  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    void close(bool value) => Navigator.of(context).pop(value);

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        style.badge(icon, danger: destructive),
        const SizedBox(height: 14),
        Text(title, textAlign: TextAlign.center, style: style.titleStyle),
        const SizedBox(height: 10),
        Text(message, textAlign: TextAlign.center, style: style.bodyStyle),
        const SizedBox(height: 22),
        // Si no caben uno al lado del otro (letra muy grande), uno encima
        // del otro.
        LayoutBuilder(
          builder: (context, constraints) {
            final cancel = style.button(
              cancelLabel,
              kind: ButtonKind.plain,
              onTap: () => close(false),
            );
            final confirm = style.button(
              confirmLabel,
              kind: destructive ? ButtonKind.danger : ButtonKind.accent,
              onTap: () => close(true),
            );
            final textScale = MediaQuery.textScalerOf(context).scale(1);
            if (constraints.maxWidth < 240 || textScale > 1.3) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [confirm, const SizedBox(height: 10), cancel],
              );
            }
            return Row(
              children: [
                Expanded(child: cancel),
                const SizedBox(width: 12),
                Expanded(child: confirm),
              ],
            );
          },
        ),
      ],
    );

    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Material(
              type: MaterialType.transparency,
              child: Semantics(
                scopesRoute: true,
                namesRoute: true,
                explicitChildNodes: true,
                label: title,
                child: style.frame(content),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
