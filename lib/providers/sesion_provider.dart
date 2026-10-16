import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import 'huella_provider.dart';
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

  /// Tras una huella aprobada: abre sesión sin PIN si [usuarioId] la tiene
  /// activada y sigue existiendo; si ya no existe, lo olvida.
  Future<bool> iniciarSesionConHuella(int usuarioId) async {
    final huellas = ref.read(usuariosConHuellaProvider.notifier);
    if (!ref.read(usuariosConHuellaProvider).contains(usuarioId)) return false;
    final usuarios = await ref.read(usuarioRepositoryProvider).listarUsuarios();
    final usuario = usuarios.where((u) => u.id == usuarioId).firstOrNull;
    if (usuario == null) {
      await huellas.conservarSolo(usuarios.map((u) => u.id));
      return false;
    }
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
