import 'package:flutter/material.dart';

import '../util/formato_moneda.dart';
import 'colores_app.dart';

/// Qué representa una cifra, para darle su color.
enum TonoMonto { neutro, entra, sale, fiado, claro }

/// Una cifra de dinero: dígitos alineados, negrita, color según su tono.
/// Se encoge (nunca desborda) si no cabe.
class Monto extends StatelessWidget {
  const Monto(
    this.valor, {
    super.key,
    this.tamano = 18,
    this.tono = TonoMonto.neutro,
  });

  final int valor;
  final double tamano;
  final TonoMonto tono;

  static Color colorDe(TonoMonto tono) => switch (tono) {
        TonoMonto.neutro => ColoresApp.texto,
        TonoMonto.entra => ColoresApp.entra,
        TonoMonto.sale => ColoresApp.sale,
        TonoMonto.fiado => ColoresApp.fiado,
        TonoMonto.claro => Colors.white,
      };

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(
        formatoMoneda(valor),
        maxLines: 1,
        style: TextStyle(
          fontSize: tamano,
          fontWeight: FontWeight.w800,
          color: colorDe(tono),
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
