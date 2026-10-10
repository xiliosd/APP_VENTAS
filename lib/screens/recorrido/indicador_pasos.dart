import 'package:flutter/material.dart';

import '../../ui/colores_app.dart';

/// "Paso N de 4" con una barra de avance.
class IndicadorPasos extends StatelessWidget {
  const IndicadorPasos({super.key, required this.paso, this.total = 4});

  final int paso;
  final int total;

  @override
  Widget build(BuildContext context) {
    final c = ColoresApp.of(context);
    return Column(
      key: const Key('indicador_pasos'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Paso $paso de $total',
            style: TextStyle(
                color: c.textoSecundario, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: paso / total,
            minHeight: 6,
            color: c.primario,
            backgroundColor: c.primarioSuave,
          ),
        ),
      ],
    );
  }
}
