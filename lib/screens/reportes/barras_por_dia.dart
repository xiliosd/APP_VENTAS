import 'package:flutter/material.dart';

import '../../ui/colores_app.dart';
import '../../util/formato_moneda.dart';

const _diasCortos = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
const _diasLargos = [
  'lunes',
  'martes',
  'miércoles',
  'jueves',
  'viernes',
  'sábado',
  'domingo',
];

/// "Lun 5".
String etiquetaDia(DateTime dia) =>
    '${_diasCortos[dia.weekday - 1]} ${dia.day}';

/// "12 a. m.", "7 a. m.", "12 m.", "6 p. m.".
String etiquetaHora(int hora) {
  if (hora == 0) return '12 a. m.';
  if (hora < 12) return '$hora a. m.';
  if (hora == 12) return '12 m.';
  return '${hora - 12} p. m.';
}

/// Una fila de [Barras]: su llave (`barra_<clave>`), etiqueta y valor.
class FilaBarra {
  const FilaBarra({
    required this.clave,
    required this.etiqueta,
    required this.valor,
  });

  final String clave;
  final String etiqueta;
  final int valor;
}

/// Barras horizontales proporcionales al mayor valor, con [resaltada] (una
/// clave) en verde intenso.
class Barras extends StatelessWidget {
  const Barras({super.key, required this.filas, this.resaltada});

  final List<FilaBarra> filas;
  final String? resaltada;

  @override
  Widget build(BuildContext context) {
    final maximo = filas.fold<int>(0, (m, f) => f.valor > m ? f.valor : m);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final fila in filas)
          Barra(
            key: Key('barra_${fila.clave}'),
            etiqueta: fila.etiqueta,
            valor: fila.valor,
            fraccion: maximo == 0 ? 0.0 : fila.valor / maximo,
            resaltada: fila.clave == resaltada,
          ),
      ],
    );
  }
}

/// Ventas de cada día como barras horizontales, con el mejor día resaltado.
class BarrasPorDia extends StatelessWidget {
  const BarrasPorDia({super.key, required this.ventasPorDia, this.mejorDia});

  final Map<DateTime, int> ventasPorDia;
  final DateTime? mejorDia;

  @override
  Widget build(BuildContext context) {
    final mejor = mejorDia;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (mejor != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Mejor día: ${_diasLargos[mejor.weekday - 1]} ${mejor.day} · '
              '${formatoMoneda(ventasPorDia[mejor] ?? 0)}',
              key: const Key('texto_mejor_dia'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        Barras(
          filas: [
            for (final entrada in ventasPorDia.entries)
              FilaBarra(
                clave: '${entrada.key.day}',
                etiqueta: etiquetaDia(entrada.key),
                valor: entrada.value,
              ),
          ],
          resaltada: mejor == null ? null : '${mejor.day}',
        ),
      ],
    );
  }
}

/// Una fila: etiqueta, barra proporcional y monto.
class Barra extends StatelessWidget {
  const Barra({
    super.key,
    required this.etiqueta,
    required this.valor,
    required this.fraccion,
    required this.resaltada,
  });

  final String etiqueta;
  final int valor;

  /// De 0 a 1, respecto al día de más venta.
  final double fraccion;
  final bool resaltada;

  @override
  Widget build(BuildContext context) {
    final escala = MediaQuery.textScalerOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: escala.scale(64),
            child: Text(etiqueta, maxLines: 1, softWrap: false),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                // Un día sin ventas deja una marca mínima, no un hueco.
                widthFactor: fraccion == 0 ? 0.01 : fraccion,
                child: Container(
                  height: 14,
                  decoration: BoxDecoration(
                    color: resaltada ? ColoresApp.entra : ColoresApp.entraSuave,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: escala.scale(84),
            child: Text(
              formatoMoneda(valor),
              textAlign: TextAlign.right,
              maxLines: 1,
              softWrap: false,
              style: const TextStyle(
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
