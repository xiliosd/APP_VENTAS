import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/historial_providers.dart';
import '../../util/formato_moneda.dart';

class HistorialScreen extends ConsumerWidget {
  const HistorialScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ventasAsync = ref.watch(historialDelDiaProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Historial de hoy')),
      body: ventasAsync.when(
        data: (ventas) => ListView.builder(
          itemCount: ventas.length,
          itemBuilder: (context, index) {
            final venta = ventas[index];
            return ListTile(
              title: Text(formatoMoneda(venta.monto)),
              subtitle: Text(venta.esFiado ? 'Fiado' : 'Contado'),
              trailing: Text(
                '${venta.fecha.hour}:${venta.fecha.minute.toString().padLeft(2, '0')}',
              ),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
