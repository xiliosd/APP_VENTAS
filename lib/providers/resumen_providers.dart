import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../repositories/resumen_repository.dart';
import 'database_provider.dart';
import 'repository_providers.dart';

/// Emits whenever any table changes, so that the resumen providers below
/// recompute automatically after a sale/expense is registered instead of
/// keeping a stale total cached (see [_cambiosFiadoProvider] in
/// fiado_providers.dart for the same pattern).
final _cambiosResumenProvider = StreamProvider<void>((ref) {
  return ref.watch(databaseProvider).tableUpdates().map((_) {});
});

final resumenDelDiaProvider = FutureProvider.autoDispose<ResumenDia>((ref) {
  ref.watch(_cambiosResumenProvider);
  return ref.watch(resumenRepositoryProvider).resumenDelDia(DateTime.now());
});

final resumenPorVendedorProvider =
    FutureProvider.autoDispose<Map<Usuario, ResumenDia>>((ref) {
  ref.watch(_cambiosResumenProvider);
  return ref.watch(resumenRepositoryProvider).resumenPorVendedor(DateTime.now());
});
