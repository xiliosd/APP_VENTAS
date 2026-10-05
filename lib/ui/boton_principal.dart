import 'package:flutter/material.dart';

import 'colores_app.dart';

enum VarianteBoton { primario, entra, contorno, peligro }

/// Botón grande de ancho completo. Con [onPressed] null queda deshabilitado.
class BotonPrincipal extends StatelessWidget {
  const BotonPrincipal({
    super.key,
    required this.texto,
    required this.onPressed,
    this.variante = VarianteBoton.primario,
    this.icono,
  });

  final String texto;
  final VoidCallback? onPressed;
  final VarianteBoton variante;
  final IconData? icono;

  @override
  Widget build(BuildContext context) {
    final contenido = icono == null
        ? Text(texto, textAlign: TextAlign.center)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icono, size: 20),
              const SizedBox(width: 8),
              Flexible(child: Text(texto, overflow: TextOverflow.ellipsis)),
            ],
          );
    final boton = switch (variante) {
      VarianteBoton.primario =>
        FilledButton(onPressed: onPressed, child: contenido),
      VarianteBoton.entra => FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: ColoresApp.entra,
            foregroundColor: Colors.white,
          ),
          child: contenido,
        ),
      VarianteBoton.contorno => OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: ColoresApp.primario,
            side: const BorderSide(color: ColoresApp.primario, width: 1.5),
          ),
          child: contenido,
        ),
      VarianteBoton.peligro => OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: ColoresApp.sale,
            side: const BorderSide(color: ColoresApp.sale, width: 1.5),
          ),
          child: contenido,
        ),
    };
    return SizedBox(width: double.infinity, child: boton);
  }
}
