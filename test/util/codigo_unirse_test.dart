import 'package:app_ventas/sincronizacion/nube_tienda.dart';
import 'package:app_ventas/util/codigo_unirse.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('texto del QR', () {
    test('ida y vuelta con el código y el número', () {
      final texto = textoCodigoUnirse(codigo: 'ABC234', numero: 3);

      expect(texto, 'vecitienda:unirse:1:ABC234:3');
      expect(leerCodigoUnirse(texto), (codigo: 'ABC234', numero: 3));
    });

    test('acepta espacios alrededor y el código en minúsculas', () {
      expect(leerCodigoUnirse('  vecitienda:unirse:1:abc234:12 '), (
        codigo: 'ABC234',
        numero: 12,
      ));
    });

    for (final invalido in [
      '',
      'https://x.com',
      'vecitienda:unirse:2:ABC234:3',
      'vecitienda:unirse:1:ABC23:3',
      'vecitienda:unirse:1:ABCI34:3',
      'vecitienda:unirse:1:ABC234:0',
      'vecitienda:unirse:1:ABC234:x',
      'vecitienda:unirse:1:ABC234:3:extra',
    ]) {
      test('"$invalido" no es un código de VeciTienda', () {
        expect(leerCodigoUnirse(invalido), isNull);
      });
    }
  });

  group('celularesAReemplazar', () {
    CelularTienda celular(
      String auth, {
      String rol = 'vendedor',
      EstadoMiembro estado = EstadoMiembro.aprobado,
      String? idGlobal = 'beto',
    }) => CelularTienda(
      usuarioAuth: auth,
      rol: rol,
      estado: estado,
      solicitadoEn: DateTime(2026, 11, 20),
      usuarioIdGlobal: idGlobal,
    );

    test('solo el celular anterior aprobado del mismo vendedor', () {
      final reemplazar = celularesAReemplazar(
        [
          celular('viejo'),
          celular('pendiente', estado: EstadoMiembro.pendiente),
          celular('de-caro', idGlobal: 'caro'),
          celular('dueno', rol: 'admin', idGlobal: null),
          celular('nuevo'),
        ],
        idGlobal: 'beto',
        usuarioAuthNuevo: 'nuevo',
      );

      expect(reemplazar.map((c) => c.usuarioAuth), ['viejo']);
    });

    test('sin celular anterior no reemplaza nada', () {
      expect(
        celularesAReemplazar(
          [celular('nuevo')],
          idGlobal: 'beto',
          usuarioAuthNuevo: 'nuevo',
        ),
        isEmpty,
      );
    });
  });
}
