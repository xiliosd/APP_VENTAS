import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import 'repository_providers.dart';

final listaUsuariosProvider = FutureProvider<List<Usuario>>((ref) {
  return ref.watch(usuarioRepositoryProvider).listarUsuarios();
});
