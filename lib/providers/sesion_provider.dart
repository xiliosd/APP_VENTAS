import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import 'repository_providers.dart';

class SesionState {
  const SesionState({this.usuarioActivo});

  final Usuario? usuarioActivo;

  bool get haySesion => usuarioActivo != null;
  bool get esAdmin => usuarioActivo?.rol == 'admin';
}

class SesionNotifier extends Notifier<SesionState> {
  @override
  SesionState build() => const SesionState();

  Future<bool> iniciarSesion(int usuarioId, String pin) async {
    final repo = ref.read(usuarioRepositoryProvider);
    final usuario = await repo.verificarPin(usuarioId, pin);
    if (usuario == null) return false;
    state = SesionState(usuarioActivo: usuario);
    return true;
  }

  void cerrarSesion() {
    state = const SesionState();
  }
}

final sesionProvider = NotifierProvider<SesionNotifier, SesionState>(
  SesionNotifier.new,
);

final haySesionUsuariosProvider = FutureProvider<bool>((ref) {
  return ref.watch(usuarioRepositoryProvider).existeAlgunUsuario();
});
