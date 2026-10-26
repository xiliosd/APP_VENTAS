import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/reporte_providers.dart';
import '../../repositories/reporte_repository.dart';
import '../../ui/colores_app.dart';
import '../../ui/entrada_escalonada.dart';
import '../../ui/estado_vacio.dart';
import '../../ui/monto.dart';
import '../../ui/selector_segmentado.dart';
import '../../ui/tarjeta_monto.dart';
import '../../ui/tema_app.dart';
import '../../ui/tipografia.dart';
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
      comparacionReporteProvider((periodo: _periodo, hoy: _hoy)),
    );

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
                onPressed: () => setState(() => _periodo = _periodo.anterior),
              ),
              Expanded(
                child: Text(
                  _periodo.titulo(_hoy),
                  key: const Key('titulo_periodo'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
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
            skipLoadingOnReload: true,
            data: (comparacion) => comparacion.actual.vacio
                ? const EstadoVacio(
                    icono: Icons.bar_chart_rounded,
                    titulo: 'Sin ventas en este periodo',
                  )
                : _Contenido(comparacion: comparacion, tipo: _periodo.tipo),
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, st) => EstadoVacio(
              icono: Icons.error_outline_rounded,
              titulo: 'No se pudo cargar el reporte',
              accion: TextButton(
                key: const Key('reintentar_reporte'),
                onPressed: () => ref.invalidate(comparacionReporteProvider(
                    (periodo: _periodo, hoy: _hoy))),
                child: const Text('Reintentar'),
              ),
            ),
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
    final contra = tipo == TipoPeriodo.semana
        ? 'vs. semana pasada'
        : 'vs. mes pasado';
    final c = ColoresApp.of(context);
    final gris = TextStyle(color: c.textoSecundario);
    final suave = c.sobreTarjetaPrincipal.withValues(alpha: 0.75);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EntradaEscalonada(
          indice: 0,
          child: Container(
            key: const Key('reporte_ventas'),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.tarjetaPrincipal,
              borderRadius: BorderRadius.circular(radioTarjetaPrincipal),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ventas', style: estiloTitulo(tamano: 14, color: suave)),
                const SizedBox(height: 4),
                Monto(r.ventas,
                    tamano: 36, tono: TonoMonto.claro, animado: true),
                _EtiquetaCambio(
                  key: const Key('cambio_ventas'),
                  cambio: comparacion.cambioVentas,
                  contra: contra,
                  enTarjeta: true,
                ),
                const SizedBox(height: 4),
                Text(
                  '${plural(r.cantidadVentas, 'venta', 'ventas')} · '
                  'promedio ${formatoMoneda(r.ventaPromedio)}',
                  key: const Key('texto_promedio'),
                  style: TextStyle(color: suave, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        EntradaEscalonada(
          indice: 1,
          child: Row(
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
                  _EtiquetaCambio(
                    key: const Key('cambio_ganancia'),
                    cambio: comparacion.cambioGanancia,
                    contra: contra,
                  ),
                ],
              ),
            ),
          ],
        ),
        ),
        const _Titulo('Caja y banco'),
        EntradaEscalonada(
          indice: 2,
          child: Row(
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
        ),
        const SizedBox(height: 8),
        Text(
          'Gastos ${formatoMoneda(r.gastos)}',
          key: const Key('texto_gastos_caja'),
          style: gris,
        ),
        const SizedBox(height: 12),
        EntradaEscalonada(
          indice: 3,
          child: Card(
            key: const Key('tarjeta_fiado_reporte'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Fiado',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(
                    'Fiaste ${formatoMoneda(r.fiado)} · '
                    'Cobraste ${formatoMoneda(r.cobrado)}',
                    key: const Key('texto_fiado'),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          'Deuda: ${formatoMoneda(r.deudaInicio)} → '
                          '${formatoMoneda(r.deudaFin)}',
                          key: const Key('texto_deuda'),
                        ),
                      ),
                      if (r.deudaFin != r.deudaInicio) ...[
                        const SizedBox(width: 6),
                        Icon(
                          r.deudaFin > r.deudaInicio
                              ? Icons.trending_up_rounded
                              : Icons.trending_down_rounded,
                          key: const Key('tendencia_deuda'),
                          size: 18,
                          color: r.deudaFin > r.deudaInicio ? c.sale : c.entra,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const _Titulo('¿A quién le vendo?'),
        Card(
          key: const Key('tarjeta_a_quien'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _contenidoAQuien(r, gris),
          ),
        ),
        const _Titulo('Mejores clientes'),
        if (r.mejoresClientes.isEmpty)
          Text(
            'Marca al cliente al cobrar para ver aquí a tus mejores clientes',
            key: const Key('texto_sin_clientes'),
            style: gris,
          )
        else
          for (final (i, cliente) in r.mejoresClientes.indexed)
            Padding(
              key: Key('mejor_cliente_$i'),
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${i + 1}. ${cliente.nombre} · '
                    '${plural(cliente.compras, 'compra', 'compras')} '
                    '· ${formatoMoneda(cliente.dinero)}',
                  ),
                  const SizedBox(height: 4),
                  LayoutBuilder(
                    builder: (context, limites) {
                      // La lista va por dinero: el primero llena el ancho.
                      final mayor = r.mejoresClientes.first.dinero;
                      final ancho = mayor <= 0
                          ? 4.0
                          : (limites.maxWidth * cliente.dinero / mayor)
                              .clamp(4.0, limites.maxWidth);
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          key: Key('barra_mejor_cliente_$i'),
                          height: 6,
                          width: ancho,
                          decoration: BoxDecoration(
                            color: i == 0 ? c.marcaVerde : c.primario,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
        const _Titulo('Ventas por día'),
        BarrasPorDia(ventasPorDia: r.ventasPorDia, mejorDia: r.mejorDia),
        const _Titulo('Productos más vendidos'),
        if (r.ranking.isEmpty && r.otrosMontos == 0)
          Text(
            'Aún no hay ventas con detalle de productos en este periodo',
            key: const Key('texto_sin_detalle'),
            style: gris,
          )
        else ...[
          if (r.hayCostos)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                r.gananciaProductos < 0
                    ? 'Pérdida en productos: '
                        '${formatoMoneda(-r.gananciaProductos)}'
                    : 'Ganancia en productos: '
                        '${formatoMoneda(r.gananciaProductos)}',
                key: const Key('texto_ganancia_productos'),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: r.gananciaProductos < 0 ? ColoresApp.of(context).sale : null,
                ),
              ),
            ),
          for (final (i, p) in r.ranking.indexed)
            Padding(
              key: Key('ranking_$i'),
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                '${i + 1}. ${p.nombre} · ${p.unidades} u · '
                '${formatoMoneda(p.dinero)}'
                '${switch (p.ganancia) {
                  null => '',
                  final g when g < 0 => ' · pierde ${formatoMoneda(-g)}',
                  final g => ' · gana ${formatoMoneda(g)}',
                }}',
                style: (p.ganancia ?? 0) < 0
                    ? TextStyle(color: ColoresApp.of(context).sale)
                    : null,
              ),
                  const SizedBox(height: 4),
                  LayoutBuilder(
                    builder: (context, limites) {
                      // El top va por unidades: la barra se mide contra el
                      // producto que más dinero dejó, no contra el primero.
                      final mayor = r.ranking
                          .map((x) => x.dinero)
                          .reduce((a, b) => a > b ? a : b);
                      final ancho = mayor <= 0
                          ? 4.0
                          : (limites.maxWidth * p.dinero / mayor)
                              .clamp(4.0, limites.maxWidth);
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          key: Key('barra_ranking_$i'),
                          height: 6,
                          width: ancho,
                          decoration: BoxDecoration(
                            color: i == 0 ? c.marcaVerde : c.primario,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          if (r.otrosMontos > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Otros montos · ${formatoMoneda(r.otrosMontos)}',
                key: const Key('texto_otros_montos'),
                style: gris,
              ),
            ),
          if (r.vendidoSinCosto > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${formatoMoneda(r.vendidoSinCosto)} vendidos sin costo '
                'registrado',
                key: const Key('texto_sin_costo'),
                style: gris,
              ),
            ),
        ],
        const _Titulo('Horas de más venta'),
        if (r.horaPico case final pico?)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.schedule_rounded, color: c.primario),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Hora pico: ${etiquetaHora(pico)} · '
                        '${formatoMoneda(r.ventasPorHora[pico]!)}',
                        key: const Key('texto_hora_pico'),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Barras(
          filas: [
            for (final e in r.ventasPorHora.entries)
              FilaBarra(
                clave: 'h${e.key}',
                etiqueta: etiquetaHora(e.key),
                valor: e.value,
              ),
          ],
          resaltada: r.horaPico == null ? null : 'h${r.horaPico}',
        ),
      ],
    );
  }
}

extension on _Contenido {
  Widget _contenidoAQuien(Reporte r, TextStyle gris) {
    final total = r.vendidoHabituales + r.vendidoDePaso;
    if (total == 0) {
      return Text('Aún no hay ventas en este periodo', style: gris);
    }
    // De paso es el resto para que las dos filas sumen siempre 100 %.
    final porcentajeHabituales = (r.vendidoHabituales * 100 / total).round();
    String fila(String nombre, int monto, int porcentaje) =>
        '$nombre · ${formatoMoneda(monto)} · $porcentaje %';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          fila(
            'Clientes habituales',
            r.vendidoHabituales,
            porcentajeHabituales,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          fila(
            'De paso o sin marcar',
            r.vendidoDePaso,
            100 - porcentajeHabituales,
          ),
        ),
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
    child: Text(
      texto,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
    ),
  );
}

/// "↑ 12 % vs. semana pasada", "↓ 8 % …" o "= …"; nada si no hay
/// porcentaje. En la tarjeta principal va como píldora verde o roja.
class _EtiquetaCambio extends StatelessWidget {
  const _EtiquetaCambio(
      {super.key,
      required this.cambio,
      required this.contra,
      this.enTarjeta = false});

  final int? cambio;
  final String contra;
  final bool enTarjeta;

  @override
  Widget build(BuildContext context) {
    final valor = cambio;
    if (valor == null) return const SizedBox.shrink();
    final c = ColoresApp.of(context);
    final texto = valor > 0
        ? '↑ $valor % $contra'
        : valor < 0
            ? '↓ ${-valor} % $contra'
            : '= $contra';
    final tono = valor > 0
        ? c.entra
        : valor < 0
            ? c.sale
            : null;
    if (!enTarjeta) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(texto,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: tono ?? c.textoSecundario)),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: tono == null
              ? EdgeInsets.zero
              : const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: tono == null
              ? null
              : ShapeDecoration(
                  shape: const StadiumBorder(),
                  color: tono.withValues(alpha: 0.22),
                ),
          child: Text(
            texto,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: tono == null
                  ? c.sobreTarjetaPrincipal.withValues(alpha: 0.75)
                  : c.sobreTarjetaPrincipal,
            ),
          ),
        ),
      ),
    );
  }
}
