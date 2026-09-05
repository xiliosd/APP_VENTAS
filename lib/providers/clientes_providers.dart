import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import 'database_provider.dart';
import 'repository_providers.dart';

/// Emits whenever any table changes, so that [listaClientesProvider]
/// recomputes automatically after a client is created (including the
/// inline creation from RegistrarVentaScreen, which bypasses this provider)
/// instead of keeping a stale list cached (see [_cambiosFiadoProvider] in
/// fiado_providers.dart for the same pattern).
final _cambiosClientesProvider = StreamProvider<void>((ref) {
  return ref.watch(databaseProvider).tableUpdates().map((_) {});
});

final listaClientesProvider = FutureProvider<List<Cliente>>((ref) {
  ref.watch(_cambiosClientesProvider);
  return ref.watch(clienteRepositoryProvider).listarClientes();
});
