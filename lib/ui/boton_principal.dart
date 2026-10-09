import 'package:flutter/material.dart';

import 'colores_app.dart';
import 'movimiento.dart';
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
      child: _Aplastable(habilitado: onPressed != null, child: boton),
    );
  }
}

/// Se encoge al presionar y vuelve con rebote (Material 3 Expressive).
class _Aplastable extends StatefulWidget {
  const _Aplastable({required this.child, required this.habilitado});

  final Widget child;
  final bool habilitado;

  @override
  State<_Aplastable> createState() => _AplastableState();
}

class _AplastableState extends State<_Aplastable> {
  var _presionado = false;

  void _cambiar(bool valor) {
    if (widget.habilitado && _presionado != valor) {
      setState(() => _presionado = valor);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _cambiar(true),
      onPointerUp: (_) => _cambiar(false),
      onPointerCancel: (_) => _cambiar(false),
      child: AnimatedScale(
        scale: _presionado ? 0.94 : 1.0,
        duration: Movimiento.duracion(
            context, _presionado ? Movimiento.corta : Movimiento.media),
        curve: _presionado ? Curves.easeOut : Movimiento.resorte,
        child: widget.child,
      ),
    );
  }
}
