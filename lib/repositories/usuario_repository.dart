import 'package:drift/drift.dart';

import '../data/database.dart';
import '../util/pin_hash.dart';

class UsuarioRepository {
  UsuarioRepository(this._db);

  final AppDatabase _db;

  Future<List<Usuario>> listarUsuarios() => _db.select(_db.usuarios).get();

  Future<bool> existeAlgunUsuario() async {
    final usuarios = await listarUsuarios();
    return usuarios.isNotEmpty;
  }

  Future<int> crearUsuario({
    required String nombre,
    required String rol,
    required String pin,
  }) {
    return _db.into(_db.usuarios).insert(
          UsuariosCompanion.insert(
            nombre: nombre,
            rol: rol,
            pinHash: hashPin(pin),
          ),
        );
  }

  Future<Usuario?> verificarPin(int usuarioId, String pin) async {
    final usuario = await (_db.select(_db.usuarios)
          ..where((u) => u.id.equals(usuarioId)))
        .getSingleOrNull();
    if (usuario == null) return null;
    return usuario.pinHash == hashPin(pin) ? usuario : null;
  }

  Future<void> resetearPin(int usuarioId, String nuevoPin) {
    return (_db.update(_db.usuarios)..where((u) => u.id.equals(usuarioId)))
        .write(UsuariosCompanion(pinHash: Value(hashPin(nuevoPin))));
  }
}
