import 'package:drift/drift.dart';

import '../data/database.dart';

/// Un proveedor de un producto, tal como se edita en el formulario.
class ProveedorDeProducto {
  const ProveedorDeProducto({
    required this.proveedorId,
    required this.precioCompra,
    required this.preferido,
  });

  final int proveedorId;
  final int precioCompra;
  final bool preferido;
}

/// Código de barras, marca, tamaño, envase y tipo de un producto.
class DetallesProducto {
  const DetallesProducto({
    this.codigoBarras,
    this.marca,
    this.tamano,
    this.envase,
    this.tipo,
  });

  final String? codigoBarras;
  final String? marca;
  final String? tamano;
  final String? envase;
  final String? tipo;
}

/// Otro producto activo ya tiene ese código de barras.
class CodigoRepetido implements Exception {
  const CodigoRepetido(this.nombre);

  /// Nombre del producto que ya lo tiene.
  final String nombre;
}

String? _limpio(String? texto) {
  final t = texto?.trim();
  return t == null || t.isEmpty ? null : t;
}

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

  /// Proveedores de [productoId] en el orden en que se agregaron.
  Future<List<ProductoProveedor>> proveedoresDe(int productoId) =>
      (_db.select(_db.productosProveedores)
            ..where((p) => p.productoId.equals(productoId))
            ..orderBy([(p) => OrderingTerm.asc(p.id)]))
          .get();

  /// Precio de compra del proveedor preferido; null sin proveedores.
  Future<int?> costoDe(int productoId) async {
    final preferido = await (_db.select(_db.productosProveedores)
          ..where((p) =>
              p.productoId.equals(productoId) & p.preferido.equals(true)))
        .getSingleOrNull();
    return preferido?.precioCompra;
  }

  /// Producto → costo, solo de los productos con proveedor preferido.
  Future<Map<int, int>> costos() async {
    final filas = await (_db.select(_db.productosProveedores)
          ..where((p) => p.preferido.equals(true)))
        .get();
    return {for (final f in filas) f.productoId: f.precioCompra};
  }

  /// Crea ([id] null) o actualiza el producto y reemplaza sus proveedores,
  /// todo en una transacción. Devuelve el id.
  Future<int> guardarProducto({
    int? id,
    required String nombre,
    required int precio,
    List<ProveedorDeProducto> proveedores = const [],
    DetallesProducto? detalles,
  }) async {
    final limpio = nombre.trim();
    if (limpio.isEmpty) throw ArgumentError('Escribe un nombre');
    if (precio <= 0) throw ArgumentError('Escribe un precio válido');
    if (proveedores.any((p) => p.precioCompra <= 0)) {
      throw ArgumentError('Precio de compra inválido');
    }
    if (proveedores.map((p) => p.proveedorId).toSet().length !=
        proveedores.length) {
      throw ArgumentError('Proveedor repetido');
    }
    if (proveedores.isNotEmpty &&
        proveedores.where((p) => p.preferido).length != 1) {
      throw ArgumentError('Debe haber un proveedor preferido');
    }
    return _db.transaction(() async {
      final previos = id == null
          ? <int>{}
          : (await proveedoresDe(id)).map((p) => p.proveedorId).toSet();
      for (final p in proveedores) {
        if (previos.contains(p.proveedorId)) continue;
        final proveedor = await (_db.select(_db.proveedores)
              ..where((x) => x.id.equals(p.proveedorId)))
            .getSingleOrNull();
        if (proveedor == null || !proveedor.activo) {
          throw ArgumentError('Proveedor inactivo');
        }
      }
      final codigo = _limpio(detalles?.codigoBarras);
      if (codigo != null) {
        final otro = await (_db.select(_db.productos)
              ..where((p) =>
                  p.codigoBarras.equals(codigo) &
                  p.activo.equals(true) &
                  (id == null ? const Constant(true) : p.id.equals(id).not())))
            .getSingleOrNull();
        if (otro != null) throw CodigoRepetido(otro.nombre);
      }
      final columnas = detalles == null
          ? const ProductosCompanion()
          : ProductosCompanion(
              codigoBarras: Value(codigo),
              marca: Value(_limpio(detalles.marca)),
              tamano: Value(_limpio(detalles.tamano)),
              envase: Value(_limpio(detalles.envase)),
              tipo: Value(_limpio(detalles.tipo)),
            );
      final productoId = id ??
          await _db.into(_db.productos).insert(columnas.copyWith(
              nombre: Value(limpio), precio: Value(precio)));
      if (id != null) {
        await (_db.update(_db.productos)..where((p) => p.id.equals(id)))
            .write(columnas.copyWith(
                nombre: Value(limpio), precio: Value(precio)));
      }
      await (_db.delete(_db.productosProveedores)
            ..where((p) => p.productoId.equals(productoId)))
          .go();
      for (final p in proveedores) {
        await _db.into(_db.productosProveedores).insert(
              ProductosProveedoresCompanion.insert(
                productoId: productoId,
                proveedorId: p.proveedorId,
                precioCompra: p.precioCompra,
                preferido: Value(p.preferido),
              ),
            );
      }
      return productoId;
    });
  }

  /// El producto con [codigo] (recortado); prefiere el activo.
  Future<Producto?> productoPorCodigo(String codigo) async {
    final limpio = codigo.trim();
    if (limpio.isEmpty) return null;
    final filas = await (_db.select(_db.productos)
          ..where((p) => p.codigoBarras.equals(limpio)))
        .get();
    return filas.where((p) => p.activo).firstOrNull ?? filas.firstOrNull;
  }

  /// Marcas de los productos activos, sin repetir y en orden alfabético.
  Future<List<String>> marcasUsadas() async {
    final filas = await (_db.select(_db.productos)
          ..where((p) => p.activo.equals(true) & p.marca.isNotNull()))
        .get();
    return {for (final p in filas) p.marca!}.toList()..sort();
  }
}
