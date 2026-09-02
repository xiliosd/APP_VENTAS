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
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return LazyDatabase(() async {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, 'app_ventas.sqlite'));
      return NativeDatabase.createInBackground(file);
    });
  }
}
