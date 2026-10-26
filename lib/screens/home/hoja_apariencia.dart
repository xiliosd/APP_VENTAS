import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/apariencia_provider.dart';
import '../../providers/tamano_letra_provider.dart';
import '../../ui/hoja_inferior.dart';
import '../../ui/selector_segmentado.dart';

/// Hoja para elegir Automático / Claro / Oscuro y el tamaño de letra; cada
/// cambio se aplica al tocar.
Future<void> mostrarHojaApariencia(BuildContext context) {
  return mostrarHojaInferior<void>(
    context,
    titulo: 'Apariencia',
    builder: (_) => Consumer(
      builder: (context, ref, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SelectorSegmentado<ThemeMode>(
            valor: ref.watch(aparienciaProvider),
            opciones: const {
              ThemeMode.system: 'Automático',
              ThemeMode.light: 'Claro',
              ThemeMode.dark: 'Oscuro',
            },
            onCambio: (modo) =>
                ref.read(aparienciaProvider.notifier).elegir(modo),
          ),
          const SizedBox(height: 24),
          const Text('Tamaño de letra',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          SelectorSegmentado<TamanoLetra>(
            key: const Key('selector_tamano_letra'),
            valor: ref.watch(tamanoLetraProvider),
            opciones: const {
              TamanoLetra.normal: 'Normal',
              TamanoLetra.grande: 'Grande',
              TamanoLetra.muyGrande: 'Muy grande',
            },
            onCambio: (tamano) =>
                ref.read(tamanoLetraProvider.notifier).elegir(tamano),
          ),
        ],
      ),
    ),
  );
}
