import 'package:app_ventas/util/categorias_gasto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('poner categoría en descripción vacía o con texto', () {
    expect(aplicarCategoria('', 'Mercancía'), 'Mercancía');
    expect(aplicarCategoria('hielo', 'Mercancía'), 'Mercancía · hielo');
    expect(aplicarCategoria('  hielo ', 'Servicios'), 'Servicios · hielo');
  });

  test('cambiar de categoría reemplaza la anterior', () {
    expect(aplicarCategoria('Mercancía · hielo', 'Servicios'), 'Servicios · hielo');
    expect(aplicarCategoria('Mercancía', 'Arriendo'), 'Arriendo');
  });

  test('quitar la categoría deja el texto', () {
    expect(aplicarCategoria('Transporte · taxi', null), 'taxi');
    expect(aplicarCategoria('Transporte', null), '');
    expect(aplicarCategoria('taxi', null), 'taxi');
  });

  test('categoriaDe reconoce solo categorías al inicio', () {
    expect(categoriaDe('Mercancía · hielo'), 'Mercancía');
    expect(categoriaDe('Mercancía'), 'Mercancía');
    expect(categoriaDe('hielo'), isNull);
    expect(categoriaDe('Mercancías varias'), isNull);
  });
}
