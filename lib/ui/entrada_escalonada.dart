import 'package:flutter/material.dart';

import 'movimiento.dart';

/// Hace que un elemento de una lista suba y aparezca con rebote la primera
/// vez que se construye; [indice] (hasta 8) escalona la entrada 60 ms.
class EntradaEscalonada extends StatefulWidget {
  const EntradaEscalonada({super.key, required this.indice, required this.child});
  final int indice;
  final Widget child;
  @override
  State<EntradaEscalonada> createState() => _EntradaEscalonadaState();
}

class _EntradaEscalonadaState extends State<EntradaEscalonada>
    with SingleTickerProviderStateMixin {
  AnimationController? _control;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_control != null || Movimiento.reducido(context)) return;
    final retraso = Duration(milliseconds: 60 * widget.indice.clamp(0, 8));
    _control = AnimationController(
        vsync: this, duration: retraso + Movimiento.larga)
      ..forward();
  }

  @override
  void dispose() {
    _control?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final control = _control;
    if (control == null) return widget.child;
    final total = control.duration!.inMilliseconds;
    final inicio = (60 * widget.indice.clamp(0, 8)) / total;
    final curva = CurvedAnimation(
        parent: control, curve: Interval(inicio, 1, curve: Movimiento.resorte));
    return AnimatedBuilder(
      animation: curva,
      child: widget.child,
      builder: (context, hijo) {
        if (control.isCompleted) return hijo!;
        final v = curva.value;
        return Opacity(
          opacity: v.clamp(0.0, 1.0),
          child: Transform.translate(offset: Offset(0, 24 * (1 - v)), child: hijo),
        );
      },
    );
  }
}
