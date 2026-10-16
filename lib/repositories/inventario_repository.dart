import 'package:drift/drift.dart';

import '../data/database.dart';
import '../util/categorias_gasto.dart';
import '../util/permisos.dart';
import 'correccion_repository.dart';
import 'pedido_repository.dart';

/// Un producto recibido en una entrada.
class LineaRecibida {
  const LineaRecibida({
    required this.productoId,
    required this.cantidad,
    required this.precioCompra,
  });

  final int productoId;
  final int cantidad;
  final int precioCompra;
}

/// Una entrada con sus líneas y nombres, el gasto que generó y, si vino de un
/// pedido, las líneas que se pidieron.
typedef DetalleEntrada = ({
  EntradaResumen resumen,
  List<({LineaEntrada linea, String producto})> lineas,
  Gasto? gasto,
  List<LineaPedidoDetalle>? lineasPedido,
});

/// Una entrada con los nombres de su proveedor y de quien la recibió.
class EntradaResumen {
  const EntradaResumen({
    required this.entrada,
    required this.proveedor,
    required this.usuario,
  });

  final EntradaMercancia entrada;
  final String proveedor;
  final String usuario;
}

/// Un producto en "Por pedir".
class ProductoPorPedir {
  const ProductoPorPedir({required this.producto, required this.existencias});

  final Producto producto;
  final int existencias;
}

/// Productos por pedir de un mismo proveedor preferido (null = sin proveedor).
class GrupoPorPedir {
  const GrupoPorPedir({required this.proveedor, required this.productos});

  final Proveedor? proveedor;
  final List<ProductoPorPedir> productos;
}

enum TipoMovimientoInventario { conteoInicial, ajuste, entrada }

/// Un evento del historial de existencias de un producto.
class MovimientoInventario {
  const MovimientoInventario({
    required this.tipo,
    required this.fecha,
    required this.cantidad,
    required this.quien,
    this.anterior,
    this.anulada = false,
  });

  final TipoMovimientoInventario tipo;
  final DateTime fecha;
  final int cantidad;

  /// Usuario que contó, o proveedor de la entrada.
  final String quien;

  /// Solo en ajustes: lo que decía la app.
  final int? anterior;

  /// Solo en entradas.
  final bool anulada;
}

/// Una línea del pedido sugerido a un proveedor.
class LineaSugerida {
  const LineaSugerida({
    required this.producto,
    required this.existencias,
    required this.sugerido,
    this.precio,
  });

  final Producto producto;
  final int existencias;

  /// (pedirHasta ?? 2 × mínimo) − existencias, nunca menos de 1.
  final int sugerido;

  /// Precio de compra con ese proveedor; null si no lo tiene.
  final int? precio;
}

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
    // Pocas consultas en lote, sin importar cuántos productos haya: productos
    // con control, sus conteos, y las líneas recibidas y vendidas desde el
    // conteo más viejo; luego cada producto filtra desde su último conteo.
    final ids = productoIds.toSet().toList();
    if (ids.isEmpty) return {};
    final controlados =
        (await (_db.select(_db.productos)..where(
                  (p) => p.id.isIn(ids) & p.controlaExistencias.equals(true),
                ))
                .get())
            .map((p) => p.id)
            .toList();
    if (controlados.isEmpty) return {};
    final ultimo = <int, ConteoInventario>{};
    for (final c
        in await (_db.select(_db.conteosInventario)
              ..where((c) => c.productoId.isIn(controlados))
              ..orderBy([
                (c) => OrderingTerm.asc(c.fecha),
                (c) => OrderingTerm.asc(c.id),
              ]))
            .get()) {
      ultimo[c.productoId] = c;
    }
    if (ultimo.isEmpty) return {};
    final desde = ultimo.values
        .map((c) => c.fecha)
        .reduce((a, b) => a.isBefore(b) ? a : b);

    final resultado = {for (final e in ultimo.entries) e.key: e.value.cantidad};
    final recibidas =
        await (_db.select(_db.lineasEntrada).join([
              innerJoin(
                _db.entradasMercancia,
                _db.entradasMercancia.id.equalsExp(_db.lineasEntrada.entradaId),
              ),
            ])..where(
              _db.lineasEntrada.productoId.isIn(ultimo.keys) &
                  _db.entradasMercancia.anulada.equals(false) &
                  _db.entradasMercancia.fecha.isBiggerThanValue(desde),
            ))
            .get();
    for (final f in recibidas) {
      final linea = f.readTable(_db.lineasEntrada);
      final fecha = f.readTable(_db.entradasMercancia).fecha;
      if (fecha.isAfter(ultimo[linea.productoId]!.fecha)) {
        resultado[linea.productoId] =
            resultado[linea.productoId]! + linea.cantidad;
      }
    }
    final vendidas =
        await (_db.select(_db.lineasVenta).join([
              innerJoin(
                _db.ventas,
                _db.ventas.id.equalsExp(_db.lineasVenta.ventaId),
              ),
            ])..where(
              _db.lineasVenta.productoId.isIn(ultimo.keys) &
                  _db.ventas.anulado.equals(false) &
                  _db.ventas.fecha.isBiggerThanValue(desde),
            ))
            .get();
    for (final f in vendidas) {
      final linea = f.readTable(_db.lineasVenta);
      final productoId = linea.productoId!;
      if (f.readTable(_db.ventas).fecha.isAfter(ultimo[productoId]!.fecha)) {
        resultado[productoId] = resultado[productoId]! - linea.cantidad;
      }
    }
    return resultado;
  }

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
      await (_db.update(
        _db.productos,
      )..where((p) => p.id.equals(productoId))).write(
        ProductosCompanion(
          controlaExistencias: const Value(true),
          minimo: Value(minimo),
        ),
      );
      await _db
          .into(_db.conteosInventario)
          .insert(
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

  /// Deja de controlar existencias; el historial se conserva y "pedir hasta"
  /// se borra (al activarlo de nuevo se vuelve a pedir el mínimo).
  Future<void> desactivarControl(int productoId) =>
      (_db.update(_db.productos)..where((p) => p.id.equals(productoId))).write(
        const ProductosCompanion(
          controlaExistencias: Value(false),
          pedirHasta: Value(null),
        ),
      );

  Future<void> cambiarMinimo(int productoId, int minimo) async {
    if (minimo < 0) throw ArgumentError('Escribe un mínimo válido');
    final producto = await (_db.select(
      _db.productos,
    )..where((p) => p.id.equals(productoId))).getSingle();
    final pedirHasta = producto.pedirHasta;
    if (pedirHasta != null && minimo > pedirHasta) {
      throw ArgumentError('El mínimo no puede ser mayor que "Pedir hasta"');
    }
    await (_db.update(_db.productos)..where((p) => p.id.equals(productoId)))
        .write(ProductosCompanion(minimo: Value(minimo)));
  }

  /// Cambia el mínimo y "pedir hasta" (null lo borra) en una sola escritura;
  /// "pedir hasta" debe ser ≥ mínimo.
  Future<void> cambiarLimites(
    int productoId, {
    required int minimo,
    int? pedirHasta,
  }) async {
    if (minimo < 0) throw ArgumentError('Escribe un mínimo válido');
    if (pedirHasta != null && pedirHasta < minimo) {
      throw ArgumentError('Debe ser mayor o igual que el mínimo');
    }
    await (_db.update(_db.productos)..where((p) => p.id.equals(productoId)))
        .write(
          ProductosCompanion(
            minimo: Value(minimo),
            pedirHasta: Value(pedirHasta),
          ),
        );
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
    await _db
        .into(_db.conteosInventario)
        .insert(
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

  // ---- Entradas de mercancía ----

  /// Registra mercancía de [proveedorId] y actualiza los precios de ese
  /// proveedor en cada producto (o lo agrega). Con [pedidoId] cierra ese
  /// pedido; con [pagadoDeCaja] anota el total como gasto de mercancía.
  /// Devuelve el id de la entrada.
  Future<int> recibirMercancia({
    required int proveedorId,
    required List<LineaRecibida> lineas,
    String? nota,
    required Usuario por,
    int? pedidoId,
    bool pagadoDeCaja = true,
  }) async {
    if (lineas.isEmpty) throw ArgumentError('Agrega al menos un producto');
    if (lineas.any((l) => l.cantidad <= 0 || l.precioCompra <= 0)) {
      throw ArgumentError('Cantidad o precio inválido');
    }
    if (lineas.map((l) => l.productoId).toSet().length != lineas.length) {
      throw ArgumentError('Producto repetido');
    }
    return _db.transaction(() async {
      final proveedor = await (_db.select(
        _db.proveedores,
      )..where((p) => p.id.equals(proveedorId))).getSingleOrNull();
      if (proveedor == null || !proveedor.activo) {
        throw ArgumentError('Proveedor inactivo');
      }
      if (pedidoId != null) {
        final pedido = await (_db.select(
          _db.pedidos,
        )..where((p) => p.id.equals(pedidoId))).getSingleOrNull();
        if (pedido == null ||
            pedido.estado != EstadoPedido.porLlegar ||
            pedido.proveedorId != proveedorId) {
          throw ArgumentError('El pedido ya no está por llegar');
        }
      }
      final limpia = nota?.trim() ?? '';
      final total = lineas.fold(0, (s, l) => s + l.cantidad * l.precioCompra);
      final id = await _db
          .into(_db.entradasMercancia)
          .insert(
            EntradasMercanciaCompanion.insert(
              proveedorId: proveedorId,
              usuarioId: por.id,
              fecha: _reloj(),
              total: total,
              nota: Value(limpia.isEmpty ? null : limpia),
            ),
          );
      for (final l in lineas) {
        await _db
            .into(_db.lineasEntrada)
            .insert(
              LineasEntradaCompanion.insert(
                entradaId: id,
                productoId: l.productoId,
                cantidad: l.cantidad,
                precioCompra: l.precioCompra,
              ),
            );
        final vinculo =
            await (_db.select(_db.productosProveedores)..where(
                  (v) =>
                      v.productoId.equals(l.productoId) &
                      v.proveedorId.equals(proveedorId),
                ))
                .getSingleOrNull();
        if (vinculo != null) {
          if (vinculo.precioCompra != l.precioCompra) {
            await (_db.update(
              _db.productosProveedores,
            )..where((v) => v.id.equals(vinculo.id))).write(
              ProductosProveedoresCompanion(
                precioCompra: Value(l.precioCompra),
              ),
            );
          }
        } else {
          final tienePreferido =
              await (_db.select(_db.productosProveedores)..where(
                    (v) =>
                        v.productoId.equals(l.productoId) &
                        v.preferido.equals(true),
                  ))
                  .get()
                  .then((f) => f.isNotEmpty);
          await _db
              .into(_db.productosProveedores)
              .insert(
                ProductosProveedoresCompanion.insert(
                  productoId: l.productoId,
                  proveedorId: proveedorId,
                  precioCompra: l.precioCompra,
                  preferido: Value(!tienePreferido),
                ),
              );
        }
      }
      if (pedidoId != null) {
        await (_db.update(
          _db.pedidos,
        )..where((p) => p.id.equals(pedidoId))).write(
          PedidosCompanion(
            estado: const Value(EstadoPedido.recibido),
            entradaId: Value(id),
          ),
        );
      }
      if (pagadoDeCaja) {
        await _db
            .into(_db.gastos)
            .insert(
              GastosCompanion.insert(
                monto: total,
                descripcion: Value(
                  aplicarCategoria(proveedor.nombre, 'Mercancía'),
                ),
                fecha: _reloj(),
                usuarioId: por.id,
                entradaId: Value(id),
              ),
            );
      }
      return id;
    });
  }

  /// La entrada deja de sumar existencias; los precios no se revierten. Su
  /// gasto se anula y su pedido vuelve a estar por llegar.
  Future<void> anularEntrada(int entradaId, {required Usuario por}) async {
    await _db.transaction(() async {
      final entrada = await (_db.select(
        _db.entradasMercancia,
      )..where((e) => e.id.equals(entradaId))).getSingle();
      if (entrada.anulada) throw ArgumentError('La entrada ya está anulada');
      final gasto = await _gastoDe(entradaId);
      // Anular la entrada mueve la caja: misma regla que anular un gasto.
      if (gasto != null &&
          !gasto.anulado &&
          !puedeCorregir(
            usuario: por,
            duenoId: entrada.usuarioId,
            fechaMovimiento: entrada.fecha,
            ahora: _reloj(),
          )) {
        throw const PermisoDenegado();
      }
      await (_db.update(
        _db.entradasMercancia,
      )..where((e) => e.id.equals(entradaId))).write(
        EntradasMercanciaCompanion(
          anulada: const Value(true),
          anuladaPorId: Value(por.id),
        ),
      );
      if (gasto != null) {
        await CorreccionRepository(
          _db,
          reloj: _reloj,
        ).anularGastoDeEntrada(gasto.id, por: por);
      }
      await (_db.update(
        _db.pedidos,
      )..where((p) => p.entradaId.equals(entradaId))).write(
        const PedidosCompanion(
          estado: Value(EstadoPedido.porLlegar),
          entradaId: Value(null),
        ),
      );
    });
  }

  Future<Gasto?> _gastoDe(int entradaId) => (_db.select(
    _db.gastos,
  )..where((g) => g.entradaId.equals(entradaId))).getSingleOrNull();

  /// Las [limite] entradas más recientes, con nombres.
  Future<List<EntradaResumen>> entradasRecientes({int limite = 20}) async {
    final filas =
        await (_db.select(_db.entradasMercancia).join([
                innerJoin(
                  _db.proveedores,
                  _db.proveedores.id.equalsExp(
                    _db.entradasMercancia.proveedorId,
                  ),
                ),
                innerJoin(
                  _db.usuarios,
                  _db.usuarios.id.equalsExp(_db.entradasMercancia.usuarioId),
                ),
              ])
              ..orderBy([
                OrderingTerm.desc(_db.entradasMercancia.fecha),
                OrderingTerm.desc(_db.entradasMercancia.id),
              ])
              ..limit(limite))
            .get();
    return [
      for (final f in filas)
        EntradaResumen(
          entrada: f.readTable(_db.entradasMercancia),
          proveedor: f.readTable(_db.proveedores).nombre,
          usuario: f.readTable(_db.usuarios).nombre,
        ),
    ];
  }

  Future<DetalleEntrada> detalleEntrada(int entradaId) async {
    final f = await (_db.select(_db.entradasMercancia).join([
      innerJoin(
        _db.proveedores,
        _db.proveedores.id.equalsExp(_db.entradasMercancia.proveedorId),
      ),
      innerJoin(
        _db.usuarios,
        _db.usuarios.id.equalsExp(_db.entradasMercancia.usuarioId),
      ),
    ])..where(_db.entradasMercancia.id.equals(entradaId))).getSingle();
    final lineas =
        await (_db.select(_db.lineasEntrada).join([
                innerJoin(
                  _db.productos,
                  _db.productos.id.equalsExp(_db.lineasEntrada.productoId),
                ),
              ])
              ..where(_db.lineasEntrada.entradaId.equals(entradaId))
              ..orderBy([OrderingTerm.asc(_db.lineasEntrada.id)]))
            .get();
    final pedido = await (_db.select(
      _db.pedidos,
    )..where((p) => p.entradaId.equals(entradaId))).getSingleOrNull();
    return (
      resumen: EntradaResumen(
        entrada: f.readTable(_db.entradasMercancia),
        proveedor: f.readTable(_db.proveedores).nombre,
        usuario: f.readTable(_db.usuarios).nombre,
      ),
      lineas: [
        for (final l in lineas)
          (
            linea: l.readTable(_db.lineasEntrada),
            producto: l.readTable(_db.productos).nombre,
          ),
      ],
      gasto: await _gastoDe(entradaId),
      lineasPedido: pedido == null
          ? null
          : (await PedidoRepository(_db).detallePedido(pedido.id)).lineas,
    );
  }

  // ---- Listas ----

  /// Productos activos con control, por nombre, con sus existencias.
  Future<List<({Producto producto, int existencias})>>
  productosConControl() async {
    final lista =
        await (_db.select(_db.productos)
              ..where(
                (p) =>
                    p.activo.equals(true) & p.controlaExistencias.equals(true),
              )
              ..orderBy([(p) => OrderingTerm.asc(p.nombre)]))
            .get();
    final existencias = await existenciasDe(lista.map((p) => p.id));
    return [
      for (final p in lista)
        if (existencias[p.id] != null)
          (producto: p, existencias: existencias[p.id]!),
    ];
  }

  /// Productos activos con control y existencias ≤ mínimo, por proveedor
  /// preferido.
  Future<List<GrupoPorPedir>> porPedir() async {
    final faltan = [
      for (final p in await productosConControl())
        if (p.existencias <= p.producto.minimo)
          ProductoPorPedir(producto: p.producto, existencias: p.existencias),
    ];
    final preferidos = {
      for (final v in await (_db.select(
        _db.productosProveedores,
      )..where((v) => v.preferido.equals(true))).get())
        v.productoId: v.proveedorId,
    };
    final proveedores = {
      for (final p in await _db.select(_db.proveedores).get()) p.id: p,
    };
    final grupos = <int?, List<ProductoPorPedir>>{};
    for (final p in faltan) {
      grupos.putIfAbsent(preferidos[p.producto.id], () => []).add(p);
    }
    int orden(ProductoPorPedir a, ProductoPorPedir b) {
      final negA = a.existencias < 0 ? 0 : 1;
      final negB = b.existencias < 0 ? 0 : 1;
      if (negA != negB) return negA - negB;
      final falta = (a.existencias - a.producto.minimo).compareTo(
        b.existencias - b.producto.minimo,
      );
      if (falta != 0) return falta;
      return a.producto.nombre.compareTo(b.producto.nombre);
    }

    final resultado =
        [
          for (final e in grupos.entries)
            GrupoPorPedir(
              proveedor: e.key == null ? null : proveedores[e.key],
              productos: e.value..sort(orden),
            ),
        ]..sort((a, b) {
          if (a.proveedor == null) return 1;
          if (b.proveedor == null) return -1;
          return a.proveedor!.nombre.toLowerCase().compareTo(
            b.proveedor!.nombre.toLowerCase(),
          );
        });
    return resultado;
  }

  /// Conteos y entradas del producto, del más reciente al más viejo.
  Future<List<MovimientoInventario>> historial(
    int productoId, {
    int limite = 30,
  }) async {
    final usuarios = {
      for (final u in await _db.select(_db.usuarios).get()) u.id: u.nombre,
    };
    final conteos = await (_db.select(
      _db.conteosInventario,
    )..where((c) => c.productoId.equals(productoId))).get();
    final entradas = await (_db.select(_db.lineasEntrada).join([
      innerJoin(
        _db.entradasMercancia,
        _db.entradasMercancia.id.equalsExp(_db.lineasEntrada.entradaId),
      ),
      innerJoin(
        _db.proveedores,
        _db.proveedores.id.equalsExp(_db.entradasMercancia.proveedorId),
      ),
    ])..where(_db.lineasEntrada.productoId.equals(productoId))).get();
    final movimientos = [
      for (final c in conteos)
        MovimientoInventario(
          tipo: c.tipo == TipoConteo.inicial
              ? TipoMovimientoInventario.conteoInicial
              : TipoMovimientoInventario.ajuste,
          fecha: c.fecha,
          cantidad: c.cantidad,
          anterior: c.anterior,
          quien: usuarios[c.usuarioId] ?? '',
        ),
      for (final f in entradas)
        MovimientoInventario(
          tipo: TipoMovimientoInventario.entrada,
          fecha: f.readTable(_db.entradasMercancia).fecha,
          cantidad: f.readTable(_db.lineasEntrada).cantidad,
          quien: f.readTable(_db.proveedores).nombre,
          anulada: f.readTable(_db.entradasMercancia).anulada,
        ),
    ]..sort((a, b) => b.fecha.compareTo(a.fecha));
    return movimientos.take(limite).toList();
  }

  // ---- Pedido sugerido ----

  /// Cambia "pedir hasta" (null lo borra); debe ser ≥ 0 y ≥ mínimo.
  Future<void> cambiarPedirHasta(int productoId, int? pedirHasta) async {
    if (pedirHasta != null) {
      final producto = await (_db.select(
        _db.productos,
      )..where((p) => p.id.equals(productoId))).getSingle();
      if (pedirHasta < 0 || pedirHasta < producto.minimo) {
        throw ArgumentError('Debe ser mayor o igual que el mínimo');
      }
    }
    await (_db.update(_db.productos)..where((p) => p.id.equals(productoId)))
        .write(ProductosCompanion(pedirHasta: Value(pedirHasta)));
  }

  /// Pedido sugerido para el grupo de "Por pedir" de [proveedorId] (null =
  /// "Sin proveedor"), en el mismo orden.
  Future<List<LineaSugerida>> sugerenciaPedido(int? proveedorId) async {
    final grupo = (await porPedir())
        .where((g) => g.proveedor?.id == proveedorId)
        .firstOrNull;
    if (grupo == null) return const [];
    final precios = proveedorId == null
        ? const <int, int>{}
        : {
            for (final v in await (_db.select(
              _db.productosProveedores,
            )..where((v) => v.proveedorId.equals(proveedorId))).get())
              v.productoId: v.precioCompra,
          };
    return [
      for (final p in grupo.productos)
        LineaSugerida(
          producto: p.producto,
          existencias: p.existencias,
          sugerido:
              ((p.producto.pedirHasta ?? 2 * p.producto.minimo) - p.existencias)
                  .clamp(1, 1 << 30),
          precio: precios[p.producto.id],
        ),
    ];
  }
}
