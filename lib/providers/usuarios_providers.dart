import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import 'repository_providers.dart';

final listaUsuariosProvider = FutureProvider<List<Usuario>>((ref) {
  return ref.watch(usuarioRepositoryProvider).listarUsuarios();
});

/// Los que pueden entrar: los de "¿Quién eres?". Sale de la lista completa
/// para que recargarla también la recargue.
final listaUsuariosActivosProvider = FutureProvider<List<Usuario>>((ref) async {
  final usuarios = await ref.watch(listaUsuariosProvider.future);
  return [
    for (final usuario in usuarios)
      if (usuario.activo) usuario,
  ];
});
