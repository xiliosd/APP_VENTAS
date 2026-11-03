import 'package:app_ventas/util/id_global.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final formatoV7 = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );

  test('genera un UUID v7 en minúsculas', () {
    expect(generarIdGlobal(), matches(formatoV7));
  });

  test('10 000 ids seguidos no se repiten', () {
    final ids = {for (var i = 0; i < 10000; i++) generarIdGlobal()};
    expect(ids.length, 10000);
  });

  test('los ids seguidos quedan en el orden en que se crearon', () {
    // Muchos caen en el mismo milisegundo: el contador mantiene el orden.
    final ids = [for (var i = 0; i < 5000; i++) generarIdGlobal()];
    final ordenados = [...ids]..sort();
    expect(ordenados, ids);
  });

  test('empieza con la hora en milisegundos', () {
    final antes = DateTime.now().millisecondsSinceEpoch;
    final id = generarIdGlobal();
    final despues = DateTime.now().millisecondsSinceEpoch;
    final milisegundos = int.parse(
      id.replaceAll('-', '').substring(0, 12),
      radix: 16,
    );
    expect(milisegundos, inInclusiveRange(antes, despues));
  });
}
