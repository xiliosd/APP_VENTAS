import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../providers/historial_providers.dart';
import '../../providers/usuarios_providers.dart';
import '../../repositories/historial_repository.dart';
import '../../ui/colores_app.dart';
import '../../ui/entrada_escalonada.dart';
import '../../ui/etiqueta_qr.dart';
import '../../ui/estado_vacio.dart';
import '../../ui/monto.dart';
import '../../util/fecha_util.dart';
import '../../util/texto_util.dart';
import '../../widgets/selector_fecha.dart';
import '../correccion/hoja_movimiento.dart';
import '../correccion/texto_correccion.dart';
import '../reportes/barras_por_dia.dart' show etiquetaHora;
import 'filtro_historial.dart';

class HistorialScreen extends ConsumerStatefulWidget {
  const HistorialScreen({super.key});

  @override
  ConsumerState<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends ConsumerState<HistorialScreen> {
  DateTime _dia = inicioDelDia(DateTime.now());
  int? _usuarioId;
  FiltroTipo _tipo = FiltroTipo.todo;

  static const _nombresTipo = {
    FiltroTipo.todo: 'Todo',
    FiltroTipo.contado: 'Contado',
    FiltroTipo.fiado: 'Fiado',
    FiltroTipo.gastos: 'Gastos',
  };

  static const _vacioTipo = {
    FiltroTipo.todo: 'Sin movimientos este día',
    FiltroTipo.contado: 'Sin ventas de contado este día',
    FiltroTipo.fiado: 'Sin ventas fiadas este día',
    FiltroTipo.gastos: 'Sin gastos este día',
  };

  @override
  Widget build(BuildContext context) {
    final usuarios =
        ref.watch(listaUsuariosProvider).valueOrNull ?? const <Usuario>[];
    final nombres = {for (final u in usuarios) u.id: u.nombre};
    final movimientosAsync =
        ref.watch(historialProvider((dia: _dia, usuarioId: _usuarioId)));

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SelectorFecha(
              dia: _dia,
              onCambio: (dia) => setState(() => _dia = inicioDelDia(dia)),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final t in FiltroTipo.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      key: Key('filtro_tipo_${t.name}'),
                      label: Text(_nombresTipo[t]!),
                      selected: _tipo == t,
                      onSelected: (_) => setState(() => _tipo = t),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    key: const Key('filtro_usuario_todos'),
                    label: const Text('Todos'),
                    selected: _usuarioId == null,
                    onSelected: (_) => setState(() => _usuarioId = null),
                  ),
                ),
                for (final u in usuarios)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      key: Key('filtro_usuario_${u.id}'),
                      label: Text(u.nombre),
                      selected: _usuarioId == u.id,
                      onSelected: (_) => setState(() => _usuarioId = u.id),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: movimientosAsync.when(
              skipLoadingOnReload: true,
              data: (movimientos) {
                final c = ColoresApp.of(context);
                final visibles = filtrarPorTipo(movimientos, _tipo)
                  ..sort((a, b) => b.fecha.compareTo(a.fecha));
                final totalVentas = visibles
                    .where((m) =>
                        !m.anulado && m.tipo == TipoMovimientoHistorial.venta)
                    .fold<int>(0, (suma, m) => suma + m.monto);
                final totalGastos = visibles
                    .where((m) =>
                        !m.anulado && m.tipo == TipoMovimientoHistorial.gasto)
                    .fold<int>(0, (suma, m) => suma + m.monto);
                final filas = <Widget>[];
                int? horaActual;
                for (final (i, m) in visibles.indexed) {
                  if (m.fecha.hour != horaActual) {
                    horaActual = m.fecha.hour;
                    filas.add(Padding(
                      key: Key('hora_$horaActual'),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Text(
                        etiquetaHora(horaActual),
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: c.textoSecundario),
                      ),
                    ));
                  }
                  filas.add(EntradaEscalonada(
                    indice: i,
                    child: _MovimientoTile(
                      movimiento: m,
                      nombres: nombres,
                      onTap: () => abrirHojaMovimiento(
                        context,
                        MovimientoEditable.desdeHistorial(m,
                            nombreCliente: m.nombreCliente),
                      ),
                    ),
                  ));
                }
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      key: const Key('resumen_historial'),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_tipo != FiltroTipo.gastos)
                              Row(
                                key: const Key('total_ventas'),
                                children: [
                                  const Expanded(child: Text('Ventas')),
                                  Monto(totalVentas,
                                      tamano: 18,
                                      tono: TonoMonto.entra,
                                      animado: true),
                                ],
                              ),
                            if (_tipo == FiltroTipo.todo ||
                                _tipo == FiltroTipo.gastos)
                              Row(
                                key: const Key('total_gastos'),
                                children: [
                                  const Expanded(child: Text('Gastos')),
                                  Monto(totalGastos,
                                      tamano: 18,
                                      tono: TonoMonto.sale,
                                      animado: true),
                                ],
                              ),
                            const SizedBox(height: 4),
                            Text(
                              plural(visibles.length, 'movimiento',
                                  'movimientos'),
                              key: const Key('texto_cantidad_movimientos'),
                              style: TextStyle(
                                  fontSize: 12, color: c.textoSecundario),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (visibles.isEmpty)
                      EstadoVacio(
                        icono: Icons.receipt_long_rounded,
                        titulo: _vacioTipo[_tipo]!,
                      )
                    else
                      Card(
                        key: const Key('lista_movimientos'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: filas,
                        ),
                      ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }
}

class _MovimientoTile extends StatelessWidget {
  const _MovimientoTile({
    required this.movimiento,
    required this.nombres,
    required this.onTap,
  });

  final MovimientoHistorial movimiento;

  /// Nombre de cada usuario por id.
  final Map<int, String> nombres;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = ColoresApp.of(context);
    final esGasto = movimiento.tipo == TipoMovimientoHistorial.gasto;
    final (color, icono) = esGasto
        ? (c.sale, Icons.call_made_rounded)
        : movimiento.esFiado
            ? (c.fiado, Icons.menu_book_rounded)
            : (c.entra, Icons.shopping_cart_rounded);
    final colorIcono = movimiento.anulado ? c.textoSecundario : color;
    final descripcion = movimiento.descripcion?.trim() ?? '';
    final detalle = esGasto
        ? (descripcion.isEmpty ? 'Gasto' : descripcion)
        : (movimiento.esFiado ? 'Fiado' : 'Contado');
    final correccion = movimiento.ultimaCorreccion;
    final secundario = TextStyle(fontSize: 12, color: c.textoSecundario);

    return ListTile(
      key: Key('movimiento_${movimiento.tipo.name}_${movimiento.id}'),
      onTap: onTap,
      leading: Container(
        key: Key('icono_movimiento_${movimiento.tipo.name}_${movimiento.id}'),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: colorIcono.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(icono, color: colorIcono, size: 20),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text('$detalle · ${nombres[movimiento.usuarioId] ?? ''}',
                overflow: TextOverflow.ellipsis),
          ),
          if (!esGasto &&
              movimiento.medioPago == MedioPago.transferencia) ...[
            const SizedBox(width: 8),
            const EtiquetaQr(),
          ],
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (movimiento.esFiado && movimiento.nombreCliente != null)
            Text(movimiento.nombreCliente!, style: secundario),
          if (correccion != null)
            Text(
              textoCorreccion(correccion, nombres[correccion.usuarioId] ?? ''),
              style: secundario,
            ),
        ],
      ),
      trailing: Monto(movimiento.monto,
          tamano: 16,
          tono: esGasto ? TonoMonto.sale : TonoMonto.neutro,
          tachado: movimiento.anulado),
    );
  }
}
