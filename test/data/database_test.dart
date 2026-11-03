import 'package:app_ventas/data/database.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('creates tables and can insert/read a usuario', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final id = await db
        .into(db.usuarios)
        .insert(
          UsuariosCompanion.insert(
            nombre: 'Admin',
            rol: 'admin',
            pinHash: 'hash',
          ),
        );

    final usuarios = await db.select(db.usuarios).get();
    expect(usuarios, hasLength(1));
    expect(usuarios.single.id, id);
    expect(usuarios.single.nombre, 'Admin');
  });

  group('id global', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('cada fila nueva recibe un id global distinto', () async {
      final usuario = await db
          .into(db.usuarios)
          .insert(
            UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'x'),
          );
      for (var i = 0; i < 3; i++) {
        await db
            .into(db.ventas)
            .insert(
              VentasCompanion.insert(
                monto: 1000,
                fecha: DateTime(2026, 11, 3),
                usuarioId: usuario,
              ),
            );
      }

      final ids = (await db.select(db.ventas).get())
          .map((v) => v.idGlobal)
          .toSet();
      expect(ids.length, 3);
      expect(ids.every((id) => id.length == 36), isTrue);
    });

    test('editar una fila no cambia su id global', () async {
      final id = await db
          .into(db.clientes)
          .insert(ClientesCompanion.insert(nombre: 'Don Pedro'));
      final antes = (await db.select(db.clientes).getSingle()).idGlobal;

      await (db.update(db.clientes)..where((c) => c.id.equals(id))).write(
        const ClientesCompanion(telefono: Value('300')),
      );

      final despues = await db.select(db.clientes).getSingle();
      expect(despues.telefono, '300');
      expect(despues.idGlobal, antes);
    });

    test('dos filas no pueden tener el mismo id global', () async {
      await db
          .into(db.clientes)
          .insert(
            ClientesCompanion.insert(
              nombre: 'Uno',
              idGlobal: const Value('fijo'),
            ),
          );

      expect(
        db
            .into(db.clientes)
            .insert(
              ClientesCompanion.insert(
                nombre: 'Dos',
                idGlobal: const Value('fijo'),
              ),
            ),
        throwsA(isA<SqliteException>()),
      );
    });

    test('la base está en la versión 12', () {
      expect(db.schemaVersion, 12);
    });
  });

  test('cerrar la base dos veces solo la cierra una vez', () async {
    final contador = _ContadorCierres();
    final db = AppDatabase(NativeDatabase.memory().interceptWith(contador));
    await db.customSelect('SELECT 1').get();

    await db.close();
    await db.close();

    expect(contador.cierres, 1);
  });
}

class _ContadorCierres extends QueryInterceptor {
  int cierres = 0;

  @override
  Future<void> close(QueryExecutor inner) {
    cierres++;
    return inner.close();
  }
}
