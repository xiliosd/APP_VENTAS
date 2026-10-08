import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../providers/historial_providers.dart';
import '../../providers/usuarios_providers.dart';
import '../../repositories/historial_repository.dart';
import '../../ui/colores_app.dart';
import '../../ui/etiqueta_qr.dart';
import '../../ui/estado_vacio.dart';
import '../../ui/monto.dart';
import '../../ui/tarjeta_monto.dart';
import '../../util/fecha_util.dart';
import '../../widgets/selector_fecha.dart';
import '../correccion/hoja_movimiento.dart';
import '../correccion/texto_correccion.dart';

class HistorialScreen extends ConsumerStatefulWidget {
  const HistorialScreen({super.key});

  @override
  ConsumerState<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends ConsumerState<HistorialScreen> {
  DateTime _dia = inicioDelDia(DateTime.now());
  int? _usuarioId;

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
              data: (movimientos) {
                final totalVentas = movimientos
                    .where((m) =>
                        !m.anulado && m.tipo == TipoMovimientoHistorial.venta)
                    .fold<int>(0, (suma, m) => suma + m.monto);
                final totalGastos = movimientos
                    .where((m) =>
                        !m.anulado && m.tipo == TipoMovimientoHistorial.gasto)
                    .fold<int>(0, (suma, m) => suma + m.monto);
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TarjetaMonto(
                            key: const Key('total_ventas'),
                            etiqueta: 'Ventas',
                            valor: totalVentas,
                            tono: TonoMonto.entra,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TarjetaMonto(
                            key: const Key('total_gastos'),
                            etiqueta: 'Gastos',
                            valor: totalGastos,
                            tono: TonoMonto.sale,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (movimientos.isEmpty)
                      const EstadoVacio(
                        icono: Icons.receipt_long_rounded,
                        titulo: 'Sin movimientos este día',
                      )
                    else
                      Card(
                        key: const Key('lista_movimientos'),
                        child: Column(
                          children: [
                            for (final m in movimientos)
                              _MovimientoTile(
                                movimiento: m,
                                nombres: nombres,
                                onTap: () => abrirHojaMovimiento(
                                  context,
                                  MovimientoEditable.desdeHistorial(m,
                                      nombreCliente: m.nombreCliente),
                                ),
                              ),
                          ],
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
    final esGasto = movimiento.tipo == TipoMovimientoHistorial.gasto;
    final color = esGasto ? ColoresApp.sale : ColoresApp.entra;
    final descripcion = movimiento.descripcion?.trim() ?? '';
    final detalle = esGasto
        ? (descripcion.isEmpty ? 'Gasto' : descripcion)
        : (movimiento.esFiado ? 'Fiado' : 'Contado');
    final correccion = movimiento.ultimaCorreccion;

    return ListTile(
      key: Key('movimiento_${movimiento.tipo.name}_${movimiento.id}'),
      onTap: onTap,
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: color.withValues(alpha: 0.12),
        child: Icon(
          esGasto ? Icons.south_west_rounded : Icons.north_east_rounded,
          color: color,
          size: 20,
        ),
      ),
      title: Row(
        children: [
          Monto(movimiento.monto,
              tamano: 16,
              tono: esGasto ? TonoMonto.sale : TonoMonto.neutro,
              tachado: movimiento.anulado),
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
          Text('$detalle · ${nombres[movimiento.usuarioId] ?? ''}'),
          if (correccion != null)
            Text(
              textoCorreccion(correccion, nombres[correccion.usuarioId] ?? ''),
              style: const TextStyle(
                  fontSize: 12, color: ColoresApp.textoSecundario),
            ),
        ],
      ),
      trailing: Text(formatoHora(movimiento.fecha),
          style: const TextStyle(color: ColoresApp.textoSecundario)),
    );
  }
}
