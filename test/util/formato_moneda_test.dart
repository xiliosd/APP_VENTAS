import 'package:app_ventas/util/formato_moneda.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formatea montos con separador de miles y símbolo de pesos', () {
    expect(formatoMoneda(0), r'$0');
    expect(formatoMoneda(3000), r'$3.000');
    expect(formatoMoneda(1000000), r'$1.000.000');
    expect(formatoMoneda(999), r'$999');
  });

  test('parsearMonto acepta dígitos con o sin separador de miles y símbolo', () {
    expect(parsearMonto('3000'), 3000);
    expect(parsearMonto('3.000'), 3000);
    expect(parsearMonto(r'$3.000'), 3000);
    expect(parsearMonto(' 3 000 '), 3000);
  });

  test('parsearMonto rechaza texto, signos, decimales y vacío', () {
    expect(parsearMonto('abc'), isNull);
    expect(parsearMonto('-500'), isNull);
    expect(parsearMonto('12,5'), isNull);
    expect(parsearMonto(''), isNull);
  });
}
