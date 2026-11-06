import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../util/id_global.dart';
import 'correccion.dart';
import 'disparadores_sincronizacion.dart';
import 'inventario.dart';
import 'medio_pago.dart';

export 'correccion.dart';
export 'disparadores_sincronizacion.dart';
export 'inventario.dart';
export 'medio_pago.dart';

part 'database.g.dart';

/// Tablas (nombre SQL) cuyas filas se sincronizarán entre los celulares de una
/// tienda compartida; todas llevan `id_global`. `configuracion_tienda` no:
/// tiene una sola fila y en la nube se identifica por la tienda.
const tablasConIdGlobal = <String>[
  'usuarios',
  'productos',
  'proveedores',
  'productos_proveedores',
  'conteos_inventario',
  'entradas_mercancia',
  'lineas_entrada',
  'pedidos',
  'lineas_pedido',
  'clientes',
  'ventas',
  'lineas_venta',
  'pagos_fiado',
  'gastos',
  'correcciones',
];

/// El `id` entero sigue siendo local de cada celular (y el que usan las llaves
/// foráneas); `idGlobal` es el que todos los celulares de una tienda
/// compartida reconocen como el mismo registro. Se genera solo al insertar.
mixin ConIdGlobal on Table {
  TextColumn get idGlobal => text().clientDefault(generarIdGlobal)();
}

@DataClassName('Usuario')
@TableIndex(name: 'usuarios_id_global', columns: {#idGlobal}, unique: true)
class Usuarios extends Table with ConIdGlobal {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get nombre => text()();
  TextColumn get rol => text()(); // 'admin' | 'vendedor'
  /// Vacío en un celular al que el usuario llegó desde la nube y aún no entró:
  /// el PIN no viaja en la tienda compartida, se revisa en línea la primera
  /// vez y luego se guarda aquí.
  TextColumn get pinHash => text()();

  /// Un vendedor desactivado no aparece en "¿Quién eres?" ni puede entrar.
  BoolColumn get activo => boolean().withDefault(const Constant(true))();

  /// Lo que el vendedor escribe para unirse desde su celular; solo vendedores.
  IntColumn get numeroVendedor => integer().nullable()();

  /// Sube cada vez que se cambia el PIN: otro celular con una versión menor
  /// sabe que su PIN guardado ya no sirve.
  IntColumn get versionPin => integer().withDefault(const Constant(0))();
}

@DataClassName('Producto')
@TableIndex(name: 'productos_id_global', columns: {#idGlobal}, unique: true)
class Productos extends Table with ConIdGlobal {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get nombre => text()();
  IntColumn get precio => integer()(); // COP, entero
  BoolColumn get activo => boolean().withDefault(const Constant(true))();

  /// Lleva conteo de existencias (Fase 4B).
  BoolColumn get controlaExistencias =>
      boolean().withDefault(const Constant(false))();

  /// Con existencias en este número o menos, el producto pasa a "Por pedir".
  IntColumn get minimo => integer().withDefault(const Constant(0))();

  /// Cuántas quiere tener después de pedir; sugiere la cantidad del pedido.
  IntColumn get pedirHasta => integer().nullable()();

  /// Código de barras (Fase código de barras). Único entre los activos; lo
  /// valida el repositorio para que un inactivo pueda conservar el suyo.
  TextColumn get codigoBarras => text().nullable()();
  TextColumn get marca => text().nullable()();

  /// Libre: "1,5 L", "400 ml", "500 g".
  TextColumn get tamano => text().nullable()();

  /// Claves de `lib/util/catalogo_producto.dart`.
  TextColumn get envase => text().nullable()();
  TextColumn get tipo => text().nullable()();
}

/// A quién se le compran los productos.
@DataClassName('Proveedor')
@TableIndex(name: 'proveedores_id_global', columns: {#idGlobal}, unique: true)
class Proveedores extends Table with ConIdGlobal {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get nombre => text()();
  TextColumn get telefono => text().nullable()();
  TextColumn get notas => text().nullable()();
  BoolColumn get activo => boolean().withDefault(const Constant(true))();
}

/// Un proveedor de un producto y su precio de compra. Un producto con
/// proveedores tiene exactamente un preferido (lo garantiza el repositorio).
@DataClassName('ProductoProveedor')
@TableIndex(
  name: 'productos_proveedores_id_global',
  columns: {#idGlobal},
  unique: true,
)
class ProductosProveedores extends Table with ConIdGlobal {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get productoId => integer().references(Productos, #id)();
  IntColumn get proveedorId => integer().references(Proveedores, #id)();
  IntColumn get precioCompra => integer()();
  BoolColumn get preferido => boolean().withDefault(const Constant(false))();

  @override
  List<Set<Column>> get uniqueKeys => [
    {productoId, proveedorId},
  ];
}

/// Cuántas unidades de un producto se contaron y cuándo.
@DataClassName('ConteoInventario')
@TableIndex(
  name: 'conteos_inventario_id_global',
  columns: {#idGlobal},
  unique: true,
)
class ConteosInventario extends Table with ConIdGlobal {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get productoId => integer().references(Productos, #id)();
  IntColumn get cantidad => integer()();

  /// Existencias según la app al contar; null en el conteo inicial.
  IntColumn get anterior => integer().nullable()();
  TextColumn get tipo => textEnum<TipoConteo>()();
  TextColumn get nota => text().nullable()();
  IntColumn get usuarioId => integer().references(Usuarios, #id)();
  DateTimeColumn get fecha => dateTime()();
}

/// Mercancía recibida de un proveedor.
@DataClassName('EntradaMercancia')
@TableIndex(
  name: 'entradas_mercancia_id_global',
  columns: {#idGlobal},
  unique: true,
)
class EntradasMercancia extends Table with ConIdGlobal {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get proveedorId => integer().references(Proveedores, #id)();
  IntColumn get usuarioId => integer().references(Usuarios, #id)();
  DateTimeColumn get fecha => dateTime()();
  IntColumn get total => integer()();
  TextColumn get nota => text().nullable()();
  BoolColumn get anulada => boolean().withDefault(const Constant(false))();
  IntColumn get anuladaPorId =>
      integer().nullable().references(Usuarios, #id)();
}

/// Un producto de una entrada de mercancía.
@DataClassName('LineaEntrada')
@TableIndex(
  name: 'lineas_entrada_id_global',
  columns: {#idGlobal},
  unique: true,
)
class LineasEntrada extends Table with ConIdGlobal {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get entradaId => integer().references(EntradasMercancia, #id)();
  IntColumn get productoId => integer().references(Productos, #id)();
  IntColumn get cantidad => integer()();
  IntColumn get precioCompra => integer()();
}

/// Pedido hecho a un proveedor desde el pedido sugerido; la mercancía llega
/// días después.
@DataClassName('Pedido')
@TableIndex(name: 'pedidos_id_global', columns: {#idGlobal}, unique: true)
class Pedidos extends Table with ConIdGlobal {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get proveedorId => integer().references(Proveedores, #id)();
  IntColumn get usuarioId => integer().references(Usuarios, #id)();
  DateTimeColumn get fecha => dateTime()();
  TextColumn get estado => textEnum<EstadoPedido>().withDefault(
    Constant(EstadoPedido.porLlegar.name),
  )();

  /// La entrada con la que se recibió; null mientras no llega.
  IntColumn get entradaId =>
      integer().nullable().references(EntradasMercancia, #id)();
}

/// Un producto de un pedido, con el precio que se esperaba pagar.
@DataClassName('LineaPedido')
@TableIndex(name: 'lineas_pedido_id_global', columns: {#idGlobal}, unique: true)
class LineasPedido extends Table with ConIdGlobal {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get pedidoId => integer().references(Pedidos, #id)();
  IntColumn get productoId => integer().references(Productos, #id)();
  IntColumn get cantidad => integer()();
  IntColumn get precioEsperado => integer().nullable()();
}

@DataClassName('Cliente')
@TableIndex(name: 'clientes_id_global', columns: {#idGlobal}, unique: true)
class Clientes extends Table with ConIdGlobal {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get nombre => text()();

  /// Opcional: los clientes anteriores a la versión 10 no lo tienen.
  TextColumn get apellido => text().nullable()();
  TextColumn get telefono => text().nullable()();
  TextColumn get notas => text().nullable()();
}

@DataClassName('Venta')
@TableIndex(name: 'ventas_id_global', columns: {#idGlobal}, unique: true)
class Ventas extends Table with ConIdGlobal {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get monto => integer()();
  IntColumn get productoId => integer().nullable().references(Productos, #id)();
  DateTimeColumn get fecha => dateTime()();
  BoolColumn get esFiado => boolean().withDefault(const Constant(false))();
  IntColumn get clienteId => integer().nullable().references(Clientes, #id)();
  IntColumn get usuarioId => integer().references(Usuarios, #id)();
  TextColumn get medioPago =>
      textEnum<MedioPago>().withDefault(const Constant('efectivo'))();
  BoolColumn get anulado => boolean().withDefault(const Constant(false))();
}

/// Un producto (o monto suelto) de una venta, tal como estaba al vender.
@DataClassName('LineaVenta')
@TableIndex(name: 'lineas_venta_id_global', columns: {#idGlobal}, unique: true)
class LineasVenta extends Table with ConIdGlobal {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get ventaId => integer().references(Ventas, #id)();

  /// null = monto suelto ("+ Otro" o monto rápido).
  IntColumn get productoId => integer().nullable().references(Productos, #id)();
  TextColumn get descripcion => text()();
  IntColumn get precioUnitario => integer()();
  IntColumn get cantidad => integer()();

  /// Costo de una unidad al vender (precio del proveedor preferido); null en
  /// montos sueltos, productos sin proveedor o ventas anteriores a la 4A.
  IntColumn get costoUnitario => integer().nullable()();
}

@DataClassName('PagoFiado')
@TableIndex(name: 'pagos_fiado_id_global', columns: {#idGlobal}, unique: true)
class PagosFiado extends Table with ConIdGlobal {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get clienteId => integer().references(Clientes, #id)();
  IntColumn get monto => integer()();
  DateTimeColumn get fecha => dateTime()();
  IntColumn get usuarioId => integer().references(Usuarios, #id)();
  TextColumn get medioPago =>
      textEnum<MedioPago>().withDefault(const Constant('efectivo'))();
  BoolColumn get anulado => boolean().withDefault(const Constant(false))();
}

@DataClassName('Gasto')
@TableIndex(name: 'gastos_id_global', columns: {#idGlobal}, unique: true)
class Gastos extends Table with ConIdGlobal {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get monto => integer()();
  TextColumn get descripcion => text().nullable()();
  DateTimeColumn get fecha => dateTime()();
  IntColumn get usuarioId => integer().references(Usuarios, #id)();
  BoolColumn get anulado => boolean().withDefault(const Constant(false))();

  /// La mercancía recibida que lo generó; esos gastos solo cambian anulando
  /// la entrada.
  IntColumn get entradaId =>
      integer().nullable().references(EntradasMercancia, #id)();
}

/// Configuración de la tienda: una sola fila (id 1).
@DataClassName('ConfiguracionTiendaFila')
class ConfiguracionTienda extends Table {
  IntColumn get id => integer()();
  BlobColumn get imagenQr => blob().nullable()();

  /// Nombre de la tienda; null mientras no se ha configurado.
  TextColumn get nombreTienda => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Un registro que cambió en este celular y aún no se sube a la tienda
/// compartida. Lo llenan los disparadores de `disparadores_sincronizacion.dart`.
@DataClassName('CambioPendiente')
class CambiosPendientes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get tabla => text()();
  TextColumn get idGlobal => text()();
  BoolColumn get borrado => boolean()();

  /// Sube con cada nuevo cambio del mismo registro: al confirmar una subida
  /// solo se borra la anotación si nadie la cambió mientras tanto.
  IntColumn get cambio => integer().withDefault(const Constant(1))();

  @override
  List<Set<Column>> get uniqueKeys => [
    {tabla, idGlobal},
  ];
}

/// Estado de la tienda compartida en este celular: una sola fila (id 1) que
/// solo existe cuando la tienda es compartida.
@DataClassName('EstadoSincronizacionFila')
class EstadoSincronizacion extends Table {
  IntColumn get id => integer()();
  TextColumn get tiendaId => text()();

  /// Última versión de la nube ya aplicada en este celular.
  IntColumn get cursor => integer().withDefault(const Constant(0))();

  /// Mientras se aplican cambios bajados, los disparadores no anotan nada.
  BoolColumn get aplicando => boolean().withDefault(const Constant(false))();
  DateTimeColumn get ultimaSincronizacion => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Rastro de cada anulación o corrección de un movimiento.
@DataClassName('Correccion')
@TableIndex(name: 'correcciones_id_global', columns: {#idGlobal}, unique: true)
class Correcciones extends Table with ConIdGlobal {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get tipoMovimiento => textEnum<TipoMovimiento>()();

  /// Id en `ventas`, `pagos_fiado` o `gastos` según [tipoMovimiento]; sin
  /// llave foránea porque apunta a tres tablas.
  IntColumn get movimientoId => integer()();
  TextColumn get accion => textEnum<AccionCorreccion>()();
  IntColumn get usuarioId => integer().references(Usuarios, #id)();
  DateTimeColumn get fecha => dateTime()();

  /// Cómo estaba el movimiento justo antes del cambio, ya formateado.
  TextColumn get antes => text()();
}

@DriftDatabase(
  tables: [
    Usuarios,
    Productos,
    Proveedores,
    ProductosProveedores,
    ConteosInventario,
    EntradasMercancia,
    LineasEntrada,
    Pedidos,
    LineasPedido,
    Clientes,
    Ventas,
    LineasVenta,
    PagosFiado,
    Gastos,
    ConfiguracionTienda,
    Correcciones,
    CambiosPendientes,
    EstadoSincronizacion,
  ],
)
class AppDatabase extends _$AppDatabase {
  // Only an explicitly-injected executor (as used in tests, e.g.
  // `AppDatabase(NativeDatabase.memory())`) is wrapped with
  // `closeStreamsSynchronously: true` below. The production path
  // (`_openConnection()`) is left untouched, since only `flutter_test`'s
  // FakeAsync zone has the debounce-Timer problem that fix addresses.
  AppDatabase([QueryExecutor? executor])
    : super(executor != null ? _wrapConnection(executor) : _openConnection());

  @override
  int get schemaVersion => 13;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _crearDisparadores();
    },
    // Drift no envuelve la migración en una transacción: sin esto, un celular
    // que se apaga a mitad deja pasos aplicados con la versión vieja, y al
    // reabrir el mismo paso falla ("columna repetida") y la tienda no abre.
    // La versión se fija dentro de la transacción para que todo quede junto.
    onUpgrade: (m, desde, hasta) => transaction(() async {
      await _migrar(m, desde);
      await customStatement('PRAGMA user_version = $hasta');
    }),
  );

  Future<void> _migrar(Migrator m, int desde) async {
    if (desde < 2) {
      await m.addColumn(ventas, ventas.medioPago);
      await m.addColumn(pagosFiado, pagosFiado.medioPago);
      await m.createTable(configuracionTienda);
    }
    if (desde < 3) {
      await m.addColumn(ventas, ventas.anulado);
      await m.addColumn(pagosFiado, pagosFiado.anulado);
      await m.addColumn(gastos, gastos.anulado);
      await m.createTable(correcciones);
    }
    if (desde < 4) {
      await m.createTable(lineasVenta);
    }
    if (desde < 5) {
      await m.createTable(proveedores);
      await m.createTable(productosProveedores);
      // Si la tabla se creó en esta misma migración ya trae la columna.
      if (desde >= 4) {
        await m.addColumn(lineasVenta, lineasVenta.costoUnitario);
      }
      if (desde >= 2) {
        await m.addColumn(
          configuracionTienda,
          configuracionTienda.nombreTienda,
        );
      }
    }
    if (desde < 6) {
      await m.addColumn(productos, productos.controlaExistencias);
      await m.addColumn(productos, productos.minimo);
      await m.createTable(conteosInventario);
      await m.createTable(entradasMercancia);
      await m.createTable(lineasEntrada);
    }
    if (desde < 7) {
      await m.addColumn(productos, productos.pedirHasta);
    }
    if (desde < 8) {
      await m.addColumn(productos, productos.codigoBarras);
      await m.addColumn(productos, productos.marca);
      await m.addColumn(productos, productos.tamano);
      await m.addColumn(productos, productos.envase);
      await m.addColumn(productos, productos.tipo);
    }
    if (desde < 9) {
      await m.createTable(pedidos);
      await m.createTable(lineasPedido);
      await m.addColumn(gastos, gastos.entradaId);
    }
    if (desde < 10) {
      await m.addColumn(clientes, clientes.apellido);
    }
    if (desde < 11) {
      await _llenarIdsGlobales(m);
    }
    if (desde < 12) {
      await m.createTable(cambiosPendientes);
      await m.createTable(estadoSincronizacion);
      await _crearDisparadores();
    }
    if (desde < 13) {
      await m.addColumn(usuarios, usuarios.activo);
      await m.addColumn(usuarios, usuarios.numeroVendedor);
      await m.addColumn(usuarios, usuarios.versionPin);
    }
  }

  Future<void> _crearDisparadores() async {
    for (final sentencia in sentenciasDisparadores(tablasConIdGlobal)) {
      await customStatement(sentencia);
    }
  }

  /// Agrega `id_global` a las tablas de una base anterior a la v11 y le da a
  /// cada fila uno propio. Corre dentro de la transacción de la migración.
  Future<void> _llenarIdsGlobales(Migrator m) async {
    for (final tabla in tablasConIdGlobal) {
      final columnas = await customSelect("PRAGMA table_info('$tabla')").get();
      // Las tablas creadas en esta misma migración ya traen la columna.
      if (!columnas.any((c) => c.read<String>('name') == 'id_global')) {
        // SQLite no deja agregar una columna NOT NULL sin valor por defecto;
        // el '' solo dura hasta llenar cada fila abajo.
        await customStatement(
          "ALTER TABLE $tabla ADD COLUMN id_global TEXT NOT NULL DEFAULT ''",
        );
      }
      final filas = await customSelect(
        "SELECT id FROM $tabla WHERE id_global = ''",
      ).get();
      for (final fila in filas) {
        await customStatement('UPDATE $tabla SET id_global = ? WHERE id = ?', [
          generarIdGlobal(),
          fila.read<int>('id'),
        ]);
      }
      await customStatement(
        'CREATE UNIQUE INDEX IF NOT EXISTS ${tabla}_id_global '
        'ON $tabla (id_global)',
      );
    }
  }

  static QueryExecutor _openConnection() {
    return LazyDatabase(() async {
      return NativeDatabase.createInBackground(await archivoBaseDatos());
    });
  }

  bool _cerrada = false;

  /// Cerrar dos veces no hace nada la segunda vez: al restaurar un respaldo
  /// la base se cierra antes de reemplazar el archivo, y otra vez cuando se
  /// invalida `databaseProvider`.
  @override
  Future<void> close() async {
    if (_cerrada) return;
    _cerrada = true;
    await super.close();
  }

  // Closes query streams synchronously instead of debouncing them with a
  // Timer. Without this, widget tests that use `observarProductosActivos()`
  // (or any other watch stream) fail with "A Timer is still pending even
  // after the widget tree was disposed" once the widget tree is torn down,
  // because flutter_test runs widget tests inside a FakeAsync zone that
  // never elapses drift's debounce timer on its own. See drift's own
  // `DatabaseConnection` docs for `closeStreamsSynchronously`.
  static QueryExecutor _wrapConnection(QueryExecutor executor) {
    if (executor is DatabaseConnection) return executor;
    return DatabaseConnection(executor, closeStreamsSynchronously: true);
  }
}

/// Archivo SQLite de la app en el celular.
Future<File> archivoBaseDatos() async {
  final carpeta = await getApplicationDocumentsDirectory();
  return File(p.join(carpeta.path, 'app_ventas.sqlite'));
}
