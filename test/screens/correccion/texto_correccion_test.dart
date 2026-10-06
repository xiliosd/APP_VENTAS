import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/screens/correccion/texto_correccion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Correccion correccion(TipoMovimiento tipo, AccionCorreccion accion) =>
      Correccion(
        id: 1,
        tipoMovimiento: tipo,
        movimientoId: 1,
        accion: accion,
        usuarioId: 1,
        fecha: DateTime(2026, 10, 6, 15, 40),
        antes: r'$5.000 · Contado · Efectivo',
      );

  test('una venta anulada va en femenino con la hora', () {
    expect(
        textoCorreccion(
            correccion(TipoMovimiento.venta, AccionCorreccion.anulado), 'Ana'),
        'Anulada por Ana · 15:40');
  });

  test('un gasto corregido va en masculino con el valor anterior', () {
    expect(
        textoCorreccion(
            correccion(TipoMovimiento.gasto, AccionCorreccion.corregido), 'Ana'),
        r'Corregido por Ana · antes: $5.000 · Contado · Efectivo');
  });

  test('un abono anulado va en masculino', () {
    expect(
        textoCorreccion(
            correccion(TipoMovimiento.abono, AccionCorreccion.anulado), 'Beto'),
        'Anulado por Beto · 15:40');
  });
}
