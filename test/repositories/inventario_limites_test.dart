import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/repositories/inventario_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late InventarioRepository repo;
  late int arepa;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = InventarioRepository(db, reloj: () => DateTime(2026, 10, 8, 8));
    final id = await db.into(db.usuarios).insert(
        UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'x'));
    final ana = await (db.select(db.usuarios)..where((u) => u.id.equals(id)))
        .getSingle();
    arepa = await db
        .into(db.productos)
        .insert(ProductosCompanion.insert(nombre: 'Arepa', precio: 3000));
    await repo.activarControl(arepa, cantidad: 10, minimo: 5, por: ana);
    await repo.cambiarPedirHasta(arepa, 8);
  });
  tearDown(() => db.close());

  Future<(int, int?)> limites() async {
    final p = await (db.select(db.productos)..where((p) => p.id.equals(arepa)))
        .getSingle();
    return (p.minimo, p.pedirHasta);
  }

  test('cambiarMinimo no pasa de "Pedir hasta"', () async {
    await expectLater(repo.cambiarMinimo(arepa, 9), throwsArgumentError);
    expect(await limites(), (5, 8));
  });

  test('cambiarLimites sube o baja los dos a la vez', () async {
    await repo.cambiarLimites(arepa, minimo: 10, pedirHasta: 20);
    expect(await limites(), (10, 20));
    await repo.cambiarLimites(arepa, minimo: 2, pedirHasta: 3);
    expect(await limites(), (2, 3));
    await repo.cambiarLimites(arepa, minimo: 4, pedirHasta: null);
    expect(await limites(), (4, null));
  });

  test('cambiarLimites rechaza "Pedir hasta" menor que el mínimo', () async {
    await expectLater(repo.cambiarLimites(arepa, minimo: 6, pedirHasta: 5),
        throwsArgumentError);
    await expectLater(
        repo.cambiarLimites(arepa, minimo: -1), throwsArgumentError);
    expect(await limites(), (5, 8));
  });

  test('dejar de controlar borra "Pedir hasta"', () async {
    await repo.desactivarControl(arepa);
    final p = await (db.select(db.productos)..where((p) => p.id.equals(arepa)))
        .getSingle();
    expect((p.controlaExistencias, p.pedirHasta), (false, null));
  });
}
