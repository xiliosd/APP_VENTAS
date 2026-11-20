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

/// Día (normalizado con `inicioDelDia`, para que cada lectura del mismo día
/// use el mismo provider) y, para un vendedor, solo lo suyo.
typedef FiltroResumen = ({DateTime dia, int? usuarioId});

final resumenDelDiaProvider = FutureProvider.autoDispose
    .family<ResumenDia, FiltroResumen>((ref, f) {
      ref.watch(_cambiosResumenProvider);
      return ref
          .watch(resumenRepositoryProvider)
          .resumenDelDia(f.dia, usuarioId: f.usuarioId);
    });

/// Totales de los 7 días que terminan en el día del filtro.
final ventasDiariasProvider = FutureProvider.autoDispose
    .family<List<int>, FiltroResumen>((ref, f) {
      ref.watch(_cambiosResumenProvider);
      return ref
          .watch(resumenRepositoryProvider)
          .ventasDiarias(f.dia, usuarioId: f.usuarioId);
    });

/// Solo para el administrador; la clave es un día normalizado.
final resumenPorVendedorProvider = FutureProvider.autoDispose
    .family<Map<Usuario, ResumenDia>, DateTime>((ref, dia) {
      ref.watch(_cambiosResumenProvider);
      return ref.watch(resumenRepositoryProvider).resumenPorVendedor(dia);
    });
