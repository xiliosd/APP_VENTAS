import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/historial_repository.dart';
import 'database_provider.dart';
import 'repository_providers.dart';

/// Day (normalized with `inicioDelDia`) and optional user to show in the
/// historial. Records compare by value, so equal filters share one provider.
typedef FiltroHistorial = ({DateTime dia, int? usuarioId});

/// Emits whenever any table changes, so the historial refreshes after a sale
/// or expense is registered (same pattern as fiado_providers.dart).
final _cambiosHistorialProvider = StreamProvider<void>((ref) {
  return ref.watch(databaseProvider).tableUpdates().map((_) {});
});

final historialProvider = FutureProvider.autoDispose
    .family<List<MovimientoHistorial>, FiltroHistorial>((ref, filtro) {
  ref.watch(_cambiosHistorialProvider);
  return ref
      .watch(historialRepositoryProvider)
      .movimientosDelDia(filtro.dia, usuarioId: filtro.usuarioId);
});
