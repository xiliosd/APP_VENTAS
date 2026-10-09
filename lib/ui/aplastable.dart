import 'package:flutter/material.dart';

import 'movimiento.dart';

/// Se encoge al presionar y vuelve con rebote (Material 3 Expressive).
class Aplastable extends StatefulWidget {
  const Aplastable({super.key, required this.child, this.habilitado = true});

  final Widget child;
  final bool habilitado;

  @override
  State<Aplastable> createState() => _AplastableState();
}

class _AplastableState extends State<Aplastable> {
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
