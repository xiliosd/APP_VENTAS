import 'package:flutter/material.dart';

import '../util/formato_moneda.dart';

class MontoRapidoGrid extends StatelessWidget {
  const MontoRapidoGrid({super.key, required this.onSeleccionar});

  final void Function(int monto) onSeleccionar;

  static const montos = [1000, 2000, 5000, 10000, 20000, 50000];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: montos.map((monto) {
        return ElevatedButton(
          key: Key('monto_rapido_$monto'),
          onPressed: () => onSeleccionar(monto),
          child: Text(formatoMoneda(monto)),
        );
      }).toList(),
    );
  }
}
