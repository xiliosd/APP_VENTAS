import 'package:flutter/material.dart';

import '../ui/mosaico.dart';
import '../ui/recorrido/objetivo_recorrido.dart';
import '../util/formato_moneda.dart';

class MontoRapidoGrid extends StatelessWidget {
  const MontoRapidoGrid({
    super.key,
    required this.onSeleccionar,
    this.cantidadDe,
  });

  final void Function(int monto) onSeleccionar;

  /// Cuántas veces está ese monto en el ticket (para la insignia).
  final int Function(int monto)? cantidadDe;

  static const montos = [1000, 2000, 5000, 10000, 20000, 50000];

  @override
  Widget build(BuildContext context) {
    return GrillaMosaicos(
      conSubtitulo: false,
      children: [
        for (final monto in montos)
          ObjetivoRecorrido(
            id: 'monto_rapido_$monto',
            child: Mosaico(
              key: Key('monto_rapido_$monto'),
              titulo: formatoMoneda(monto),
              cantidad: cantidadDe?.call(monto) ?? 0,
              onTap: () => onSeleccionar(monto),
            ),
          ),
      ],
    );
  }
}
