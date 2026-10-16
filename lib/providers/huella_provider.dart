import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../respaldo/respaldo_provider.dart';
import '../servicios/autenticacion_huella.dart';

/// Preferencia: ids de los usuarios que activaron la huella en este celular.
/// No va en la base de datos: la huella es del celular, no de la tienda.
const claveUsuariosConHuella = 'usuarios_con_huella';

class UsuariosConHuella extends Notifier<Set<int>> {
  @override
  Set<int> build() => {
    for (final id
        in ref
                .read(preferenciasProvider)
                .getStringList(claveUsuariosConHuella) ??
            const <String>[])
      ?int.tryParse(id),
  };

  Future<void> activar(int usuarioId) => _guardar({...state, usuarioId});

  Future<void> desactivar(int usuarioId) =>
      _guardar({...state}..remove(usuarioId));

  /// Al restaurar un respaldo: la base nueva puede traer otras personas con
  /// los mismos ids.
  Future<void> borrarTodas() => _guardar({});

  /// Quita los ids que ya no están en [existentes].
  Future<void> conservarSolo(Iterable<int> existentes) =>
      _guardar(state.intersection(existentes.toSet()));

  Future<void> _guardar(Set<int> ids) async {
    state = ids;
    await ref.read(preferenciasProvider).setStringList(claveUsuariosConHuella, [
      for (final id in ids) '$id',
    ]);
  }
}

final usuariosConHuellaProvider = NotifierProvider<UsuariosConHuella, Set<int>>(
  UsuariosConHuella.new,
);

/// El celular tiene biometría registrada (se consulta una vez por sesión de
/// la app; se invalida al volver a mirar).
final huellaDisponibleProvider = FutureProvider<bool>(
  (ref) => ref.watch(autenticacionHuellaProvider).disponible(),
);
