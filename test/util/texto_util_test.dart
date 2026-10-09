import 'package:app_ventas/util/texto_util.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('plural usa singular solo para 1', () {
    expect(plural(1, 'venta', 'ventas'), '1 venta');
    expect(plural(0, 'venta', 'ventas'), '0 ventas');
    expect(plural(3, 'cliente', 'clientes'), '3 clientes');
  });

  test('sinTildes quita tildes y mayúsculas pero conserva la ñ', () {
    expect(sinTildes('Café ÁRBOL Pingüino Ñame'), 'cafe arbol pinguino ñame');
  });
}
