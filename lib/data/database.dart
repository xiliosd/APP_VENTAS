import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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
}

@DataClassName('PagoFiado')
class PagosFiado extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get clienteId => integer().references(Clientes, #id)();
  IntColumn get monto => integer()();
  DateTimeColumn get fecha => dateTime()();
  IntColumn get usuarioId => integer().references(Usuarios, #id)();
}

@DataClassName('Gasto')
class Gastos extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get monto => integer()();
  TextColumn get descripcion => text().nullable()();
  DateTimeColumn get fecha => dateTime()();
  IntColumn get usuarioId => integer().references(Usuarios, #id)();
}

@DriftDatabase(
  tables: [Usuarios, Productos, Clientes, Ventas, PagosFiado, Gastos],
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
  int get schemaVersion => 1;

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
