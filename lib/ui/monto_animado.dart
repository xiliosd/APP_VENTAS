import 'package:flutter/material.dart';

import 'monto.dart';
import 'movimiento.dart';

/// [Monto] que, cuando cambia el valor, cuenta desde el anterior hasta el
/// nuevo. La primera vez (y con "quitar animaciones") muestra el valor directo.
class MontoAnimado extends StatefulWidget {
  const MontoAnimado(this.valor,
      {super.key, this.tamano = 18, this.tono = TonoMonto.neutro, this.tachado = false});

  final int valor;
  final double tamano;
  final TonoMonto tono;
  final bool tachado;

  @override
  State<MontoAnimado> createState() => _MontoAnimadoState();
}

class _MontoAnimadoState extends State<MontoAnimado>
    with SingleTickerProviderStateMixin {
  late final _control = AnimationController(vsync: this);
  late int _desde = widget.valor;
  late int _hasta = widget.valor;

  int get _actual {
    final t = Curves.easeOutCubic.transform(_control.value);
    return (_desde + (_hasta - _desde) * t).round();
  }

  @override
  void didUpdateWidget(MontoAnimado anterior) {
    super.didUpdateWidget(anterior);
    if (widget.valor == _hasta) return;
    _desde = _control.isAnimating ? _actual : _hasta;
    _hasta = widget.valor;
    _control.duration = Movimiento.duracion(context, Movimiento.conteo);
    _control.forward(from: 0);
  }

  @override
  void dispose() {
    _control.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _control,
      builder: (context, _) => Monto(
        _control.isAnimating ? _actual : _hasta,
        tamano: widget.tamano,
        tono: widget.tono,
        tachado: widget.tachado,
      ),
    );
  }
}
