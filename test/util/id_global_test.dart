import 'package:app_ventas/util/id_global.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final formatoV4 = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );

  test('genera un UUID v4 en minúsculas', () {
    expect(generarIdGlobal(), matches(formatoV4));
  });

  test('10 000 ids seguidos no se repiten', () {
    final ids = {for (var i = 0; i < 10000; i++) generarIdGlobal()};
    expect(ids.length, 10000);
  });
}
