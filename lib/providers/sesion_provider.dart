import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../sincronizacion/nube_tienda.dart';
import '../sincronizacion/sincronizacion_provider.dart';
import '../util/permisos.dart' as permisos;
import 'database_provider.dart';
import 'huella_provider.dart';
import 'repository_providers.dart';

enum ResultadoIngreso {
  ok,
  pinIncorrecto,
  necesitaInternet,
  bloqueado,
  inactivo,
}

class SesionState {
  const SesionState({this.usuarioActivo});

  final Usuario? usuarioActivo;

  bool get haySesion => usuarioActivo != null;
  bool get esAdmin => usuarioActivo?.rol == 'admin';
  bool get puedeManejarCatalogo => permisos.puedeManejarCatalogo(usuarioActivo);
}

class SesionNotifier extends Notifier<SesionState> {
  StreamSubscription<Usuario?>? _vigilancia;
  int? _vigilado;

  @override
  SesionState build() {
    ref.onDispose(() => _vigilancia?.cancel());
    listenSelf((_, sesion) => _vigilarUsuario(sesion.usuarioActivo?.id));
    return const SesionState();
  }

  /// Lo que cambie del usuario con sesión en otro celular (su permiso de
  /// catálogo, su nombre) llega a esta sesión sin volver a entrar: quitarle
  /// la confianza a un super vendedor surte efecto de una vez.
  void _vigilarUsuario(int? usuarioId) {
    if (usuarioId == _vigilado) return;
    _vigilado = usuarioId;
    unawaited(_vigilancia?.cancel());
    _vigilancia = null;
    if (usuarioId == null) return;
    final db = ref.read(databaseProvider);
    _vigilancia = (db.select(db.usuarios)..where((u) => u.id.equals(usuarioId)))
        .watchSingleOrNull()
        .listen((usuario) {
          // Desactivar o borrar al usuario ya lo resuelven sus propios flujos.
          if (usuario == null || state.usuarioActivo?.id != usuarioId) return;
          if (usuario != state.usuarioActivo) {
            state = SesionState(usuarioActivo: usuario);
          }
        });
  }

  /// Revisa el PIN en este celular. Un usuario que llegó de la tienda
  /// compartida y nunca entró aquí no tiene PIN guardado: se revisa en la
  /// nube (con internet) y queda guardado para entrar sin internet después.
  Future<ResultadoIngreso> iniciarSesion(int usuarioId, String pin) async {
    final repo = ref.read(usuarioRepositoryProvider);
    final guardado = await repo.buscar(usuarioId);
    if (guardado == null) return ResultadoIngreso.pinIncorrecto;
    if (!guardado.activo) return ResultadoIngreso.inactivo;
    if (guardado.pinHash.isEmpty) {
      final resultado = await _revisarEnLinea(guardado, pin);
      if (resultado != ResultadoIngreso.ok) return resultado;
      await repo.guardarPinLocal(usuarioId, pin);
    }
    final usuario = await repo.verificarPin(usuarioId, pin);
    if (usuario == null) return ResultadoIngreso.pinIncorrecto;
    state = SesionState(usuarioActivo: usuario);
    return ResultadoIngreso.ok;
  }

  Future<ResultadoIngreso> _revisarEnLinea(Usuario usuario, String pin) async {
    final sincronizador = ref.read(sincronizadorProvider);
    final tiendaId = await sincronizador?.tiendaId();
    if (sincronizador == null || tiendaId == null) {
      return ResultadoIngreso.pinIncorrecto;
    }
    try {
      return switch (await sincronizador.nube.verificarPin(
        tiendaId,
        usuario.idGlobal,
        pin,
      )) {
        ResultadoPin.ok => ResultadoIngreso.ok,
        ResultadoPin.incorrecto => ResultadoIngreso.pinIncorrecto,
        ResultadoPin.bloqueado => ResultadoIngreso.bloqueado,
        ResultadoPin.inactivo => ResultadoIngreso.inactivo,
      };
    } on ErrorSinConexion {
      return ResultadoIngreso.necesitaInternet;
    } on ErrorSesionTienda {
      return ResultadoIngreso.necesitaInternet;
    }
  }

  /// Tras una huella aprobada: abre sesión sin PIN si [usuarioId] la tiene
  /// activada y sigue existiendo; si ya no existe, lo olvida.
  Future<bool> iniciarSesionConHuella(int usuarioId) async {
    final huellas = ref.read(usuariosConHuellaProvider.notifier);
    if (!ref.read(usuariosConHuellaProvider).contains(usuarioId)) return false;
    final usuarios = await ref.read(usuarioRepositoryProvider).listarUsuarios();
    final usuario = usuarios.where((u) => u.id == usuarioId).firstOrNull;
    if (usuario != null && !usuario.activo) return false;
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
