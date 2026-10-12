import 'package:app_ventas/repositories/historial_repository.dart';
import 'package:app_ventas/screens/historial/filtro_historial.dart';
import 'package:flutter_test/flutter_test.dart';

MovimientoHistorial m(TipoMovimientoHistorial tipo, int id,
        {bool fiado = false}) =>
    MovimientoHistorial(
        tipo: tipo,
        id: id,
        monto: 1000,
        fecha: DateTime(2026, 10, 12, 10),
        usuarioId: 1,
        esFiado: fiado);

void main() {
  final lista = [
    m(TipoMovimientoHistorial.venta, 1),
    m(TipoMovimientoHistorial.venta, 2, fiado: true),
    m(TipoMovimientoHistorial.gasto, 3),
  ];

  test('cada filtro deja lo suyo', () {
    expect(filtrarPorTipo(lista, FiltroTipo.todo).map((x) => x.id), [1, 2, 3]);
    expect(filtrarPorTipo(lista, FiltroTipo.contado).map((x) => x.id), [1]);
    expect(filtrarPorTipo(lista, FiltroTipo.fiado).map((x) => x.id), [2]);
    expect(filtrarPorTipo(lista, FiltroTipo.gastos).map((x) => x.id), [3]);
  });
}
