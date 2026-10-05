import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../providers/historial_providers.dart';
import '../../providers/usuarios_providers.dart';
import '../../repositories/historial_repository.dart';
import '../../util/fecha_util.dart';
import '../../util/formato_moneda.dart';
import '../../widgets/selector_fecha.dart';

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
      appBar: AppBar(title: const Text('Historial')),
      body: Column(
        children: [
          SelectorFecha(
            dia: _dia,
            onCambio: (dia) => setState(() => _dia = inicioDelDia(dia)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButton<int?>(
              key: const Key('filtro_usuario'),
              isExpanded: true,
              value: _usuarioId,
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('Todos')),
                for (final u in usuarios)
                  DropdownMenuItem<int?>(value: u.id, child: Text(u.nombre)),
              ],
              onChanged: (id) => setState(() => _usuarioId = id),
            ),
          ),
          Expanded(
            child: movimientosAsync.when(
              data: (movimientos) {
                if (movimientos.isEmpty) {
                  return const Center(child: Text('Sin movimientos este día'));
                }
                return ListView(
                  children: movimientos
                      .map((m) => _MovimientoTile(
                            movimiento: m,
                            nombreUsuario: nombres[m.usuarioId] ?? '',
                          ))
                      .toList(),
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
  const _MovimientoTile({required this.movimiento, required this.nombreUsuario});

  final MovimientoHistorial movimiento;
  final String nombreUsuario;

  @override
  Widget build(BuildContext context) {
    final esGasto = movimiento.tipo == TipoMovimientoHistorial.gasto;
    final colorGasto = Theme.of(context).colorScheme.error;
    final descripcion = movimiento.descripcion?.trim() ?? '';
    final detalle = esGasto
        ? (descripcion.isEmpty ? 'Gasto' : descripcion)
        : (movimiento.esFiado ? 'Fiado' : 'Contado');

    return ListTile(
      leading: Icon(
        esGasto ? Icons.money_off : Icons.point_of_sale,
        color: esGasto ? colorGasto : null,
      ),
      title: Text(
        formatoMoneda(movimiento.monto),
        style: esGasto ? TextStyle(color: colorGasto) : null,
      ),
      subtitle: Text('$detalle · $nombreUsuario'),
      trailing: Text(formatoHora(movimiento.fecha)),
    );
  }
}
