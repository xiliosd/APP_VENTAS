import 'package:flutter/material.dart';

import 'aplastable.dart';

/// Botón redondo de −/+ para cantidades. Con [onPressed] null queda apagado.
class BotonCantidad extends StatelessWidget {
  const BotonCantidad({
    super.key,
    required this.icono,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icono;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Aplastable(
      habilitado: onPressed != null,
      child: IconButton.filledTonal(
        tooltip: tooltip,
        icon: Icon(icono),
        onPressed: onPressed,
        style: IconButton.styleFrom(minimumSize: const Size(40, 40)),
      ),
    );
  }
}
