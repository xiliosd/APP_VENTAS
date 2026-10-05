import 'package:drift/drift.dart';

import '../data/database.dart';

class ProductoRepository {
  ProductoRepository(this._db);

  final AppDatabase _db;

  Stream<List<Producto>> observarProductosActivos() {
    return (_db.select(_db.productos)..where((p) => p.activo.equals(true)))
        .watch();
  }

  Future<List<Producto>> listarTodos() => _db.select(_db.productos).get();

  Future<int> crearProducto({required String nombre, required int precio}) {
    return _db.into(_db.productos).insert(
          ProductosCompanion.insert(nombre: nombre, precio: precio),
        );
  }

  Future<void> actualizarProducto(int id, {String? nombre, int? precio}) {
    return (_db.update(_db.productos)..where((p) => p.id.equals(id))).write(
      ProductosCompanion(
        nombre: nombre != null ? Value(nombre) : const Value.absent(),
        precio: precio != null ? Value(precio) : const Value.absent(),
      ),
    );
  }

  Future<void> desactivarProducto(int id) {
    return (_db.update(_db.productos)..where((p) => p.id.equals(id)))
        .write(const ProductosCompanion(activo: Value(false)));
  }

  Stream<List<Producto>> observarProductosInactivos() {
    return (_db.select(_db.productos)..where((p) => p.activo.equals(false)))
        .watch();
  }

  Future<void> reactivarProducto(int id) {
    return (_db.update(_db.productos)..where((p) => p.id.equals(id)))
        .write(const ProductosCompanion(activo: Value(true)));
  }
}
