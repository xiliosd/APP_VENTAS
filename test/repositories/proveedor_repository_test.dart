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

  Future<Proveedor> proveedor(int id) =>
      (db.select(db.proveedores)..where((p) => p.id.equals(id))).getSingle();

  test('crear recorta y guarda vacíos como null', () async {
    final id = await repo.crear(nombre: '  Postobón ', telefono: ' ', notas: '');
    final p = await proveedor(id);
    expect(p.nombre, 'Postobón');
    expect(p.telefono, isNull);
    expect(p.notas, isNull);
    expect(p.activo, isTrue);
  });

  test('un nombre vacío se rechaza', () async {
    await expectLater(repo.crear(nombre: '  '), throwsArgumentError);
    expect(await db.select(db.proveedores).get(), isEmpty);
  });

  test('actualizar cambia los datos', () async {
    final id = await repo.crear(nombre: 'Postobón');
    await repo.actualizar(id,
        nombre: 'Postobón S.A.', telefono: '3001234567', notas: 'Martes');
    final p = await proveedor(id);
    expect(p.nombre, 'Postobón S.A.');
    expect(p.telefono, '3001234567');
    expect(p.notas, 'Martes');
  });

  test('desactivar y reactivar mueven entre las listas', () async {
    final id = await repo.crear(nombre: 'Postobón');
    await repo.crear(nombre: 'Alpina');

    await repo.desactivar(id);
    expect((await repo.observarActivos().first).map((p) => p.nombre),
        ['Alpina']);
    expect((await repo.observarInactivos().first).single.id, id);

    await repo.reactivar(id);
    expect((await repo.observarActivos().first).map((p) => p.nombre),
        ['Alpina', 'Postobón']);
    expect(await repo.todos(), hasLength(2));
  });

  test('cuenta y lista los productos de cada proveedor', () async {
    final postobon = await repo.crear(nombre: 'Postobón');
    final alpina = await repo.crear(nombre: 'Alpina');
    final coca = await db
        .into(db.productos)
        .insert(ProductosCompanion.insert(nombre: 'Coca', precio: 1200));
    final avena = await db
        .into(db.productos)
        .insert(ProductosCompanion.insert(nombre: 'Avena', precio: 2000));
    await db.into(db.productosProveedores).insert(
        ProductosProveedoresCompanion.insert(
            productoId: coca, proveedorId: postobon, precioCompra: 900));
    await db.into(db.productosProveedores).insert(
        ProductosProveedoresCompanion.insert(
            productoId: avena, proveedorId: postobon, precioCompra: 1500));

    expect(await repo.cantidadProductos(), {postobon: 2});
    expect(await repo.cantidadProductos().then((m) => m[alpina]), isNull);
    final productos = await repo.productosDe(postobon);
    expect(productos.map((p) => (p.producto.nombre, p.precioCompra)),
        [('Avena', 1500), ('Coca', 900)]);
  });
}
