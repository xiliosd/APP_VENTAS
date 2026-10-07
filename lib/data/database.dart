import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'correccion.dart';
import 'medio_pago.dart';

export 'correccion.dart';
export 'medio_pago.dart';

part 'database.g.dart';

@DataClassName('Usuario')
class Usuarios extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get nombre => text()();
  TextColumn get rol => text()(); // 'admin' | 'vendedor'
  TextColumn get pinHash => text()();
}

@DataClassName('Producto')
class Productos extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get nombre => text()();
  IntColumn get precio => integer()(); // COP, entero
  BoolColumn get activo => boolean().withDefault(const Constant(true))();
}

/// A quién se le compran los productos.
@DataClassName('Proveedor')
class Proveedores extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get nombre => text()();
  TextColumn get telefono => text().nullable()();
  TextColumn get notas => text().nullable()();
  BoolColumn get activo => boolean().withDefault(const Constant(true))();
}

/// Un proveedor de un producto y su precio de compra. Un producto con
/// proveedores tiene exactamente un preferido (lo garantiza el repositorio).
@DataClassName('ProductoProveedor')
class ProductosProveedores extends Table {
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

@DataClassName('Cliente')
class Clientes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get nombre => text()();
  TextColumn get telefono => text().nullable()();
  TextColumn get notas => text().nullable()();
}

@DataClassName('Venta')
class Ventas extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get monto => integer()();
  IntColumn get productoId => integer().nullable().references(Productos, #id)();
  DateTimeColumn get fecha => dateTime()();
  BoolColumn get esFiado => boolean().withDefault(const Constant(false))();
  IntColumn get clienteId => integer().nullable().references(Clientes, #id)();
  IntColumn get usuarioId => integer().references(Usuarios, #id)();
  TextColumn get medioPago => textEnum<MedioPago>()
      .withDefault(const Constant('efectivo'))();
  BoolColumn get anulado => boolean().withDefault(const Constant(false))();
}

/// Un producto (o monto suelto) de una venta, tal como estaba al vender.
@DataClassName('LineaVenta')
class LineasVenta extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get ventaId => integer().references(Ventas, #id)();

  /// null = monto suelto ("+ Otro" o monto rápido).
  IntColumn get productoId =>
      integer().nullable().references(Productos, #id)();
  TextColumn get descripcion => text()();
  IntColumn get precioUnitario => integer()();
  IntColumn get cantidad => integer()();

  /// Costo de una unidad al vender (precio del proveedor preferido); null en
  /// montos sueltos, productos sin proveedor o ventas anteriores a la 4A.
  IntColumn get costoUnitario => integer().nullable()();
}

@DataClassName('PagoFiado')
class PagosFiado extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get clienteId => integer().references(Clientes, #id)();
  IntColumn get monto => integer()();
  DateTimeColumn get fecha => dateTime()();
  IntColumn get usuarioId => integer().references(Usuarios, #id)();
  TextColumn get medioPago => textEnum<MedioPago>()
      .withDefault(const Constant('efectivo'))();
  BoolColumn get anulado => boolean().withDefault(const Constant(false))();
}

@DataClassName('Gasto')
class Gastos extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get monto => integer()();
  TextColumn get descripcion => text().nullable()();
  DateTimeColumn get fecha => dateTime()();
  IntColumn get usuarioId => integer().references(Usuarios, #id)();
  BoolColumn get anulado => boolean().withDefault(const Constant(false))();
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

/// Rastro de cada anulación o corrección de un movimiento.
@DataClassName('Correccion')
class Correcciones extends Table {
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
    Clientes,
    Ventas,
    LineasVenta,
    PagosFiado,
    Gastos,
    ConfiguracionTienda,
    Correcciones,
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
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, desde, hasta) async {
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
                  configuracionTienda, configuracionTienda.nombreTienda);
            }
          }
        },
      );

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
