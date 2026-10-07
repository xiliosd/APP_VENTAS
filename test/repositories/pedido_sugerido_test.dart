import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/repositories/inventario_repository.dart';
import 'package:app_ventas/repositories/producto_repository.dart';
import 'package:app_ventas/repositories/proveedor_repository.dart';
import 'package:app_ventas/repositories/venta_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late InventarioRepository repo;
  late Usuario ana;
  late int postobon;
  late int alpina;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = InventarioRepository(db, reloj: () => DateTime(2026, 10, 7, 8));
    final id = await db.into(db.usuarios).insert(
        UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'x'));
    ana = await (db.select(db.usuarios)..where((u) => u.id.equals(id)))
        .getSingle();
    postobon = await ProveedorRepository(db).crear(nombre: 'Postobón');
    alpina = await ProveedorRepository(db).crear(nombre: 'Alpina');
  });

  tearDown(() => db.close());

  Future<int> producto(String nombre,
          {List<ProveedorDeProducto> proveedores = const []}) =>
      ProductoRepository(db)
          .guardarProducto(nombre: nombre, precio: 1000, proveedores: proveedores);

  ProveedorDeProducto de(int id, int precio, {bool preferido = false}) =>
      ProveedorDeProducto(
          proveedorId: id, precioCompra: precio, preferido: preferido);

  test('con pedir hasta, sin él, negativo y nunca menos de 1', () async {
    final coca = await producto('Coca', proveedores: [
      de(postobon, 900, preferido: true),
      de(alpina, 850),
    ]);
    final pan = await producto('Pan', proveedores: [de(postobon, 400, preferido: true)]);
    final agua = await producto('Agua', proveedores: [de(postobon, 700, preferido: true)]);
    await repo.activarControl(coca, cantidad: 1, minimo: 5, por: ana);
    await repo.cambiarPedirHasta(coca, 24);
    await repo.activarControl(pan, cantidad: 2, minimo: 6, por: ana);
    await repo.activarControl(agua, cantidad: 0, minimo: 0, por: ana);
    await VentaRepository(db).registrarVenta(
      monto: 3000,
      esFiado: false,
      usuarioId: ana.id,
      fecha: DateTime(2026, 10, 7, 9),
      lineas: [
        LineaNueva(
            productoId: coca, descripcion: 'Coca', precioUnitario: 1000, cantidad: 3),
      ],
    );

    final lineas = await repo.sugerenciaPedido(postobon);

    expect(lineas.map((l) => l.producto.nombre), ['Coca', 'Pan', 'Agua']);
    expect(lineas.map((l) => (l.existencias, l.sugerido, l.precio)), [
      (-2, 26, 900),
      (2, 10, 400),
      (0, 1, 700),
    ]);
  });

  test('sin proveedor no hay precio', () async {
    final pan = await producto('Pan');
    await repo.activarControl(pan, cantidad: 1, minimo: 3, por: ana);

    final lineas = await repo.sugerenciaPedido(null);

    expect(lineas.single.producto.id, pan);
    expect(lineas.single.sugerido, 5);
    expect(lineas.single.precio, isNull);
    expect(await repo.sugerenciaPedido(postobon), isEmpty);
  });

  test('cambiarPedirHasta guarda, borra y valida', () async {
    final pan = await producto('Pan');
    await repo.activarControl(pan, cantidad: 1, minimo: 3, por: ana);

    await repo.cambiarPedirHasta(pan, 12);
    Future<int?> leer() async => (await (db.select(db.productos)
              ..where((p) => p.id.equals(pan)))
            .getSingle())
        .pedirHasta;
    expect(await leer(), 12);

    await repo.cambiarPedirHasta(pan, null);
    expect(await leer(), isNull);

    await expectLater(repo.cambiarPedirHasta(pan, -1), throwsArgumentError);
    await expectLater(repo.cambiarPedirHasta(pan, 2), throwsArgumentError);
    expect(await leer(), isNull);
  });
}
