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
  late ProductoRepository productos;
  late Usuario ana;
  late int postobon;
  late int alpina;
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
    postobon = await ProveedorRepository(db).crear(nombre: 'Postobón');
    alpina = await ProveedorRepository(db).crear(nombre: 'alpina');
  });

  tearDown(() => db.close());

  Future<int> producto(String nombre, {int? proveedor}) =>
      productos.guardarProducto(
        nombre: nombre,
        precio: 1000,
        proveedores: proveedor == null
            ? const []
            : [
                ProveedorDeProducto(
                    proveedorId: proveedor, precioCompra: 500, preferido: true),
              ],
      );

  Future<void> controlar(int id, int hay, int minimo) =>
      repo.activarControl(id, cantidad: hay, minimo: minimo, por: ana);

  test('agrupa por proveedor preferido y ordena', () async {
    final coca = await producto('Coca', proveedor: postobon);
    final pepsi = await producto('Pepsi', proveedor: postobon);
    final colombiana = await producto('Colombiana', proveedor: postobon);
    final leche = await producto('Leche', proveedor: alpina);
    final pan = await producto('Pan');
    final sobra = await producto('Sobra', proveedor: postobon);
    await controlar(coca, 2, 6); // −4
    await controlar(pepsi, 5, 6); // −1
    await controlar(colombiana, 1, 0); // tiene suficiente: 1 > 0
    await controlar(leche, 0, 3);
    await controlar(pan, 1, 1);
    await controlar(sobra, 50, 5);
    // Colombiana queda en negativo con una venta.
    await VentaRepository(db).registrarVenta(
      monto: 3000,
      esFiado: false,
      usuarioId: ana.id,
      fecha: DateTime(2026, 10, 7, 9),
      lineas: [
        LineaNueva(
            productoId: colombiana,
            descripcion: 'Colombiana',
            precioUnitario: 1000,
            cantidad: 3),
      ],
    );

    final grupos = await repo.porPedir();

    expect(grupos.map((g) => g.proveedor?.nombre), ['alpina', 'Postobón', null]);
    expect(grupos[1].productos.map((p) => p.producto.nombre),
        ['Colombiana', 'Coca', 'Pepsi']);
    expect(grupos[1].productos.first.existencias, -2);
    expect(grupos[2].productos.single.producto.nombre, 'Pan');
  });

  test('un producto inactivo o sin control no aparece', () async {
    final coca = await producto('Coca', proveedor: postobon);
    final pepsi = await producto('Pepsi', proveedor: postobon);
    await controlar(coca, 0, 5);
    await productos.desactivarProducto(coca);
    await producto('Pan');

    expect(await repo.porPedir(), isEmpty);
    expect(pepsi, isPositive);
  });

  test('productos con control por nombre con sus existencias', () async {
    final pepsi = await producto('Pepsi');
    final coca = await producto('Coca');
    await producto('Pan');
    await controlar(pepsi, 4, 1);
    await controlar(coca, 9, 1);

    final lista = await repo.productosConControl();
    expect(lista.map((p) => (p.producto.nombre, p.existencias)),
        [('Coca', 9), ('Pepsi', 4)]);
  });

  test('el historial mezcla conteos y entradas, el más reciente primero',
      () async {
    final coca = await producto('Coca', proveedor: postobon);
    await controlar(coca, 12, 2);
    ahora = DateTime(2026, 10, 7, 9);
    final entrada = await repo.recibirMercancia(
      proveedorId: postobon,
      lineas: [LineaRecibida(productoId: coca, cantidad: 24, precioCompra: 500)],
      por: ana,
    );
    ahora = DateTime(2026, 10, 7, 10);
    await repo.ajustarConteo(coca, cantidad: 30, por: ana);
    await repo.anularEntrada(entrada, por: ana);

    final h = await repo.historial(coca);
    expect(h.map((m) => m.tipo), [
      TipoMovimientoInventario.ajuste,
      TipoMovimientoInventario.entrada,
      TipoMovimientoInventario.conteoInicial,
    ]);
    expect((h[0].anterior, h[0].cantidad, h[0].quien), (36, 30, 'Ana'));
    expect((h[1].cantidad, h[1].quien), (24, 'Postobón'));
    expect(h[1].anulada, isTrue);
    expect((h[2].cantidad, h[2].quien), (12, 'Ana'));
  });
}
