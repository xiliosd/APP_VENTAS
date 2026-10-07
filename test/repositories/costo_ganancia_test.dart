import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/repositories/fiado_repository.dart';
import 'package:app_ventas/repositories/producto_repository.dart';
import 'package:app_ventas/repositories/proveedor_repository.dart';
import 'package:app_ventas/repositories/reporte_repository.dart';
import 'package:app_ventas/repositories/venta_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late VentaRepository ventas;
  late ProductoRepository productos;
  late int ana;
  late int arepa; // precio 3500, costo 2500
  late int coca; // precio 1200, sin proveedor
  late int postobon;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    ventas = VentaRepository(db);
    productos = ProductoRepository(db);
    ana = await db.into(db.usuarios).insert(
        UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'x'));
    postobon = await ProveedorRepository(db).crear(nombre: 'Postobón');
    arepa = await productos.guardarProducto(
      nombre: 'Arepa',
      precio: 3500,
      proveedores: [
        ProveedorDeProducto(
            proveedorId: postobon, precioCompra: 2500, preferido: true),
      ],
    );
    coca = await productos.guardarProducto(nombre: 'Coca', precio: 1200);
  });

  tearDown(() => db.close());

  LineaNueva de(int id, String nombre, int precio, int cantidad) => LineaNueva(
      productoId: id,
      descripcion: nombre,
      precioUnitario: precio,
      cantidad: cantidad);

  Future<int> vender(DateTime fecha, List<LineaNueva> lineas) =>
      ventas.registrarVenta(
          monto: lineas.fold(0, (s, l) => s + l.subtotal),
          esFiado: false,
          usuarioId: ana,
          fecha: fecha,
          lineas: lineas);

  test('cada línea guarda el costo del preferido; los sueltos no', () async {
    final id = await vender(DateTime(2026, 10, 6), [
      de(arepa, 'Arepa', 3500, 2),
      de(coca, 'Coca', 1200, 1),
      const LineaNueva(descripcion: r'$5.000', precioUnitario: 5000, cantidad: 1),
    ]);

    final lineas = await ventas.lineasDeVenta(id);
    expect(lineas.map((l) => l.costoUnitario), [2500, null, null]);
  });

  test('cambiar el costo después no altera la venta guardada', () async {
    final id = await vender(DateTime(2026, 10, 6), [de(arepa, 'Arepa', 3500, 1)]);
    await productos.guardarProducto(
      id: arepa,
      nombre: 'Arepa',
      precio: 3500,
      proveedores: [
        ProveedorDeProducto(
            proveedorId: postobon, precioCompra: 3000, preferido: true),
      ],
    );

    expect((await ventas.lineasDeVenta(id)).single.costoUnitario, 2500);
  });

  test('el reporte suma la ganancia y lo vendido sin costo', () async {
    await vender(DateTime(2026, 10, 6), [
      de(arepa, 'Arepa', 3500, 2),
      de(coca, 'Coca', 1200, 1),
      const LineaNueva(descripcion: r'$5.000', precioUnitario: 5000, cantidad: 1),
    ]);
    final anulada =
        await vender(DateTime(2026, 10, 7), [de(arepa, 'Arepa', 3500, 10)]);
    await db.customStatement(
        'UPDATE ventas SET anulado = 1 WHERE id = ?', [anulada]);

    final r = await ReporteRepository(db, FiadoRepository(db))
        .reporte(DateTime(2026, 10, 5), DateTime(2026, 10, 11));

    final deArepa = r.ranking.firstWhere((p) => p.productoId == arepa);
    final deCoca = r.ranking.firstWhere((p) => p.productoId == coca);
    expect(deArepa.ganancia, 2000);
    expect(deCoca.ganancia, isNull);
    expect(r.gananciaProductos, 2000);
    expect(r.vendidoSinCosto, 6200);
    expect(r.hayCostos, isTrue);
  });

  test('sin líneas con costo no hay costos', () async {
    await vender(DateTime(2026, 10, 6), [de(coca, 'Coca', 1200, 1)]);

    final r = await ReporteRepository(db, FiadoRepository(db))
        .reporte(DateTime(2026, 10, 5), DateTime(2026, 10, 11));

    expect(r.hayCostos, isFalse);
    expect(r.gananciaProductos, 0);
    expect(r.vendidoSinCosto, 1200);
  });
}
