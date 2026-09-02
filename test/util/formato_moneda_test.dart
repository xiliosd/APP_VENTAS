import 'package:app_ventas/util/formato_moneda.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formatea montos con separador de miles y símbolo de pesos', () {
    expect(formatoMoneda(0), r'$0');
    expect(formatoMoneda(3000), r'$3.000');
    expect(formatoMoneda(1000000), r'$1.000.000');
    expect(formatoMoneda(999), r'$999');
  });
}
