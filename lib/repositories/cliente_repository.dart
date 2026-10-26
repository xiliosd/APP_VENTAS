import 'package:drift/drift.dart';

import '../data/database.dart';
import '../util/nombre_cliente.dart';

class ClienteRepository {
  ClienteRepository(this._db);

  final AppDatabase _db;

  Future<List<Cliente>> listarClientes() => _db.select(_db.clientes).get();

  /// No revisa clientes parecidos: eso lo decide la interfaz con
  /// [clientesParecidos] para no bloquear al vendedor.
  Future<int> crearCliente({
    required String nombre,
    required String apellido,
    String? telefono,
    String? notas,
  }) async {
    return _db.into(_db.clientes).insert(
          _datos(nombre, apellido, telefono, notas),
        );
  }

  Future<void> actualizarCliente(
    int id, {
    required String nombre,
    required String apellido,
    String? telefono,
    String? notas,
  }) async {
    await (_db.update(_db.clientes)..where((c) => c.id.equals(id)))
        .write(_datos(nombre, apellido, telefono, notas));
  }

  ClientesCompanion _datos(
    String nombre,
    String apellido,
    String? telefono,
    String? notas,
  ) {
    final nombreLimpio = nombre.trim();
    final apellidoLimpio = apellido.trim();
    if (nombreLimpio.isEmpty) throw ArgumentError('Escribe el nombre');
    if (apellidoLimpio.isEmpty) throw ArgumentError('Escribe el apellido');
    final notasLimpias = notas?.trim() ?? '';
    return ClientesCompanion(
      nombre: Value(nombreLimpio),
      apellido: Value(apellidoLimpio),
      telefono: Value(telefonoNormalizado(telefono)),
      notas: Value(notasLimpias.isEmpty ? null : notasLimpias),
    );
  }

  /// Clientes con el mismo nombre completo (sin tildes ni mayúsculas) o el
  /// mismo teléfono que los dados, sin contar a [salvo]; A–Z.
  Future<List<Cliente>> clientesParecidos({
    required String nombre,
    required String apellido,
    String? telefono,
    int? salvo,
  }) async {
    final clave = claveCliente('${nombre.trim()} ${apellido.trim()}');
    final telefonoBuscado = telefonoNormalizado(telefono);
    final parecidos = (await listarClientes()).where((cliente) {
      if (cliente.id == salvo) return false;
      if (claveCliente(cliente.nombreCompleto) == clave) return true;
      return telefonoBuscado != null &&
          telefonoNormalizado(cliente.telefono) == telefonoBuscado;
    }).toList();
    parecidos.sort((a, b) => claveCliente(a.nombreCompleto)
        .compareTo(claveCliente(b.nombreCompleto)));
    return parecidos;
  }

  /// Ventas no anuladas del cliente (contado y fiado), las más recientes
  /// primero.
  Future<List<Venta>> comprasCliente(int clienteId) {
    return (_db.select(_db.ventas)
          ..where((v) => v.clienteId.equals(clienteId) & v.anulado.not())
          ..orderBy([
            (v) => OrderingTerm.desc(v.fecha),
            (v) => OrderingTerm.desc(v.id),
          ]))
        .get();
  }

  Future<Cliente?> obtenerCliente(int id) {
    return (_db.select(_db.clientes)..where((c) => c.id.equals(id)))
        .getSingleOrNull();
  }

  /// Nombre completo de cada cliente de [ids], por id.
  Future<Map<int, String>> nombresPorId(Iterable<int> ids) async {
    if (ids.isEmpty) return {};
    final filas = await (_db.select(_db.clientes)
          ..where((c) => c.id.isIn(ids)))
        .get();
    return {for (final c in filas) c.id: c.nombreCompleto};
  }
}
