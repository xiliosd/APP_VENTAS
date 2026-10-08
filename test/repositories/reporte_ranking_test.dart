import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/repositories/fiado_repository.dart';
import 'package:app_ventas/repositories/reporte_repository.dart';
import 'package:app_ventas/repositories/venta_repository.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late ReporteRepository repo;
  late VentaRepository ventas;
  late int ana;
  final lunes = DateTime(2026, 10, 5);
  final domingo = DateTime(2026, 10, 11);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = ReporteRepository(db, FiadoRepository(db));
    ventas = VentaRepository(db);
    ana = await db.into(db.usuarios).insert(
        UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'x'));
  });

  tearDown(() => db.close());

  Future<int> producto(String nombre, int precio) => db
      .into(db.productos)
      .insert(ProductosCompanion.insert(nombre: nombre, precio: precio));

  LineaNueva de(int productoId, String nombre, int precio, int cantidad) =>
      LineaNueva(
          productoId: productoId,
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

  test('ordena por unidades, desempata por dinero y aparta los montos sueltos',
      () async {
    final arepa = await producto('Arepa', 3500);
    final coca = await producto('Cocacola', 1200);
    final pan = await producto('Pan', 500);
    await vender(DateTime(2026, 10, 5, 9),
        [de(arepa, 'Arepa', 3500, 2), de(coca, 'Cocacola', 1200, 1)]);
    await vender(DateTime(2026, 10, 6, 10), [
      de(coca, 'Cocacola', 1200, 1),
      const LineaNueva(descripcion: r'$5.000', precioUnitario: 5000, cantidad: 1),
    ]);
    await vender(DateTime(2026, 10, 6, 11), [de(pan, 'Pan', 500, 2)]);
    final anulada =
        await vender(DateTime(2026, 10, 7), [de(pan, 'Pan', 500, 10)]);
    await db.customStatement(
        'UPDATE ventas SET anulado = 1 WHERE id = ?', [anulada]);
    await vender(DateTime(2026, 10, 12), [de(pan, 'Pan', 500, 50)]);

    final r = await repo.reporte(lunes, domingo);

    expect(r.ranking.map((p) => p.nombre), ['Arepa', 'Cocacola', 'Pan']);
    expect(r.ranking.map((p) => p.unidades), [2, 2, 2]);
    expect(r.ranking.map((p) => p.dinero), [7000, 2400, 1000]);
    expect(r.otrosMontos, 5000);
  });

  test('un producto renombrado se agrupa con su nombre actual', () async {
    final arepa = await producto('Arepa', 3500);
    await vender(DateTime(2026, 10, 5), [de(arepa, 'Arepa', 3500, 1)]);
    await (db.update(db.productos)..where((p) => p.id.equals(arepa)))
        .write(const ProductosCompanion(nombre: Value('Arepa de queso')));
    await vender(DateTime(2026, 10, 6), [de(arepa, 'Arepa de queso', 4000, 2)]);

    final r = await repo.reporte(lunes, domingo);

    expect(r.ranking.single.nombre, 'Arepa de queso');
    expect(r.ranking.single.unidades, 3);
    expect(r.ranking.single.dinero, 11500);
  });

  test('el ranking se corta en 10', () async {
    for (var i = 1; i <= 12; i++) {
      final id = await producto('P$i', 100);
      await vender(DateTime(2026, 10, 5), [de(id, 'P$i', 100, i)]);
    }

    final r = await repo.reporte(lunes, domingo);

    expect(r.ranking, hasLength(10));
    expect(r.ranking.first.unidades, 12);
    expect(r.ranking.last.unidades, 3);
  });

  test('las horas suman por hora local y la pico es la de más dinero',
      () async {
    await ventas.registrarVenta(
        monto: 1000, esFiado: false, usuarioId: ana,
        fecha: DateTime(2026, 10, 5, 9, 15));
    await ventas.registrarVenta(
        monto: 2000, esFiado: false, usuarioId: ana,
        fecha: DateTime(2026, 10, 6, 9, 40));
    await ventas.registrarVenta(
        monto: 2500, esFiado: false, usuarioId: ana,
        fecha: DateTime(2026, 10, 6, 18, 5));
    final anulada = await ventas.registrarVenta(
        monto: 9000, esFiado: false, usuarioId: ana,
        fecha: DateTime(2026, 10, 6, 20));
    await db.customStatement(
        'UPDATE ventas SET anulado = 1 WHERE id = ?', [anulada]);

    final r = await repo.reporte(lunes, domingo);

    expect(r.ventasPorHora, {9: 3000, 18: 2500});
    expect(r.ventasPorHora.keys.toList(), [9, 18]);
    expect(r.horaPico, 9);
    expect(r.ranking, isEmpty);
    expect(r.otrosMontos, 0);
  });

  test('en un empate de horas gana la más temprana', () async {
    await ventas.registrarVenta(
        monto: 2000, esFiado: false, usuarioId: ana,
        fecha: DateTime(2026, 10, 5, 18));
    await ventas.registrarVenta(
        monto: 2000, esFiado: false, usuarioId: ana,
        fecha: DateTime(2026, 10, 5, 7));

    expect((await repo.reporte(lunes, domingo)).horaPico, 7);
  });

  test('sin ventas no hay hora pico', () async {
    final r = await repo.reporte(lunes, domingo);
    expect(r.ventasPorHora, isEmpty);
    expect(r.horaPico, isNull);
  });

  test('con unidades y dinero iguales desempata sin mayúsculas', () async {
    final z = await producto('Zanahoria', 1000);
    final a = await producto('arepa', 1000);
    await vender(DateTime(2026, 10, 5, 9),
        [de(z, 'Zanahoria', 1000, 1), de(a, 'arepa', 1000, 1)]);

    final r = await repo.reporte(lunes, domingo);

    expect(r.ranking.map((p) => p.nombre), ['arepa', 'Zanahoria']);
  });
}
