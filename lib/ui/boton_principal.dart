import 'package:flutter/material.dart';

import 'colores_app.dart';
import 'aplastable.dart';
import 'vibracion.dart';

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
    final alTocar = onPressed == null
        ? null
        : () {
            Vibracion.toque();
            onPressed!();
          };
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
        FilledButton(onPressed: alTocar, child: contenido),
      VarianteBoton.entra => FilledButton(
          onPressed: alTocar,
          style: FilledButton.styleFrom(
            backgroundColor: ColoresApp.of(context).rellenoEntra,
            foregroundColor: ColoresApp.of(context).sobreEntra,
          ),
          child: contenido,
        ),
      VarianteBoton.contorno => OutlinedButton(
          onPressed: alTocar,
          style: OutlinedButton.styleFrom(
            foregroundColor: ColoresApp.of(context).primario,
            side: BorderSide(color: ColoresApp.of(context).primario, width: 1.5),
          ),
          child: contenido,
        ),
      VarianteBoton.peligro => OutlinedButton(
          onPressed: alTocar,
          style: OutlinedButton.styleFrom(
            foregroundColor: ColoresApp.of(context).sale,
            side: BorderSide(color: ColoresApp.of(context).sale, width: 1.5),
          ),
          child: contenido,
        ),
    };
    return SizedBox(
      width: double.infinity,
      child: Aplastable(habilitado: onPressed != null, child: boton),
    );
  }
}
