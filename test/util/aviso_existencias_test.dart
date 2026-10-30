import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/util/aviso_existencias.dart';
import 'package:flutter_test/flutter_test.dart';

Producto producto(int id, String nombre) => Producto(
  id: id,
  nombre: nombre,
  precio: 1000,
  activo: true,
  controlaExistencias: true,
  minimo: 3,
);

void main() {
  final productos = {1: producto(1, 'Arroz'), 2: producto(2, 'Azúcar')};

  List<AvisoExistencias> calcular(Map<int, int> antes, Map<int, int> despues) =>
      productosQueCruzaron(
        antes: antes,
        despues: despues,
        productos: productos,
      );

  test('cruza al mínimo: de 5 a 3 avisa "Quedan 3 Arroz: toca pedir"', () {
    final avisos = calcular({1: 5}, {1: 3});
    expect(avisos.single.texto, 'Quedan 3 Arroz: toca pedir');
    expect(avisos.single.agotado, isFalse);
  });

  test(
    'llega a cero desde abajo del mínimo: de 2 a 0 avisa "Se agotó Arroz"',
    () {
      final avisos = calcular({1: 2}, {1: 0});
      expect(avisos.single.texto, 'Se agotó Arroz');
      expect(avisos.single.agotado, isTrue);
    },
  );

  test('ya estaba bajo el mínimo y sigue sobre cero: de 2 a 1 no avisa', () {
    expect(calcular({1: 2}, {1: 1}), isEmpty);
  });

  test('ya estaba en cero o negativo: de 0 a -1 no avisa', () {
    expect(calcular({1: 0}, {1: -1}), isEmpty);
  });

  test('sin control (no viene en despues) no avisa', () {
    expect(calcular({1: 5}, {}), isEmpty);
  });

  test('agotados primero y luego por nombre', () {
    final avisos = calcular({1: 5, 2: 1}, {1: 3, 2: 0});
    expect(avisos.map((a) => a.nombre), ['Azúcar', 'Arroz']);
  });
}
