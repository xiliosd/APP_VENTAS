import 'package:drift/drift.dart';

import '../data/database.dart';
import 'correccion_repository.dart';

/// Un producto para guardar en un pedido.
class LineaPedidoNueva {
  const LineaPedidoNueva({
    required this.productoId,
    required this.cantidad,
    this.precioEsperado,
  });

  final int productoId;
  final int cantidad;
  final int? precioEsperado;
}

/// Un pedido con su proveedor, quien lo hizo y sus cifras.
class PedidoResumen {
  const PedidoResumen({
    required this.pedido,
    required this.proveedor,
    required this.usuario,
    required this.productos,
    required this.totalEstimado,
  });

  final Pedido pedido;
  final Proveedor proveedor;
  final String usuario;
  final int productos;

  /// Σ cantidad × precio esperado; las líneas sin precio cuentan 0.
  final int totalEstimado;
}

/// Una línea del pedido con su producto (activo o no).
class LineaPedidoDetalle {
  const LineaPedidoDetalle({required this.linea, required this.producto});

  final LineaPedido linea;
  final Producto producto;
}

/// Cantidad pedida y aún por llegar de cada producto (id → unidades).
Future<Map<int, int>> cantidadesPorLlegar(AppDatabase db) async {
  final filas = await (db.select(db.lineasPedido).join([
    innerJoin(db.pedidos, db.pedidos.id.equalsExp(db.lineasPedido.pedidoId)),
  ])..where(db.pedidos.estado.equalsValue(EstadoPedido.porLlegar))).get();
  final total = <int, int>{};
  for (final f in filas) {
    final l = f.readTable(db.lineasPedido);
    total[l.productoId] = (total[l.productoId] ?? 0) + l.cantidad;
  }
  return total;
}

/// Pedidos guardados desde el pedido sugerido mientras llega la mercancía.
/// Recibirlos es cosa de `InventarioRepository.recibirMercancia`.
class PedidoRepository {
  PedidoRepository(this._db, {DateTime Function()? reloj})
    : _reloj = reloj ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _reloj;

  Future<int> guardarPedido({
    required int proveedorId,
    required List<LineaPedidoNueva> lineas,
    required Usuario por,
  }) {
    _validar(lineas);
    return _db.transaction(() async {
      final proveedor = await (_db.select(
        _db.proveedores,
      )..where((p) => p.id.equals(proveedorId))).getSingleOrNull();
      if (proveedor == null || !proveedor.activo) {
        throw ArgumentError('Proveedor inactivo');
      }
      final id = await _db
          .into(_db.pedidos)
          .insert(
            PedidosCompanion.insert(
              proveedorId: proveedorId,
              usuarioId: por.id,
              fecha: _reloj(),
            ),
          );
      await _insertarLineas(id, lineas);
      return id;
    });
  }

  /// Reemplaza todas las líneas del pedido.
  Future<void> editarPedido(
    int pedidoId,
    List<LineaPedidoNueva> lineas, {
    required Usuario por,
  }) {
    _validar(lineas);
    return _db.transaction(() async {
      await _porLlegarDe(pedidoId, por);
      await (_db.delete(
        _db.lineasPedido,
      )..where((l) => l.pedidoId.equals(pedidoId))).go();
      await _insertarLineas(pedidoId, lineas);
    });
  }

  Future<void> anularPedido(int pedidoId, {required Usuario por}) {
    return _db.transaction(() async {
      await _porLlegarDe(pedidoId, por);
      await (_db.update(_db.pedidos)..where((p) => p.id.equals(pedidoId)))
          .write(const PedidosCompanion(estado: Value(EstadoPedido.anulado)));
    });
  }

  /// Pedidos por llegar, del más viejo al más nuevo; con [proveedorId], solo
  /// los de ese proveedor.
  Future<List<PedidoResumen>> pedidosPorLlegar({int? proveedorId}) async {
    final consulta = _db.select(_db.pedidos)
      ..where((p) => p.estado.equalsValue(EstadoPedido.porLlegar))
      ..orderBy([
        (p) => OrderingTerm.asc(p.fecha),
        (p) => OrderingTerm.asc(p.id),
      ]);
    if (proveedorId != null) {
      consulta.where((p) => p.proveedorId.equals(proveedorId));
    }
    return [for (final p in await consulta.get()) await _resumen(p)];
  }

  Future<({PedidoResumen resumen, List<LineaPedidoDetalle> lineas})>
  detallePedido(int pedidoId) async {
    final pedido = await (_db.select(
      _db.pedidos,
    )..where((p) => p.id.equals(pedidoId))).getSingle();
    return (resumen: await _resumen(pedido), lineas: await _lineas(pedidoId));
  }

  // ---- Apoyo ----

  void _validar(List<LineaPedidoNueva> lineas) {
    if (lineas.isEmpty) throw ArgumentError('Agrega al menos un producto');
    if (lineas.any((l) => l.cantidad <= 0)) {
      throw ArgumentError('Cantidad inválida');
    }
    if (lineas.map((l) => l.productoId).toSet().length != lineas.length) {
      throw ArgumentError('Producto repetido');
    }
  }

  Future<void> _insertarLineas(
    int pedidoId,
    List<LineaPedidoNueva> lineas,
  ) async {
    for (final l in lineas) {
      await _db
          .into(_db.lineasPedido)
          .insert(
            LineasPedidoCompanion.insert(
              pedidoId: pedidoId,
              productoId: l.productoId,
              cantidad: l.cantidad,
              precioEsperado: Value(l.precioEsperado),
            ),
          );
    }
  }

  /// El pedido, si sigue por llegar y [por] puede cambiarlo (autor o admin).
  Future<Pedido> _porLlegarDe(int pedidoId, Usuario por) async {
    final pedido = await (_db.select(
      _db.pedidos,
    )..where((p) => p.id.equals(pedidoId))).getSingle();
    if (pedido.estado != EstadoPedido.porLlegar) {
      throw ArgumentError('El pedido ya no está por llegar');
    }
    if (por.rol != 'admin' && pedido.usuarioId != por.id) {
      throw const PermisoDenegado();
    }
    return pedido;
  }

  Future<List<LineaPedidoDetalle>> _lineas(int pedidoId) async {
    final filas =
        await (_db.select(_db.lineasPedido).join([
                innerJoin(
                  _db.productos,
                  _db.productos.id.equalsExp(_db.lineasPedido.productoId),
                ),
              ])
              ..where(_db.lineasPedido.pedidoId.equals(pedidoId))
              ..orderBy([OrderingTerm.asc(_db.lineasPedido.id)]))
            .get();
    return [
      for (final f in filas)
        LineaPedidoDetalle(
          linea: f.readTable(_db.lineasPedido),
          producto: f.readTable(_db.productos),
        ),
    ];
  }

  Future<PedidoResumen> _resumen(Pedido pedido) async {
    final proveedor = await (_db.select(
      _db.proveedores,
    )..where((p) => p.id.equals(pedido.proveedorId))).getSingle();
    final usuario = await (_db.select(
      _db.usuarios,
    )..where((u) => u.id.equals(pedido.usuarioId))).getSingle();
    final lineas = await (_db.select(
      _db.lineasPedido,
    )..where((l) => l.pedidoId.equals(pedido.id))).get();
    return PedidoResumen(
      pedido: pedido,
      proveedor: proveedor,
      usuario: usuario.nombre,
      productos: lineas.length,
      totalEstimado: lineas.fold(
        0,
        (s, l) => s + l.cantidad * (l.precioEsperado ?? 0),
      ),
    );
  }
}
