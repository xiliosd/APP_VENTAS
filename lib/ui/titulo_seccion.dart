import 'package:flutter/material.dart';

import 'colores_app.dart';

/// Encabezado pequeño en mayúsculas sobre un grupo de tarjetas.
class TituloSeccion extends StatelessWidget {
  const TituloSeccion(this.texto, {super.key});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: ColoresApp.of(context).textoSecundario,
        ),
      ),
    );
  }
}
