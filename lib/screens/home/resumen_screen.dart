import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/resumen_providers.dart';
import '../../util/formato_moneda.dart';

class ResumenScreen extends ConsumerWidget {
  const ResumenScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resumenAsync = ref.watch(resumenDelDiaProvider);
    final porVendedorAsync = ref.watch(resumenPorVendedorProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Hoy',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          resumenAsync.when(
            data: (resumen) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Vendiste: ${formatoMoneda(resumen.totalVendido)}'),
                Text('Gastaste: ${formatoMoneda(resumen.totalGastado)}'),
                Text('Por cobrar: ${formatoMoneda(resumen.totalPorCobrar)}'),
              ],
            ),
            loading: () => const CircularProgressIndicator(),
            error: (e, st) => Text('Error: $e'),
          ),
          const SizedBox(height: 24),
          const Text('Por vendedor',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          porVendedorAsync.when(
            data: (mapa) => Column(
              children: mapa.entries
                  .map((entrada) => ListTile(
                        title: Text(entrada.key.nombre),
                        trailing: Text(formatoMoneda(entrada.value.totalVendido)),
                      ))
                  .toList(),
            ),
            loading: () => const CircularProgressIndicator(),
            error: (e, st) => Text('Error: $e'),
          ),
        ],
      ),
    );
  }
}
