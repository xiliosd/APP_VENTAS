import 'package:drift/drift.dart';

import '../data/database.dart';

class ClienteRepository {
  ClienteRepository(this._db);

  final AppDatabase _db;

  Future<List<Cliente>> listarClientes() => _db.select(_db.clientes).get();

  Future<int> crearCliente({required String nombre, String? telefono}) {
    return _db.into(_db.clientes).insert(
          ClientesCompanion.insert(
            nombre: nombre,
            telefono: Value(telefono),
          ),
        );
  }

  Future<Cliente?> obtenerCliente(int id) {
    return (_db.select(_db.clientes)..where((c) => c.id.equals(id)))
        .getSingleOrNull();
  }
}
