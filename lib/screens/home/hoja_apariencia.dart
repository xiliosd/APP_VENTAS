import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/apariencia_provider.dart';
import '../../ui/hoja_inferior.dart';
import '../../ui/selector_segmentado.dart';

/// Hoja para elegir Automático / Claro / Oscuro; el cambio se aplica al tocar.
Future<void> mostrarHojaApariencia(BuildContext context) {
  return mostrarHojaInferior<void>(
    context,
    titulo: 'Apariencia',
    builder: (_) => Consumer(
      builder: (context, ref, _) => SelectorSegmentado<ThemeMode>(
        valor: ref.watch(aparienciaProvider),
        opciones: const {
          ThemeMode.system: 'Automático',
          ThemeMode.light: 'Claro',
          ThemeMode.dark: 'Oscuro',
        },
        onCambio: (modo) => ref.read(aparienciaProvider.notifier).elegir(modo),
      ),
    ),
  );
}
