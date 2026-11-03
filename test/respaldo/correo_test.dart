import 'package:app_ventas/respaldo/correo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('correoNormalizado', () {
    test('acepta un correo común', () {
      expect(correoNormalizado('tienda@gmail.com'), 'tienda@gmail.com');
      expect(
        correoNormalizado('don.jose+1@correo.com.co'),
        'don.jose+1@correo.com.co',
      );
    });

    test('recorta espacios y pasa a minúsculas', () {
      expect(correoNormalizado('  Tienda@Gmail.COM '), 'tienda@gmail.com');
    });

    test('rechaza lo vacío o solo espacios', () {
      expect(correoNormalizado(''), isNull);
      expect(correoNormalizado('   '), isNull);
    });

    test('rechaza sin arroba o con dos arrobas', () {
      expect(correoNormalizado('tiendagmail.com'), isNull);
      expect(correoNormalizado('tienda@@gmail.com'), isNull);
      expect(correoNormalizado('a@b@gmail.com'), isNull);
    });

    test('rechaza sin usuario o sin dominio', () {
      expect(correoNormalizado('@gmail.com'), isNull);
      expect(correoNormalizado('tienda@'), isNull);
      expect(correoNormalizado('tienda@gmail'), isNull);
      expect(correoNormalizado('tienda@.com'), isNull);
      expect(correoNormalizado('tienda@gmail.'), isNull);
      expect(correoNormalizado('tienda@gmail..com'), isNull);
    });

    test('rechaza espacios en medio', () {
      expect(correoNormalizado('mi tienda@gmail.com'), isNull);
      expect(correoNormalizado('tienda@g mail.com'), isNull);
    });

    test('acepta un usuario de una letra', () {
      expect(correoNormalizado('a@gmail.com'), 'a@gmail.com');
    });
  });

  group('correoEnmascarado', () {
    test('deja ver las dos primeras letras del usuario', () {
      expect(correoEnmascarado('oscar@gmail.com'), 'os***@gmail.com');
      expect(correoEnmascarado('ose@gmail.com'), 'os***@gmail.com');
    });

    test('con un usuario corto deja ver solo una letra', () {
      expect(correoEnmascarado('os@gmail.com'), 'o***@gmail.com');
      expect(correoEnmascarado('a@gmail.com'), 'a***@gmail.com');
    });

    test('sin arroba o sin usuario devuelve el texto tal cual', () {
      expect(correoEnmascarado('sinarroba'), 'sinarroba');
      expect(correoEnmascarado('@gmail.com'), '@gmail.com');
    });
  });
}
