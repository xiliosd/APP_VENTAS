import 'package:flutter/material.dart';

import 'colores_app.dart';

/// Selector de 2 a 4 opciones excluyentes, de ancho completo.
class SelectorSegmentado<T> extends StatelessWidget {
  const SelectorSegmentado({
    super.key,
    required this.opciones,
    required this.valor,
    required this.onCambio,
  });

  final Map<T, String> opciones;
  final T valor;
  final ValueChanged<T> onCambio;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<T>(
        segments: [
          for (final opcion in opciones.entries)
            ButtonSegment<T>(value: opcion.key, label: Text(opcion.value)),
        ],
        selected: {valor},
        showSelectedIcon: false,
        onSelectionChanged: (seleccion) => onCambio(seleccion.first),
        style: SegmentedButton.styleFrom(
          minimumSize: const Size(0, 48),
          selectedBackgroundColor: ColoresApp.primario,
          selectedForegroundColor: Colors.white,
          foregroundColor: ColoresApp.texto,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
