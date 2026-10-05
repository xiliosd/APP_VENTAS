import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/repositories/producto_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late ProductoRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ProductoRepository(db);
  });

  tearDown(() => db.close());

  test('crearProducto queda activo por defecto y aparece en observarProductosActivos',
      () async {
    await repo.crearProducto(nombre: 'Arepa', precio: 3000);

    final activos = await repo.observarProductosActivos().first;
    expect(activos, hasLength(1));
    expect(activos.single.nombre, 'Arepa');
    expect(activos.single.precio, 3000);
    expect(activos.single.activo, isTrue);
  });

  test('desactivarProducto lo saca de observarProductosActivos pero sigue en listarTodos',
      () async {
    final id = await repo.crearProducto(nombre: 'Arepa', precio: 3000);
    await repo.desactivarProducto(id);

    expect(await repo.observarProductosActivos().first, isEmpty);
    expect(await repo.listarTodos(), hasLength(1));
  });

  test('actualizarProducto cambia nombre y precio', () async {
    final id = await repo.crearProducto(nombre: 'Arepa', precio: 3000);
    await repo.actualizarProducto(id, nombre: 'Arepa con queso', precio: 4000);

    final producto = (await repo.listarTodos()).single;
    expect(producto.nombre, 'Arepa con queso');
    expect(producto.precio, 4000);
  });

  test('reactivarProducto lo devuelve a activos y lo saca de inactivos',
      () async {
    final id = await repo.crearProducto(nombre: 'Arepa', precio: 3000);
    await repo.desactivarProducto(id);

    expect((await repo.observarProductosInactivos().first).single.id, id);
    expect(await repo.observarProductosActivos().first, isEmpty);

    await repo.reactivarProducto(id);

    expect((await repo.observarProductosActivos().first).single.id, id);
    expect(await repo.observarProductosInactivos().first, isEmpty);
  });
}
