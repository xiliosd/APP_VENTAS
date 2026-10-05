import 'package:flutter/material.dart';

import 'colores_app.dart';

/// Mensaje para una lista vacía: ícono, título, explicación y acción opcional.
class EstadoVacio extends StatelessWidget {
  const EstadoVacio({
    super.key,
    required this.icono,
    required this.titulo,
    this.mensaje,
    this.accion,
  });

  final IconData icono;
  final String titulo;
  final String? mensaje;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFFE8EDF8),
                shape: BoxShape.circle,
              ),
              child: Icon(icono, size: 32, color: ColoresApp.primario),
            ),
            const SizedBox(height: 16),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            if (mensaje != null) ...[
              const SizedBox(height: 4),
              Text(
                mensaje!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: ColoresApp.textoSecundario),
              ),
            ],
            if (accion != null) ...[const SizedBox(height: 16), accion!],
          ],
        ),
      ),
    );
  }
}
