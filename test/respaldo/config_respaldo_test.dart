import 'package:app_ventas/respaldo/config_respaldo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sin --dart-define el respaldo no está configurado', () {
    expect(ConfigRespaldo.url, isEmpty);
    expect(ConfigRespaldo.configurado, isFalse);
  });
}
