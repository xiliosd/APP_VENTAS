import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/fiado_repository.dart';
import 'database_provider.dart';
import 'repository_providers.dart';

/// Emite cada vez que cambia alguna tabla relacionada con fiados (ventas o
/// pagos), para que [clientesConDeudaProvider] se recalcule automáticamente
/// sin depender de una invalidación manual explícita.
final _cambiosFiadoProvider = StreamProvider<void>((ref) {
  return ref.watch(databaseProvider).tableUpdates().map((_) {});
});

final clientesConDeudaProvider = FutureProvider<List<ClienteConSaldo>>((ref) {
  ref.watch(_cambiosFiadoProvider);
  return ref.watch(fiadoRepositoryProvider).listaClientesConDeuda();
});
