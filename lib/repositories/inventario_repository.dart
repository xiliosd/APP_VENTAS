import 'package:drift/drift.dart';

import '../data/database.dart';

/// Existencias, conteos y entradas de mercancía. Las existencias no se
/// guardan: salen del último conteo, más lo recibido y menos lo vendido
/// después de él.
class InventarioRepository {
  InventarioRepository(this._db, {DateTime Function()? reloj})
      : _reloj = reloj ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _reloj;

  // ---- Existencias ----

  Future<int?> existencias(int productoId) async =>
      (await existenciasDe([productoId]))[productoId];

  /// Existencias de los productos de [productoIds] que tienen control y
  /// conteo (los demás no aparecen).
  Future<Map<int, int>> existenciasDe(Iterable<int> productoIds) async {
    final resultado = <int, int>{};
    for (final id in productoIds) {
      final producto = await (_db.select(_db.productos)
            ..where((p) => p.id.equals(id)))
          .getSingleOrNull();
      if (producto == null || !producto.controlaExistencias) continue;
      final conteo = await _ultimoConteo(id);
      if (conteo == null) continue;

      final recibidas = await (_db.select(_db.lineasEntrada).join([
        innerJoin(_db.entradasMercancia,
            _db.entradasMercancia.id.equalsExp(_db.lineasEntrada.entradaId)),
      ])
            ..where(_db.lineasEntrada.productoId.equals(id) &
                _db.entradasMercancia.anulada.equals(false) &
                _db.entradasMercancia.fecha.isBiggerThanValue(conteo.fecha)))
          .get();
      final vendidas = await (_db.select(_db.lineasVenta).join([
        innerJoin(_db.ventas, _db.ventas.id.equalsExp(_db.lineasVenta.ventaId)),
      ])
            ..where(_db.lineasVenta.productoId.equals(id) &
                _db.ventas.anulado.equals(false) &
                _db.ventas.fecha.isBiggerThanValue(conteo.fecha)))
          .get();

      resultado[id] = conteo.cantidad +
          recibidas.fold<int>(
              0, (s, f) => s + f.readTable(_db.lineasEntrada).cantidad) -
          vendidas.fold<int>(
              0, (s, f) => s + f.readTable(_db.lineasVenta).cantidad);
    }
    return resultado;
  }

  Future<ConteoInventario?> _ultimoConteo(int productoId) =>
      (_db.select(_db.conteosInventario)
            ..where((c) => c.productoId.equals(productoId))
            ..orderBy([
              (c) => OrderingTerm.desc(c.fecha),
              (c) => OrderingTerm.desc(c.id),
            ])
            ..limit(1))
          .getSingleOrNull();

  // ---- Control y conteos ----

  /// Activa el control con [cantidad] unidades hoy y [minimo].
  Future<void> activarControl(
    int productoId, {
    required int cantidad,
    required int minimo,
    required Usuario por,
  }) async {
    if (cantidad < 0) throw ArgumentError('Escribe cuántas hay');
    if (minimo < 0) throw ArgumentError('Escribe un mínimo válido');
    await _db.transaction(() async {
      await (_db.update(_db.productos)..where((p) => p.id.equals(productoId)))
          .write(ProductosCompanion(
              controlaExistencias: const Value(true), minimo: Value(minimo)));
      await _db.into(_db.conteosInventario).insert(
            ConteosInventarioCompanion.insert(
              productoId: productoId,
              cantidad: cantidad,
              tipo: TipoConteo.inicial,
              usuarioId: por.id,
              fecha: _reloj(),
            ),
          );
    });
  }

  /// Deja de controlar existencias; el historial se conserva.
  Future<void> desactivarControl(int productoId) =>
      (_db.update(_db.productos)..where((p) => p.id.equals(productoId))).write(
          const ProductosCompanion(controlaExistencias: Value(false)));

  Future<void> cambiarMinimo(int productoId, int minimo) async {
    if (minimo < 0) throw ArgumentError('Escribe un mínimo válido');
    await (_db.update(_db.productos)..where((p) => p.id.equals(productoId)))
        .write(ProductosCompanion(minimo: Value(minimo)));
  }

  /// Registra que hay [cantidad] unidades; guarda lo que decía la app.
  Future<void> ajustarConteo(
    int productoId, {
    required int cantidad,
    String? nota,
    required Usuario por,
  }) async {
    if (cantidad < 0) throw ArgumentError('Escribe cuántas hay');
    final anterior = await existencias(productoId);
    if (anterior == null) {
      throw ArgumentError('El producto no controla existencias');
    }
    final limpia = nota?.trim() ?? '';
    await _db.into(_db.conteosInventario).insert(
          ConteosInventarioCompanion.insert(
            productoId: productoId,
            cantidad: cantidad,
            anterior: Value(anterior),
            tipo: TipoConteo.ajuste,
            nota: Value(limpia.isEmpty ? null : limpia),
            usuarioId: por.id,
            fecha: _reloj(),
          ),
        );
  }
}
