import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/repositories/proveedor_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late ProveedorRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ProveedorRepository(db);
  });
  tearDown(() => db.close());

  test('crear rechaza un nombre repetido sin importar mayúsculas ni espacios',
      () async {
    await repo.crear(nombre: 'Postobón');
    await expectLater(
      repo.crear(nombre: '  postobón '),
      throwsA(isA<ArgumentError>().having(
          (e) => e.message, 'message', 'Ya existe un proveedor con ese nombre')),
    );
    expect(await repo.todos(), hasLength(1));
  });

  test('cuenta también los inactivos', () async {
    final id = await repo.crear(nombre: 'Alpina');
    await repo.desactivar(id);
    await expectLater(repo.crear(nombre: 'ALPINA'), throwsArgumentError);
    expect((await repo.buscarPorNombre('alpina  '))?.id, id);
  });

  test('actualizar permite su propio nombre pero no el de otro', () async {
    final a = await repo.crear(nombre: 'Alpina');
    await repo.crear(nombre: 'Postobón');
    await repo.actualizar(a, nombre: 'alpina');
    await expectLater(
        repo.actualizar(a, nombre: 'Postobón'), throwsArgumentError);
  });

  test('buscarPorNombre colapsa espacios internos', () async {
    final id = await repo.crear(nombre: 'Don  Juan');
    expect((await repo.buscarPorNombre('don juan'))?.id, id);
    expect(await repo.buscarPorNombre('Otro'), isNull);
  });
}
