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

  /// Id del cliente cuyo nombre coincide con [nombre] (sin importar
  /// mayúsculas ni espacios de los extremos); si no existe, lo crea.
  Future<int> obtenerOCrearCliente(String nombre) async {
    final limpio = nombre.trim();
    final buscado = limpio.toLowerCase();
    for (final cliente in await listarClientes()) {
      if (cliente.nombre.trim().toLowerCase() == buscado) return cliente.id;
    }
    return crearCliente(nombre: limpio);
  }

  /// Nombre de cada cliente de [ids], por id.
  Future<Map<int, String>> nombresPorId(Iterable<int> ids) async {
    if (ids.isEmpty) return {};
    final filas = await (_db.select(_db.clientes)
          ..where((c) => c.id.isIn(ids)))
        .get();
    return {for (final c in filas) c.id: c.nombre};
  }
}
