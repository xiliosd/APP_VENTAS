import 'package:flutter/material.dart';

import 'colores_app.dart';
import 'estado_vacio.dart';

/// Aviso amable cuando una pantalla no logra cargar sus datos; nunca muestra
/// el texto técnico de la excepción porque la tendera no puede actuar sobre él.
class ErrorCarga extends StatelessWidget {
  const ErrorCarga({super.key, this.compacto = false});

  /// En una fila o tarjeta se muestra solo una línea de texto.
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    if (compacto) {
      return Text(
        'No se pudo cargar',
        style: TextStyle(color: ColoresApp.of(context).textoSecundario),
      );
    }
    // Con poco alto (filtros arriba, letra grande) se desplaza en vez de
    // desbordar; con espacio de sobra queda centrado.
    return LayoutBuilder(
      builder: (context, restricciones) {
        const aviso = EstadoVacio(
          icono: Icons.error_outline_rounded,
          titulo: 'No se pudo cargar',
          mensaje: 'Cierra la app y vuelve a abrirla',
        );
        if (!restricciones.hasBoundedHeight) return aviso;
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: restricciones.maxHeight),
            child: aviso,
          ),
        );
      },
    );
  }
}
