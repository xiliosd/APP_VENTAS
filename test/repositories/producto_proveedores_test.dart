import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/repositories/producto_repository.dart';
import 'package:app_ventas/repositories/proveedor_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late ProductoRepository repo;
  late ProveedorRepository proveedores;
  late int postobon;
  late int alpina;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = ProductoRepository(db);
    proveedores = ProveedorRepository(db);
    postobon = await proveedores.crear(nombre: 'Postobón');
    alpina = await proveedores.crear(nombre: 'Alpina');
  });

  tearDown(() => db.close());

  ProveedorDeProducto de(int id, int precio, {bool preferido = false}) =>
      ProveedorDeProducto(
          proveedorId: id, precioCompra: precio, preferido: preferido);

  test('guarda un producto nuevo con sus proveedores y su costo', () async {
    final id = await repo.guardarProducto(
      nombre: 'Coca',
      precio: 1200,
      proveedores: [de(postobon, 900, preferido: true), de(alpina, 850)],
    );

    final lista = await repo.proveedoresDe(id);
    expect(lista.map((p) => (p.proveedorId, p.precioCompra, p.preferido)),
        [(postobon, 900, true), (alpina, 850, false)]);
    expect(await repo.costoDe(id), 900);
    expect(await repo.costos(), {id: 900});
  });

  test('editar reemplaza nombre, precio y proveedores', () async {
    final id = await repo.guardarProducto(
        nombre: 'Coca', precio: 1200, proveedores: [de(postobon, 900, preferido: true)]);

    await repo.guardarProducto(
      id: id,
      nombre: 'Coca 400',
      precio: 1300,
      proveedores: [de(alpina, 850, preferido: true)],
    );

    final producto = await (db.select(db.productos)
          ..where((p) => p.id.equals(id)))
        .getSingle();
    expect(producto.nombre, 'Coca 400');
    expect(producto.precio, 1300);
    expect((await repo.proveedoresDe(id)).single.proveedorId, alpina);
    expect(await repo.costoDe(id), 850);
  });

  test('sin proveedores no hay costo', () async {
    final id = await repo.guardarProducto(nombre: 'Pan', precio: 500);
    expect(await repo.costoDe(id), isNull);
    expect(await repo.costos(), isEmpty);
  });

  test('listas inválidas se rechazan sin guardar nada', () async {
    final invalidas = [
      [de(postobon, 900), de(alpina, 850)], // sin preferido
      [de(postobon, 900, preferido: true), de(alpina, 850, preferido: true)],
      [de(postobon, 0, preferido: true)],
      [de(postobon, 900, preferido: true), de(postobon, 800)],
    ];
    for (final lista in invalidas) {
      await expectLater(
          repo.guardarProducto(nombre: 'Coca', precio: 1200, proveedores: lista),
          throwsArgumentError);
    }
    await expectLater(
        repo.guardarProducto(nombre: ' ', precio: 1200), throwsArgumentError);
    await expectLater(
        repo.guardarProducto(nombre: 'Coca', precio: 0), throwsArgumentError);
    expect(await db.select(db.productos).get(), isEmpty);
    expect(await db.select(db.productosProveedores).get(), isEmpty);
  });

  test('un proveedor inactivo no se agrega a un producto nuevo', () async {
    await proveedores.desactivar(alpina);
    await expectLater(
        repo.guardarProducto(
            nombre: 'Avena',
            precio: 2000,
            proveedores: [de(alpina, 1500, preferido: true)]),
        throwsArgumentError);
    expect(await db.select(db.productos).get(), isEmpty);
  });

  test('un proveedor que se desactivó después se conserva al editar',
      () async {
    final id = await repo.guardarProducto(
        nombre: 'Avena',
        precio: 2000,
        proveedores: [de(alpina, 1500, preferido: true)]);
    await proveedores.desactivar(alpina);

    await repo.guardarProducto(
        id: id,
        nombre: 'Avena grande',
        precio: 2200,
        proveedores: [de(alpina, 1600, preferido: true)]);

    expect(await repo.costoDe(id), 1600);
  });

  test('si falla al editar no cambia nada', () async {
    final id = await repo.guardarProducto(
        nombre: 'Coca', precio: 1200, proveedores: [de(postobon, 900, preferido: true)]);
    await proveedores.desactivar(alpina);

    await expectLater(
        repo.guardarProducto(
            id: id,
            nombre: 'Coca nueva',
            precio: 1500,
            proveedores: [
              de(postobon, 900, preferido: true),
              de(alpina, 850),
            ]),
        throwsArgumentError);

    final producto = await (db.select(db.productos)
          ..where((p) => p.id.equals(id)))
        .getSingle();
    expect(producto.nombre, 'Coca');
    expect(await repo.proveedoresDe(id), hasLength(1));
  });
}
