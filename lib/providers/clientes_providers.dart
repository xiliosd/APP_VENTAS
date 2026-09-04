import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import 'repository_providers.dart';

final listaClientesProvider = FutureProvider<List<Cliente>>((ref) {
  return ref.watch(clienteRepositoryProvider).listarClientes();
});
