import 'package:app_ventas/repositories/fiado_repository.dart';
import 'package:app_ventas/util/saldos_fiado.dart';
import 'package:flutter_test/flutter_test.dart';

MovimientoFiado mov(TipoMovimientoFiado tipo, int id, int monto, int dia,
        {bool anulado = false}) =>
    MovimientoFiado(
        tipo: tipo,
        id: id,
        monto: monto,
        fecha: DateTime(2026, 10, dia, 10),
        usuarioId: 1,
        anulado: anulado);

const venta = TipoMovimientoFiado.venta;
const abono = TipoMovimientoFiado.abono;

void main() {
  test('acumula del más antiguo al más reciente, sin importar el orden dado', () {
    final saldos = saldosAcumulados([
      mov(abono, 2, 3000, 3),
      mov(venta, 1, 5000, 1),
      mov(venta, 3, 2000, 5),
    ]);
    expect(saldos[(venta, 1)], 5000);
    expect(saldos[(abono, 2)], 2000);
    expect(saldos[(venta, 3)], 4000);
  });

  test('los anulados no cuentan ni tienen saldo', () {
    final saldos = saldosAcumulados([
      mov(venta, 1, 5000, 1),
      mov(venta, 2, 9000, 2, anulado: true),
      mov(abono, 3, 1000, 3),
    ]);
    expect(saldos.containsKey((venta, 2)), isFalse);
    expect(saldos[(abono, 3)], 4000);
  });

  test('puede quedar saldo a favor (negativo)', () {
    final saldos = saldosAcumulados([
      mov(venta, 1, 2000, 1),
      mov(abono, 2, 5000, 2),
    ]);
    expect(saldos[(abono, 2)], -3000);
  });

  test('misma fecha: venta antes que abono', () {
    final saldos = saldosAcumulados([
      MovimientoFiado(tipo: abono, id: 9, monto: 1000,
          fecha: DateTime(2026, 10, 1, 10), usuarioId: 1),
      MovimientoFiado(tipo: venta, id: 8, monto: 3000,
          fecha: DateTime(2026, 10, 1, 10), usuarioId: 1),
    ]);
    expect(saldos[(venta, 8)], 3000);
    expect(saldos[(abono, 9)], 2000);
  });
}
