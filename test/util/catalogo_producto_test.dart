import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/util/busqueda_producto.dart';
import 'package:app_ventas/util/catalogo_producto.dart';
import 'package:flutter_test/flutter_test.dart';

Producto _p({
  String nombre = 'Gaseosa',
  String? codigo,
  String? marca,
  String? tamano,
}) =>
    Producto(
      id: 1,
      nombre: nombre,
      precio: 1000,
      activo: true,
      controlaExistencias: false,
      minimo: 0,
      codigoBarras: codigo,
      marca: marca,
      tamano: tamano,
    );

void main() {
  group('tipoDesdeOff', () {
    test('bebidas, lácteos y desconocido', () {
      expect(tipoDesdeOff(['en:beverages', 'en:carbonated-drinks', 'en:sodas']),
          'bebidas');
      expect(tipoDesdeOff(['en:dairies', 'en:milks']), 'lacteos');
      expect(tipoDesdeOff(['en:something-else']), isNull);
      expect(tipoDesdeOff(const []), isNull);
    });
    test('licores gana sobre bebidas', () {
      expect(tipoDesdeOff(['en:beverages', 'en:alcoholic-beverages', 'en:beers']),
          'licores');
    });
  });

  group('envaseDesdeOff', () {
    test('plástico, lata y desconocido', () {
      expect(envaseDesdeOff(['en:plastic-bottle']), 'botella_plastica');
      expect(envaseDesdeOff(['en:pet-bottle']), 'botella_plastica');
      expect(envaseDesdeOff(['en:can']), 'lata');
      expect(envaseDesdeOff(['en:glass-bottle']), 'botella_vidrio');
      expect(envaseDesdeOff(['en:mystery']), isNull);
    });
  });

  test('nombres del catálogo', () {
    expect(nombreTipo('aseo_hogar'), 'Aseo del hogar');
    expect(nombreEnvase('caja'), 'Caja o tetrapak');
    expect(tiposProducto.length, 11);
    expect(envasesProducto.length, 9);
  });

  group('coincideBusqueda', () {
    test('nombre, marca y tamaño sin tildes; código exacto', () {
      final p = _p(nombre: 'Gaseosa Colombiana', codigo: '7702', marca: 'Postobón',
          tamano: '1,5 L');
      expect(coincideBusqueda(p, ''), isTrue);
      expect(coincideBusqueda(p, 'colombiana'), isTrue);
      expect(coincideBusqueda(p, '  postobon '), isTrue);
      expect(coincideBusqueda(p, '1,5'), isTrue);
      expect(coincideBusqueda(p, '7702'), isTrue);
      expect(coincideBusqueda(p, '770'), isFalse);
      expect(coincideBusqueda(p, 'pepsi'), isFalse);
    });
  });

  test('detalleProducto', () {
    expect(detalleProducto(_p(marca: 'Alpina', tamano: '1 L')), 'Alpina · 1 L');
    expect(detalleProducto(_p(marca: 'Alpina')), 'Alpina');
    expect(detalleProducto(_p(tamano: '1 L')), '1 L');
    expect(detalleProducto(_p()), isNull);
  });
}
