import 'package:drift/drift.dart';

import '../data/database.dart';
import '../util/texto_util.dart';

String? _opcional(String? texto) {
  final limpio = texto?.trim() ?? '';
  return limpio.isEmpty ? null : limpio;
}

String _nombreValido(String nombre) {
  final limpio = nombre.trim();
  if (limpio.isEmpty) throw ArgumentError('Escribe un nombre');
  return limpio;
}

/// Proveedores de la tienda. No se borran: se desactivan.
class ProveedorRepository {
  ProveedorRepository(this._db);

  final AppDatabase _db;

  Stream<List<Proveedor>> observarActivos() => (_db.select(_db.proveedores)
        ..where((p) => p.activo.equals(true))
        ..orderBy([(p) => OrderingTerm.asc(p.nombre)]))
      .watch();

  Stream<List<Proveedor>> observarInactivos() => (_db.select(_db.proveedores)
        ..where((p) => p.activo.equals(false))
        ..orderBy([(p) => OrderingTerm.asc(p.nombre)]))
      .watch();

  Future<List<Proveedor>> todos() => _db.select(_db.proveedores).get();

  /// Proveedor (activo o no) con el mismo nombre que [nombre], según
  /// [claveNombre].
  Future<Proveedor?> buscarPorNombre(String nombre) async {
    final clave = claveNombre(nombre);
    for (final p in await todos()) {
      if (claveNombre(p.nombre) == clave) return p;
    }
    return null;
  }

  Future<void> _sinRepetir(String nombre, {int? salvo}) async {
    final existente = await buscarPorNombre(nombre);
    if (existente != null && existente.id != salvo) {
      throw ArgumentError('Ya existe un proveedor con ese nombre');
    }
  }

  Future<int> crear({
    required String nombre,
    String? telefono,
    String? notas,
  }) async {
    final limpio = _nombreValido(nombre);
    await _sinRepetir(limpio);
    return _db.into(_db.proveedores).insert(ProveedoresCompanion.insert(
          nombre: limpio,
          telefono: Value(_opcional(telefono)),
          notas: Value(_opcional(notas)),
        ));
  }

  Future<void> actualizar(
    int id, {
    required String nombre,
    String? telefono,
    String? notas,
  }) async {
    final limpio = _nombreValido(nombre);
    await _sinRepetir(limpio, salvo: id);
    await (_db.update(_db.proveedores)..where((p) => p.id.equals(id))).write(
      ProveedoresCompanion(
        nombre: Value(limpio),
        telefono: Value(_opcional(telefono)),
        notas: Value(_opcional(notas)),
      ),
    );
  }

  Future<void> desactivar(int id) =>
      (_db.update(_db.proveedores)..where((p) => p.id.equals(id)))
          .write(const ProveedoresCompanion(activo: Value(false)));

  Future<void> reactivar(int id) =>
      (_db.update(_db.proveedores)..where((p) => p.id.equals(id)))
          .write(const ProveedoresCompanion(activo: Value(true)));

  /// Proveedor → cuántos productos surte (solo los que surten alguno).
  Future<Map<int, int>> cantidadProductos() async {
    final filas = await _db.select(_db.productosProveedores).get();
    final conteo = <int, int>{};
    for (final f in filas) {
      conteo.update(f.proveedorId, (n) => n + 1, ifAbsent: () => 1);
    }
    return conteo;
  }

  /// Productos que surte [proveedorId], por nombre, con su precio de compra.
  Future<List<({Producto producto, int precioCompra})>> productosDe(
      int proveedorId) async {
    final filas = await (_db.select(_db.productosProveedores).join([
      innerJoin(_db.productos,
          _db.productos.id.equalsExp(_db.productosProveedores.productoId)),
    ])
          ..where(_db.productosProveedores.proveedorId.equals(proveedorId))
          ..orderBy([OrderingTerm.asc(_db.productos.nombre)]))
        .get();
    return [
      for (final f in filas)
        (
          producto: f.readTable(_db.productos),
          precioCompra: f.readTable(_db.productosProveedores).precioCompra,
        ),
    ];
  }
}
