import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/resumen_providers.dart';
import '../../util/fecha_util.dart';
import '../../util/formato_moneda.dart';
import '../../widgets/selector_fecha.dart';

class ResumenScreen extends ConsumerStatefulWidget {
  const ResumenScreen({super.key});

  @override
  ConsumerState<ResumenScreen> createState() => _ResumenScreenState();
}

class _ResumenScreenState extends ConsumerState<ResumenScreen> {
  DateTime _dia = inicioDelDia(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final resumenAsync = ref.watch(resumenDelDiaProvider(_dia));
    final porVendedorAsync = ref.watch(resumenPorVendedorProvider(_dia));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectorFecha(
            dia: _dia,
            onCambio: (dia) => setState(() => _dia = inicioDelDia(dia)),
          ),
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
                        trailing:
                            Text(formatoMoneda(entrada.value.totalVendido)),
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
