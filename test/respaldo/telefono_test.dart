import 'package:app_ventas/respaldo/telefono.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('telefonoE164 acepta celulares colombianos de 10 dígitos', () {
    expect(telefonoE164('3001234567'), '+573001234567');
    expect(telefonoE164(' 300 123 4567 '), '+573001234567');
  });

  test('telefonoE164 rechaza fijos, longitudes y letras', () {
    expect(telefonoE164('6011234567'), isNull);
    expect(telefonoE164('300123456'), isNull);
    expect(telefonoE164('30012345678'), isNull);
    expect(telefonoE164('300123456a'), isNull);
    expect(telefonoE164(''), isNull);
  });

  test('telefonoEnmascarado oculta el centro del número', () {
    expect(telefonoEnmascarado('+573001234567'), '+57 300 *** 4567');
    expect(telefonoEnmascarado('573001234567'), '+57 300 *** 4567');
  });
}
