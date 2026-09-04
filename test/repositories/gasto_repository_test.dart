import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/repositories/gasto_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late GastoRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = GastoRepository(db);
  });

  tearDown(() => db.close());

  Future<int> crearUsuario() {
    return db.into(db.usuarios).insert(
          UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'x'),
        );
  }

  test('registrarGasto y gastosDelDia', () async {
    final usuarioId = await crearUsuario();
    await repo.registrarGasto(
      monto: 20000,
      descripcion: 'Bolsas',
      usuarioId: usuarioId,
      fecha: DateTime(2026, 9, 2, 9),
    );

    final gastos = await repo.gastosDelDia(DateTime(2026, 9, 2));
    expect(gastos, hasLength(1));
    expect(gastos.single.monto, 20000);
    expect(gastos.single.descripcion, 'Bolsas');
  });

  test('registrarGasto sin descripción deja el campo nulo', () async {
    final usuarioId = await crearUsuario();
    await repo.registrarGasto(
      monto: 5000,
      usuarioId: usuarioId,
      fecha: DateTime(2026, 9, 2, 9),
    );

    expect((await repo.gastosDelDia(DateTime(2026, 9, 2))).single.descripcion, isNull);
  });
}
