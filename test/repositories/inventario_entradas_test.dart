import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/repositories/inventario_repository.dart';
import 'package:app_ventas/repositories/producto_repository.dart';
import 'package:app_ventas/repositories/proveedor_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late InventarioRepository repo;
  late ProductoRepository productos;
  late Usuario ana;
  late int postobon;
  late int alpina;
  late int arepa; // con Postobón $2.500 preferido
  late int avena; // sin proveedores
  var ahora = DateTime(2026, 10, 7, 8);

  setUp(() async {
    ahora = DateTime(2026, 10, 7, 8);
    db = AppDatabase(NativeDatabase.memory());
    repo = InventarioRepository(db, reloj: () => ahora);
    productos = ProductoRepository(db);
    final id = await db.into(db.usuarios).insert(
        UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'x'));
    ana = await (db.select(db.usuarios)..where((u) => u.id.equals(id)))
        .getSingle();
    final proveedores = ProveedorRepository(db);
    postobon = await proveedores.crear(nombre: 'Postobón');
    alpina = await proveedores.crear(nombre: 'Alpina');
    arepa = await productos.guardarProducto(
      nombre: 'Arepa',
      precio: 3500,
      proveedores: [
        ProveedorDeProducto(
            proveedorId: postobon, precioCompra: 2500, preferido: true),
      ],
    );
    avena = await productos.guardarProducto(nombre: 'Avena', precio: 2000);
  });

  tearDown(() => db.close());

  test('recibir suma existencias y guarda la entrada con su total', () async {
    await repo.activarControl(arepa, cantidad: 5, minimo: 2, por: ana);
    ahora = DateTime(2026, 10, 7, 9);

    final id = await repo.recibirMercancia(
      proveedorId: postobon,
      lineas: [LineaRecibida(productoId: arepa, cantidad: 24, precioCompra: 2500)],
      nota: ' Factura 123 ',
      por: ana,
    );

    expect(await repo.existencias(arepa), 29);
    final entrada = await db.select(db.entradasMercancia).getSingle();
    expect(entrada.id, id);
    expect(entrada.total, 60000);
    expect(entrada.nota, 'Factura 123');
    expect(entrada.usuarioId, ana.id);
  });

  test('un precio distinto actualiza el del proveedor y el costo', () async {
    await repo.recibirMercancia(
      proveedorId: postobon,
      lineas: [LineaRecibida(productoId: arepa, cantidad: 10, precioCompra: 2600)],
      por: ana,
    );
    expect(await productos.costoDe(arepa), 2600);
  });

  test('un proveedor nuevo para el producto se agrega', () async {
    await repo.recibirMercancia(
      proveedorId: alpina,
      lineas: [
        LineaRecibida(productoId: avena, cantidad: 6, precioCompra: 1500),
        LineaRecibida(productoId: arepa, cantidad: 2, precioCompra: 2400),
      ],
      por: ana,
    );

    final deAvena = await productos.proveedoresDe(avena);
    expect(deAvena.single.proveedorId, alpina);
    expect(deAvena.single.preferido, isTrue);
    expect(await productos.costoDe(avena), 1500);
    final deArepa = await productos.proveedoresDe(arepa);
    expect(deArepa, hasLength(2));
    expect(await productos.costoDe(arepa), 2500);
  });

  test('un producto sin control registra la entrada pero no existencias',
      () async {
    await repo.recibirMercancia(
      proveedorId: alpina,
      lineas: [LineaRecibida(productoId: avena, cantidad: 6, precioCompra: 1500)],
      por: ana,
    );
    expect(await db.select(db.lineasEntrada).get(), hasLength(1));
    expect(await repo.existencias(avena), isNull);
  });

  test('anular descuenta existencias, no revierte precios y no se repite',
      () async {
    await repo.activarControl(arepa, cantidad: 5, minimo: 2, por: ana);
    ahora = DateTime(2026, 10, 7, 9);
    final id = await repo.recibirMercancia(
      proveedorId: postobon,
      lineas: [LineaRecibida(productoId: arepa, cantidad: 24, precioCompra: 2600)],
      por: ana,
    );

    await repo.anularEntrada(id, por: ana);

    expect(await repo.existencias(arepa), 5);
    expect(await productos.costoDe(arepa), 2600);
    final entrada = await db.select(db.entradasMercancia).getSingle();
    expect(entrada.anulada, isTrue);
    expect(entrada.anuladaPorId, ana.id);
    await expectLater(repo.anularEntrada(id, por: ana), throwsArgumentError);
    expect(await repo.existencias(arepa), 5);
  });

  test('entradas recientes y detalle traen nombres', () async {
    ahora = DateTime(2026, 10, 7, 9);
    final id = await repo.recibirMercancia(
      proveedorId: postobon,
      lineas: [LineaRecibida(productoId: arepa, cantidad: 24, precioCompra: 2500)],
      por: ana,
    );

    final recientes = await repo.entradasRecientes();
    expect(recientes.single.proveedor, 'Postobón');
    expect(recientes.single.usuario, 'Ana');
    final detalle = await repo.detalleEntrada(id);
    expect(detalle.lineas.single.producto, 'Arepa');
    expect(detalle.lineas.single.linea.cantidad, 24);
  });

  test('entradas inválidas se rechazan sin guardar nada', () async {
    final invalidas = <(int, List<LineaRecibida>)>[
      (postobon, []),
      (postobon, [LineaRecibida(productoId: arepa, cantidad: 0, precioCompra: 2500)]),
      (postobon, [LineaRecibida(productoId: arepa, cantidad: 3, precioCompra: 0)]),
      (
        postobon,
        [
          LineaRecibida(productoId: arepa, cantidad: 3, precioCompra: 2500),
          LineaRecibida(productoId: arepa, cantidad: 1, precioCompra: 2500),
        ]
      ),
      (999, [LineaRecibida(productoId: arepa, cantidad: 3, precioCompra: 2500)]),
    ];
    for (final (proveedor, lineas) in invalidas) {
      await expectLater(
          repo.recibirMercancia(proveedorId: proveedor, lineas: lineas, por: ana),
          throwsArgumentError);
    }
    await ProveedorRepository(db).desactivar(alpina);
    await expectLater(
        repo.recibirMercancia(
            proveedorId: alpina,
            lineas: [LineaRecibida(productoId: avena, cantidad: 1, precioCompra: 1)],
            por: ana),
        throwsArgumentError);

    expect(await db.select(db.entradasMercancia).get(), isEmpty);
    expect(await db.select(db.lineasEntrada).get(), isEmpty);
    expect(await productos.costoDe(arepa), 2500);
  });
}
