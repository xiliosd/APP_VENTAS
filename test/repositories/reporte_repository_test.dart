import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/repositories/fiado_repository.dart';
import 'package:app_ventas/repositories/reporte_repository.dart';
import 'package:app_ventas/util/periodo.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late ReporteRepository repo;
  late int ana;
  late int pedro;
  final lunes = DateTime(2026, 10, 5);
  final domingo = DateTime(2026, 10, 11);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = ReporteRepository(db, FiadoRepository(db));
    ana = await db.into(db.usuarios).insert(
        UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'x'));
    pedro = await db
        .into(db.clientes)
        .insert(ClientesCompanion.insert(nombre: 'Don Pedro'));
  });

  tearDown(() => db.close());

  Future<int> vender(int monto, DateTime fecha,
          {bool fiado = false, MedioPago medio = MedioPago.efectivo}) =>
      db.into(db.ventas).insert(VentasCompanion.insert(
            monto: monto,
            fecha: fecha,
            usuarioId: ana,
            esFiado: Value(fiado),
            clienteId: Value(fiado ? pedro : null),
            medioPago: Value(medio),
          ));

  Future<int> abonar(int monto, DateTime fecha,
          {MedioPago medio = MedioPago.efectivo}) =>
      db.into(db.pagosFiado).insert(PagosFiadoCompanion.insert(
            clienteId: pedro,
            monto: monto,
            fecha: fecha,
            usuarioId: ana,
            medioPago: Value(medio),
          ));

  Future<int> gastar(int monto, DateTime fecha) => db.into(db.gastos).insert(
      GastosCompanion.insert(monto: monto, fecha: fecha, usuarioId: ana));

  Future<void> anular(String tabla, int id) => db.customStatement(
      'UPDATE $tabla SET anulado = 1 WHERE id = ?', [id]);

  group('reporte', () {
    test('suma el periodo y separa caja, banco y fiado', () async {
      await vender(5000, DateTime(2026, 10, 5, 9));
      await vender(3000, DateTime(2026, 10, 5, 10),
          medio: MedioPago.transferencia);
      await vender(4000, DateTime(2026, 10, 6), fiado: true);
      await anular('ventas', await vender(9999, DateTime(2026, 10, 6)));
      await abonar(1000, DateTime(2026, 10, 7));
      await abonar(500, DateTime(2026, 10, 7), medio: MedioPago.transferencia);
      await gastar(2000, DateTime(2026, 10, 7));
      await vender(7000, DateTime(2026, 10, 4));
      await vender(7000, DateTime(2026, 10, 12));

      final r = await repo.reporte(lunes, domingo);

      expect(r.ventas, 12000);
      expect(r.cantidadVentas, 3);
      expect(r.ventaPromedio, 4000);
      expect(r.gastos, 2000);
      expect(r.ganancia, 10000);
      expect(r.recibidoEfectivo, 6000);
      expect(r.recibidoTransferencia, 3500);
      expect(r.fiado, 4000);
      expect(r.cobrado, 1500);
      expect(r.deudaInicio, 0);
      expect(r.deudaFin, 2500);
      expect(r.ventasPorDia.length, 7);
      expect(r.ventasPorDia[DateTime(2026, 10, 5)], 8000);
      expect(r.ventasPorDia[DateTime(2026, 10, 6)], 4000);
      expect(r.ventasPorDia[DateTime(2026, 10, 7)], 0);
      expect(r.mejorDia, DateTime(2026, 10, 5));
      expect(r.vacio, isFalse);
    });

    test('cada venta cae en su semana aunque sea a medianoche', () async {
      await vender(1000, DateTime(2026, 10, 11, 23, 59, 59));
      await vender(2000, DateTime(2026, 10, 12));
      await vender(4000, DateTime(2026, 10, 4, 23, 59));

      expect((await repo.reporte(lunes, domingo)).ventas, 1000);
    });

    test('un anulado no cuenta en nada', () async {
      await anular('pagos_fiado', await abonar(800, DateTime(2026, 10, 6)));
      await anular('gastos', await gastar(900, DateTime(2026, 10, 6)));

      final r = await repo.reporte(lunes, domingo);

      expect(r.cobrado, 0);
      expect(r.gastos, 0);
      expect(r.recibidoEfectivo, 0);
      expect(r.vacio, isTrue);
    });

    test('en un empate el mejor día es el primero', () async {
      await vender(3000, DateTime(2026, 10, 5));
      await vender(3000, DateTime(2026, 10, 6));

      expect((await repo.reporte(lunes, domingo)).mejorDia,
          DateTime(2026, 10, 5));
    });

    test('sin datos: vacío, sin mejor día y todos los días en 0', () async {
      final r = await repo.reporte(lunes, domingo);

      expect(r.vacio, isTrue);
      expect(r.mejorDia, isNull);
      expect(r.ventaPromedio, 0);
      expect(r.ventasPorDia.values, everyElement(0));
      expect(r.ventasPorDia.keys.first, lunes);
      expect(r.ventasPorDia.keys.last, domingo);
    });

    test('la deuda al inicio cuenta lo fiado antes del periodo', () async {
      await vender(6000, DateTime(2026, 9, 30), fiado: true);

      final r = await repo.reporte(lunes, domingo);

      expect(r.deudaInicio, 6000);
      expect(r.deudaFin, 6000);
      expect(r.fiado, 0);
    });
  });

  group('comparar', () {
    test('un periodo cerrado se compara con el anterior completo', () async {
      await vender(4000, DateTime(2026, 9, 22));
      await vender(1000, DateTime(2026, 9, 27, 20));
      await vender(6000, DateTime(2026, 9, 29));

      final c = await repo.comparar(
          Periodo.de(TipoPeriodo.semana, DateTime(2026, 9, 30)),
          hoy: DateTime(2026, 10, 7));

      expect(c.actual.ventas, 6000);
      expect(c.anterior.ventas, 5000);
      expect(c.cambioVentas, 20);
      expect(c.actual.ventasPorDia.length, 7);
    });

    test('el periodo actual se compara con los mismos días del anterior',
        () async {
      await vender(4000, DateTime(2026, 9, 29));
      await vender(9000, DateTime(2026, 10, 2));
      await vender(5000, DateTime(2026, 10, 6));

      final hoy = DateTime(2026, 10, 7);
      final c = await repo.comparar(Periodo.actual(TipoPeriodo.semana, hoy),
          hoy: hoy);

      expect(c.actual.ventasPorDia.length, 3);
      expect(c.anterior.ventas, 4000);
      expect(c.cambioVentas, 25);
    });

    test('el 31 de marzo se compara con febrero hasta el 28', () async {
      await vender(2000, DateTime(2026, 2, 28, 18));
      await vender(4000, DateTime(2026, 3, 10));

      final hoy = DateTime(2026, 3, 31);
      final c =
          await repo.comparar(Periodo.actual(TipoPeriodo.mes, hoy), hoy: hoy);

      expect(c.anterior.ventas, 2000);
      expect(c.anterior.ventasPorDia.length, 28);
      expect(c.cambioVentas, 100);
    });

    test('sin ventas en el anterior no hay porcentaje', () async {
      await vender(5000, DateTime(2026, 10, 6));

      final hoy = DateTime(2026, 10, 7);
      final c = await repo.comparar(Periodo.actual(TipoPeriodo.semana, hoy),
          hoy: hoy);

      expect(c.cambioVentas, isNull);
    });

    test('una ganancia anterior negativa usa su valor absoluto', () async {
      await gastar(1000, DateTime(2026, 9, 29));
      await vender(500, DateTime(2026, 10, 6));

      final hoy = DateTime(2026, 10, 7);
      final c = await repo.comparar(Periodo.actual(TipoPeriodo.semana, hoy),
          hoy: hoy);

      expect(c.anterior.ganancia, -1000);
      expect(c.cambioGanancia, 150);
    });
  });

  test('cambioPorcentual redondea y es null con anterior en 0', () {
    expect(cambioPorcentual(1150, 1000), 15);
    expect(cambioPorcentual(900, 1000), -10);
    expect(cambioPorcentual(1000, 1000), 0);
    expect(cambioPorcentual(1000, 3000), -67);
    expect(cambioPorcentual(500, 0), isNull);
  });

  test('comparar lee la deuda de las cuatro fechas de una vez', () async {
    final fiado = _FiadoContador(db);
    final hoy = DateTime(2026, 10, 7);
    await ReporteRepository(db, fiado)
        .comparar(Periodo.actual(TipoPeriodo.semana, hoy), hoy: hoy);
    expect((fiado.lotes, fiado.sueltas), (1, 0));
  });
}

class _FiadoContador extends FiadoRepository {
  _FiadoContador(super.db);

  int lotes = 0;
  int sueltas = 0;

  @override
  Future<Map<DateTime, int>> deudasTotalesAl(Iterable<DateTime> dias) {
    lotes++;
    return super.deudasTotalesAl(dias);
  }

  @override
  Future<int> deudaTotalAl(DateTime dia) {
    sueltas++;
    return super.deudaTotalAl(dia);
  }
}
