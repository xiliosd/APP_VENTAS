import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../respaldo/respaldo_provider.dart';

const _clave = 'apariencia';
const _valores = {
  ThemeMode.system: 'sistema',
  ThemeMode.light: 'claro',
  ThemeMode.dark: 'oscuro',
};

/// Apariencia elegida en este celular: Automático (sigue al sistema), Claro u
/// Oscuro. Si no hay elección o no se entiende, Automático.
class AparienciaNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final guardado = ref.read(preferenciasProvider).getString(_clave);
    return _valores.entries
            .where((e) => e.value == guardado)
            .map((e) => e.key)
            .firstOrNull ??
        ThemeMode.system;
  }

  Future<void> elegir(ThemeMode modo) async {
    state = modo;
    await ref.read(preferenciasProvider).setString(_clave, _valores[modo]!);
  }
}

final aparienciaProvider =
    NotifierProvider<AparienciaNotifier, ThemeMode>(AparienciaNotifier.new);
