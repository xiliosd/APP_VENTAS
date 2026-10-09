import 'package:flutter/material.dart';

import '../util/formato_moneda.dart';
import 'colores_app.dart';
import 'monto_animado.dart';

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
    this.tachado = false,
    this.animado = false,
  });

  final int valor;
  final double tamano;
  final TonoMonto tono;

  /// Anulado: tachado y en gris, sin importar el tono.
  final bool tachado;

  /// Al cambiar el valor, cuenta desde el anterior ([MontoAnimado]).
  final bool animado;

  static Color colorDe(TonoMonto tono, ColoresApp c) => switch (tono) {
        TonoMonto.neutro => c.texto,
        TonoMonto.entra => c.entra,
        TonoMonto.sale => c.sale,
        TonoMonto.fiado => c.fiado,
        TonoMonto.claro => c.sobreTarjetaPrincipal,
      };

  @override
  Widget build(BuildContext context) {
    if (animado) {
      return MontoAnimado(valor, tamano: tamano, tono: tono, tachado: tachado);
    }
    final c = ColoresApp.of(context);
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(
        formatoMoneda(valor),
        maxLines: 1,
        style: TextStyle(
          fontSize: tamano,
          fontWeight: FontWeight.w800,
          color: tachado ? c.textoSecundario : colorDe(tono, c),
          decoration: tachado ? TextDecoration.lineThrough : null,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
