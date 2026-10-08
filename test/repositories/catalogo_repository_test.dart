import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/repositories/catalogo_repository.dart';
import 'package:app_ventas/repositories/inventario_repository.dart';
import 'package:app_ventas/repositories/producto_repository.dart';
import 'package:app_ventas/repositories/proveedor_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late CatalogoRepository repo;
  late Usuario ana;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = CatalogoRepository(db, ProductoRepository(db),
        ProveedorRepository(db), InventarioRepository(db));
    final id = await db.into(db.usuarios).insert(
        UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'x'));
    ana = await (db.select(db.usuarios)..where((u) => u.id.equals(id)))
        .getSingle();
  });
  tearDown(() => db.close());

  const alpinaNueva = ProveedorEnFormulario(
      nombre: 'Alpina', precioCompra: 1500, preferido: true);

  test('guarda producto, proveedor nuevo y control juntos', () async {
    final id = await repo.guardarProductoCompleto(
      nombre: 'Avena',
      precio: 2000,
      proveedores: const [alpinaNueva],
      control: const ControlEnFormulario(hayAhora: 5, minimo: 2, pedirHasta: 10),
      controlabaAntes: false,
      por: ana,
    );
    final p = await (db.select(db.productos)..where((x) => x.id.equals(id)))
        .getSingle();
    expect((p.controlaExistencias, p.minimo, p.pedirHasta), (true, 2, 10));
    expect((await db.select(db.proveedores).getSingle()).nombre, 'Alpina');
    expect(await InventarioRepository(db).existencias(id), 5);
  });

  test('si falla el último paso no queda nada', () async {
    await expectLater(
      repo.guardarProductoCompleto(
        nombre: 'Avena',
        precio: 2000,
        proveedores: const [alpinaNueva],
        // "Pedir hasta" menor que el mínimo: cambiarLimites lanza al final.
        control: const ControlEnFormulario(hayAhora: 5, minimo: 6, pedirHasta: 3),
        controlabaAntes: false,
        por: ana,
      ),
      throwsArgumentError,
    );
    expect(await db.select(db.productos).get(), isEmpty);
    expect(await db.select(db.proveedores).get(), isEmpty);
    expect(await db.select(db.conteosInventario).get(), isEmpty);
  });

  test('al editar, un fallo deja el producto como estaba', () async {
    final id = await ProductoRepository(db)
        .guardarProducto(nombre: 'Avena', precio: 2000);
    await expectLater(
      repo.guardarProductoCompleto(
        id: id,
        nombre: 'Avena grande',
        precio: 2500,
        proveedores: const [],
        control: const ControlEnFormulario(hayAhora: 1, minimo: 6, pedirHasta: 3),
        controlabaAntes: false,
        por: ana,
      ),
      throwsArgumentError,
    );
    final p = await (db.select(db.productos)..where((x) => x.id.equals(id)))
        .getSingle();
    expect((p.nombre, p.precio, p.controlaExistencias), ('Avena', 2000, false));
  });

  test('reutiliza un proveedor existente con el mismo nombre', () async {
    final alpina = await ProveedorRepository(db).crear(nombre: 'Alpina');
    final id = await repo.guardarProductoCompleto(
      nombre: 'Avena',
      precio: 2000,
      proveedores: const [
        ProveedorEnFormulario(
            nombre: ' alpina ', precioCompra: 1500, preferido: true),
      ],
      controlabaAntes: false,
      por: ana,
    );
    expect(await db.select(db.proveedores).get(), hasLength(1));
    expect((await ProductoRepository(db).proveedoresDe(id)).single.proveedorId,
        alpina);
  });

  test('dejar de controlar apaga el control', () async {
    final id = await ProductoRepository(db)
        .guardarProducto(nombre: 'Avena', precio: 2000);
    await InventarioRepository(db)
        .activarControl(id, cantidad: 3, minimo: 1, por: ana);
    await repo.guardarProductoCompleto(
      id: id,
      nombre: 'Avena',
      precio: 2000,
      proveedores: const [],
      controlabaAntes: true,
      por: ana,
    );
    final p = await (db.select(db.productos)..where((x) => x.id.equals(id)))
        .getSingle();
    expect(p.controlaExistencias, isFalse);
  });
}
