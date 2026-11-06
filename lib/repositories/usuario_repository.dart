import 'package:drift/drift.dart';

import '../data/database.dart';
import '../util/pin_hash.dart';

class UsuarioRepository {
  UsuarioRepository(this._db);

  final AppDatabase _db;

  /// Todos, también los desactivados (la pantalla de Usuarios los muestra).
  Future<List<Usuario>> listarUsuarios() => _db.select(_db.usuarios).get();

  /// Los que pueden entrar: los de "¿Quién eres?".
  Future<List<Usuario>> listarActivos() =>
      (_db.select(_db.usuarios)..where((u) => u.activo.equals(true))).get();

  Future<bool> existeAlgunUsuario() async {
    final usuarios = await listarUsuarios();
    return usuarios.isNotEmpty;
  }

  Future<int> crearUsuario({
    required String nombre,
    required String rol,
    required String pin,
    int? numeroVendedor,
  }) {
    return _db
        .into(_db.usuarios)
        .insert(
          UsuariosCompanion.insert(
            nombre: nombre,
            rol: rol,
            pinHash: hashPin(pin),
            numeroVendedor: Value(numeroVendedor),
          ),
        );
  }

  Future<Usuario?> buscar(int usuarioId) => (_db.select(
    _db.usuarios,
  )..where((u) => u.id.equals(usuarioId))).getSingleOrNull();

  Future<Usuario?> verificarPin(int usuarioId, String pin) async {
    final usuario = await buscar(usuarioId);
    if (usuario == null || !usuario.activo) return null;
    return usuario.pinHash == hashPin(pin) ? usuario : null;
  }

  /// El número que se le da al próximo vendedor: el mayor más uno.
  Future<int> siguienteNumeroVendedor() async {
    final mayor = _db.usuarios.numeroVendedor.max();
    final fila = await (_db.selectOnly(
      _db.usuarios,
    )..addColumns([mayor])).getSingle();
    return (fila.read(mayor) ?? 0) + 1;
  }

  Future<void> resetearPin(int usuarioId, String nuevoPin) {
    return _db.customUpdate(
      'UPDATE usuarios SET pin_hash = ?, version_pin = version_pin + 1 '
      'WHERE id = ?',
      variables: [
        Variable.withString(hashPin(nuevoPin)),
        Variable.withInt(usuarioId),
      ],
      updates: {_db.usuarios},
    );
  }

  /// Guarda el PIN que la nube acaba de aceptar, para entrar sin internet la
  /// próxima vez.
  Future<void> guardarPinLocal(int usuarioId, String pin) =>
      (_db.update(_db.usuarios)..where((u) => u.id.equals(usuarioId))).write(
        UsuariosCompanion(pinHash: Value(hashPin(pin))),
      );

  Future<void> desactivar(int usuarioId) =>
      (_db.update(_db.usuarios)..where((u) => u.id.equals(usuarioId))).write(
        const UsuariosCompanion(activo: Value(false)),
      );

  Future<void> activar(int usuarioId) =>
      (_db.update(_db.usuarios)..where((u) => u.id.equals(usuarioId))).write(
        const UsuariosCompanion(activo: Value(true)),
      );
}
