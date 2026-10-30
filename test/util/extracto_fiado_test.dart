import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/repositories/fiado_repository.dart';
import 'package:app_ventas/util/extracto_fiado.dart';
import 'package:flutter_test/flutter_test.dart';

MovimientoFiado _venta(
  int id,
  int monto,
  DateTime fecha, {
  bool anulado = false,
}) => MovimientoFiado(
  tipo: TipoMovimientoFiado.venta,
  id: id,
  monto: monto,
  fecha: fecha,
  usuarioId: 1,
  anulado: anulado,
);

MovimientoFiado _abono(
  int id,
  int monto,
  DateTime fecha, {
  bool anulado = false,
}) => MovimientoFiado(
  tipo: TipoMovimientoFiado.abono,
  id: id,
  monto: monto,
  fecha: fecha,
  usuarioId: 1,
  anulado: anulado,
);

LineaVenta _linea(int id, int ventaId) => LineaVenta(
  id: id,
  ventaId: ventaId,
  productoId: null,
  descripcion: 'Arepa',
  precioUnitario: 1000,
  cantidad: 1,
);

void main() {
  final d1 = DateTime(2026, 10, 1);
  final d2 = DateTime(2026, 10, 2);
  final d3 = DateTime(2026, 10, 3);
  final d4 = DateTime(2026, 10, 4);

  test('sin abonos: todo en recientes, sin consolidado', () {
    final e = armarExtracto([_venta(2, 500, d2), _venta(1, 1000, d1)], {});
    expect(e.ultimoAbono, isNull);
    expect(e.anteriores, isEmpty);
    expect(e.recientes.map((x) => x.monto), [1000, 500]);
    expect((e.recientes.last as FiadoExtracto).saldoDespues, 1500);
    expect(e.saldoActual, 1500);
  });

  test('fiado 10.000, abono 4.000, fiado 3.000', () {
    final e = armarExtracto(
      [_venta(2, 3000, d3), _abono(1, 4000, d2), _venta(1, 10000, d1)],
      {
        1: [_linea(1, 1)],
      },
    );
    expect(e.ultimoAbono!.saldoDespues, 6000);
    expect(e.anteriores, hasLength(1));
    final fiado = e.anteriores.single as FiadoExtracto;
    expect(fiado.monto, 10000);
    expect(fiado.lineas, hasLength(1));
    expect(e.recientes.single.monto, 3000);
    expect(e.saldoActual, 9000);
  });

  test('dos abonos: el primero queda en anteriores con su saldoDespues', () {
    final e = armarExtracto([
      _venta(1, 10000, d1),
      _abono(1, 4000, d2),
      _abono(2, 1000, d3),
    ], {});
    expect(e.ultimoAbono!.pagoId, 2);
    expect(e.ultimoAbono!.saldoDespues, 5000);
    expect(e.anteriores, hasLength(2));
    expect((e.anteriores.last as AbonoExtracto).saldoDespues, 6000);
    expect(e.recientes, isEmpty);
  });

  test('anulados no aparecen ni cuentan', () {
    final e = armarExtracto([
      _venta(1, 10000, d1),
      _venta(2, 7000, d2, anulado: true),
      _abono(1, 4000, d3, anulado: true),
    ], {});
    expect(e.ultimoAbono, isNull);
    expect(e.recientes, hasLength(1));
    expect(e.saldoActual, 10000);
  });

  test('misma fecha: la venta va antes que el abono', () {
    final e = armarExtracto([_abono(1, 4000, d1), _venta(1, 10000, d1)], {});
    expect(e.anteriores.single, isA<FiadoExtracto>());
    expect(e.ultimoAbono!.saldoDespues, 6000);
  });

  test('venta sin líneas queda con lineas vacías y su monto', () {
    final e = armarExtracto([_venta(1, 2500, d4)], {});
    final f = e.recientes.single as FiadoExtracto;
    expect(f.lineas, isEmpty);
    expect(f.monto, 2500);
    expect(f.ventaId, 1);
  });

  test('sin movimientos: saldo 0', () {
    final e = armarExtracto([], {});
    expect(e.saldoActual, 0);
    expect(e.recientes, isEmpty);
  });
}
