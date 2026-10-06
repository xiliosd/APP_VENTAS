import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/reporte_providers.dart';
import '../../repositories/reporte_repository.dart';
import '../../ui/colores_app.dart';
import '../../ui/estado_vacio.dart';
import '../../ui/monto.dart';
import '../../ui/selector_segmentado.dart';
import '../../ui/tarjeta_monto.dart';
import '../../util/fecha_util.dart';
import '../../util/formato_moneda.dart';
import '../../util/periodo.dart';
import '../../util/texto_util.dart';
import 'barras_por_dia.dart';

/// Reporte por semana o por mes: cómo le fue, caja y banco, fiado y ventas
/// por día, comparado con el periodo anterior.
class ReportesScreen extends ConsumerStatefulWidget {
  const ReportesScreen({super.key, this.reloj});

  /// Hora actual; solo para pruebas (por defecto, `DateTime.now`).
  final DateTime Function()? reloj;

  @override
  ConsumerState<ReportesScreen> createState() => _ReportesScreenState();
}

class _ReportesScreenState extends ConsumerState<ReportesScreen> {
  /// Se lee en cada redibujo: si la pantalla queda abierta pasada la
  /// medianoche, el periodo actual cuenta también el día nuevo.
  DateTime get _hoy => inicioDelDia((widget.reloj ?? DateTime.now)());
  late Periodo _periodo = Periodo.actual(TipoPeriodo.semana, _hoy);

  @override
  Widget build(BuildContext context) {
    final esActual = _periodo.contiene(_hoy);
    final comparacionAsync = ref.watch(
        comparacionReporteProvider((periodo: _periodo, hoy: _hoy)));

    return Scaffold(
      appBar: AppBar(title: const Text('Reportes')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SelectorSegmentado<TipoPeriodo>(
            key: const Key('selector_periodo'),
            opciones: const {
              TipoPeriodo.semana: 'Semana',
              TipoPeriodo.mes: 'Mes',
            },
            valor: _periodo.tipo,
            onCambio: (tipo) =>
                setState(() => _periodo = Periodo.actual(tipo, _hoy)),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                key: const Key('periodo_anterior'),
                tooltip: 'Anterior',
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: () =>
                    setState(() => _periodo = _periodo.anterior),
              ),
              Expanded(
                child: Text(
                  _periodo.titulo,
                  key: const Key('titulo_periodo'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                key: const Key('periodo_siguiente'),
                tooltip: 'Siguiente',
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: esActual
                    ? null
                    : () => setState(() => _periodo = _periodo.siguiente),
              ),
            ],
          ),
          const SizedBox(height: 8),
          comparacionAsync.when(
            data: (comparacion) => comparacion.actual.vacio
                ? const EstadoVacio(
                    icono: Icons.bar_chart_rounded,
                    titulo: 'Sin ventas en este periodo',
                  )
                : _Contenido(
                    comparacion: comparacion,
                    tipo: _periodo.tipo,
                  ),
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, st) => Text('Error: $e'),
          ),
        ],
      ),
    );
  }
}

class _Contenido extends StatelessWidget {
  const _Contenido({required this.comparacion, required this.tipo});

  final ComparacionReporte comparacion;
  final TipoPeriodo tipo;

  @override
  Widget build(BuildContext context) {
    final r = comparacion.actual;
    final contra =
        tipo == TipoPeriodo.semana ? 'vs. semana pasada' : 'vs. mes pasado';
    const gris = TextStyle(color: ColoresApp.textoSecundario);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Titulo('¿Cómo te fue?'),
        TarjetaMonto(
          key: const Key('reporte_ventas'),
          etiqueta: 'Ventas',
          valor: r.ventas,
          tono: TonoMonto.entra,
          tamano: 28,
        ),
        _TextoCambio(
            key: const Key('cambio_ventas'),
            cambio: comparacion.cambioVentas,
            contra: contra),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TarjetaMonto(
                key: const Key('reporte_gastos'),
                etiqueta: 'Gastos',
                valor: r.gastos,
                tono: TonoMonto.sale,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TarjetaMonto(
                    key: const Key('reporte_ganancia'),
                    etiqueta: 'Ganancia',
                    valor: r.ganancia,
                    tono: r.ganancia < 0 ? TonoMonto.sale : TonoMonto.neutro,
                  ),
                  _TextoCambio(
                      key: const Key('cambio_ganancia'),
                      cambio: comparacion.cambioGanancia,
                      contra: contra),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '${plural(r.cantidadVentas, 'venta', 'ventas')} · '
          'promedio ${formatoMoneda(r.ventaPromedio)}',
          key: const Key('texto_promedio'),
          style: gris,
        ),
        const _Titulo('Caja y banco'),
        Row(
          children: [
            Expanded(
              child: TarjetaMonto(
                key: const Key('reporte_efectivo'),
                etiqueta: 'Efectivo',
                valor: r.recibidoEfectivo,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TarjetaMonto(
                key: const Key('reporte_transferencia'),
                etiqueta: 'Transferencia',
                valor: r.recibidoTransferencia,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text('Gastos ${formatoMoneda(r.gastos)}',
            key: const Key('texto_gastos_caja'), style: gris),
        const _Titulo('Fiado'),
        Text(
          'Fiaste ${formatoMoneda(r.fiado)} · '
          'Cobraste ${formatoMoneda(r.cobrado)}',
          key: const Key('texto_fiado'),
        ),
        const SizedBox(height: 4),
        Text(
          'Deuda: ${formatoMoneda(r.deudaInicio)} → '
          '${formatoMoneda(r.deudaFin)}',
          key: const Key('texto_deuda'),
        ),
        const _Titulo('Ventas por día'),
        BarrasPorDia(ventasPorDia: r.ventasPorDia, mejorDia: r.mejorDia),
      ],
    );
  }
}

class _Titulo extends StatelessWidget {
  const _Titulo(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 8),
        child: Text(texto,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      );
}

/// "↑ 12 % vs. semana pasada" en verde, "↓ 8 % …" en rojo o "= …" en gris;
/// nada si no hay porcentaje.
class _TextoCambio extends StatelessWidget {
  const _TextoCambio({super.key, required this.cambio, required this.contra});

  final int? cambio;
  final String contra;

  @override
  Widget build(BuildContext context) {
    final valor = cambio;
    if (valor == null) return const SizedBox.shrink();
    final (texto, color) = valor > 0
        ? ('↑ $valor % $contra', ColoresApp.entra)
        : valor < 0
            ? ('↓ ${-valor} % $contra', ColoresApp.sale)
            : ('= $contra', ColoresApp.textoSecundario);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(texto,
          style: TextStyle(color: color, fontWeight: FontWeight.w600)),
    );
  }
}
