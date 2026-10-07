import 'package:drift/drift.dart';

import '../data/database.dart';

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
      final producto = await (_db.select(
        _db.productos,
      )..where((p) => p.id.equals(id))).getSingleOrNull();
      if (producto == null || !producto.controlaExistencias) continue;
      final conteo = await _ultimoConteo(id);
      if (conteo == null) continue;

      final recibidas =
          await (_db.select(_db.lineasEntrada).join([
                innerJoin(
                  _db.entradasMercancia,
                  _db.entradasMercancia.id.equalsExp(
                    _db.lineasEntrada.entradaId,
                  ),
                ),
              ])..where(
                _db.lineasEntrada.productoId.equals(id) &
                    _db.entradasMercancia.anulada.equals(false) &
                    _db.entradasMercancia.fecha.isBiggerThanValue(conteo.fecha),
              ))
              .get();
      final vendidas =
          await (_db.select(_db.lineasVenta).join([
                innerJoin(
                  _db.ventas,
                  _db.ventas.id.equalsExp(_db.lineasVenta.ventaId),
                ),
              ])..where(
                _db.lineasVenta.productoId.equals(id) &
                    _db.ventas.anulado.equals(false) &
                    _db.ventas.fecha.isBiggerThanValue(conteo.fecha),
              ))
              .get();

      resultado[id] =
          conteo.cantidad +
          recibidas.fold<int>(
            0,
            (s, f) => s + f.readTable(_db.lineasEntrada).cantidad,
          ) -
          vendidas.fold<int>(
            0,
            (s, f) => s + f.readTable(_db.lineasVenta).cantidad,
          );
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

  /// Deja de controlar existencias; el historial se conserva.
  Future<void> desactivarControl(int productoId) =>
      (_db.update(_db.productos)..where((p) => p.id.equals(productoId))).write(
        const ProductosCompanion(controlaExistencias: Value(false)),
      );

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
  /// proveedor en cada producto (o lo agrega). Devuelve el id de la entrada.
  Future<int> recibirMercancia({
    required int proveedorId,
    required List<LineaRecibida> lineas,
    String? nota,
    required Usuario por,
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
      final limpia = nota?.trim() ?? '';
      final id = await _db
          .into(_db.entradasMercancia)
          .insert(
            EntradasMercanciaCompanion.insert(
              proveedorId: proveedorId,
              usuarioId: por.id,
              fecha: _reloj(),
              total: lineas.fold(0, (s, l) => s + l.cantidad * l.precioCompra),
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
      return id;
    });
  }

  /// La entrada deja de sumar existencias; los precios no se revierten.
  Future<void> anularEntrada(int entradaId, {required Usuario por}) async {
    await _db.transaction(() async {
      final entrada = await (_db.select(
        _db.entradasMercancia,
      )..where((e) => e.id.equals(entradaId))).getSingle();
      if (entrada.anulada) throw ArgumentError('La entrada ya está anulada');
      await (_db.update(
        _db.entradasMercancia,
      )..where((e) => e.id.equals(entradaId))).write(
        EntradasMercanciaCompanion(
          anulada: const Value(true),
          anuladaPorId: Value(por.id),
        ),
      );
    });
  }

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

  /// Una entrada con sus líneas y el nombre de cada producto.
  Future<
    ({
      EntradaResumen resumen,
      List<({LineaEntrada linea, String producto})> lineas,
    })
  >
  detalleEntrada(int entradaId) async {
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
}
