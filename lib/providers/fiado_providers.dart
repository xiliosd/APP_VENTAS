import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/fiado_repository.dart';
import 'database_provider.dart';
import 'repository_providers.dart';

/// Emits whenever any table changes, so that [clientesConDeudaProvider]
/// recomputes automatically instead of relying only on an explicit
/// `ref.invalidate` call after a payment.
final _cambiosFiadoProvider = StreamProvider<void>((ref) {
  return ref.watch(databaseProvider).tableUpdates().map((_) {});
});

final clientesConDeudaProvider = FutureProvider<List<ClienteConSaldo>>((ref) {
  ref.watch(_cambiosFiadoProvider);
  return ref.watch(fiadoRepositoryProvider).listaClientesConDeuda();
});

final saldoClienteProvider =
    FutureProvider.autoDispose.family<int, int>((ref, clienteId) {
  ref.watch(_cambiosFiadoProvider);
  return ref.watch(fiadoRepositoryProvider).saldoCliente(clienteId);
});

final movimientosClienteProvider = FutureProvider.autoDispose
    .family<List<MovimientoFiado>, int>((ref, clienteId) {
  ref.watch(_cambiosFiadoProvider);
  return ref.watch(fiadoRepositoryProvider).movimientosCliente(clienteId);
});
