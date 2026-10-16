import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/util/orden_productos.dart';
import 'package:flutter_test/flutter_test.dart';

Producto _p(int id, String nombre, {String? tamano}) => Producto(
  id: id,
  nombre: nombre,
  precio: 1000,
  activo: true,
  controlaExistencias: false,
  minimo: 0,
  tamano: tamano,
);

void main() {
  final productos = [
    _p(1, 'Ñame'),
    _p(2, 'arroz'),
    _p(3, 'Azúcar'),
    _p(4, 'Nube'),
    _p(5, 'Oso'),
    _p(6, 'Coca-Cola', tamano: '1,5 L'),
    _p(7, 'Coca-Cola', tamano: '400 ml'),
  ];

  List<int> ids(List<Producto> lista) => [for (final p in lista) p.id];

  test('A–Z ignora tildes y mayúsculas y pone la ñ entre la n y la o', () {
    expect(
      ids(ordenarProductos(productos, OrdenProductos.alfabetico)),
      [2, 3, 6, 7, 4, 1, 5],
    );
  });

  test('como los creé respeta el orden de creación', () {
    expect(
      ids(ordenarProductos(productos.reversed.toList(), OrdenProductos.creacion)),
      [1, 2, 3, 4, 5, 6, 7],
    );
  });

  test('más vendidos primero; sin ventas, en A–Z', () {
    expect(
      ids(
        ordenarProductos(
          productos,
          OrdenProductos.masVendidos,
          vendidos: {5: 3, 1: 10},
        ),
      ),
      [1, 5, 2, 3, 6, 7, 4],
    );
  });

  test('no cambia la lista recibida', () {
    final copia = [...productos];
    ordenarProductos(productos, OrdenProductos.alfabetico);
    expect(ids(productos), ids(copia));
  });
}
