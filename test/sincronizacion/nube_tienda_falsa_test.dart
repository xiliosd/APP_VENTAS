import 'package:app_ventas/sincronizacion/nube_tienda.dart';
import 'package:app_ventas/util/pin_hash.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/nube_tienda_falsa.dart';

void main() {
  late NubeTiendaFalsa nube;
  late String tienda;

  setUp(() async {
    nube = NubeTiendaFalsa();
    tienda = await nube.crearTienda('La Esquina');
  });

  CambioSubida cliente(String id, String nombre) => CambioSubida(
    tabla: 'clientes',
    idGlobal: id,
    datos: {'nombre': nombre},
    borrado: false,
  );

  test('crear la tienda dos veces devuelve la misma', () async {
    expect(await nube.crearTienda('Otra'), tienda);
    expect(await nube.miTienda(), tienda);
  });

  test('subir la misma fila deja una sola con versión mayor', () async {
    await nube.subir(tienda, [cliente('c1', 'Don Pedro')]);
    final primera = (await nube.bajar(tienda, desde: 0)).single.version;
    await nube.subir(tienda, [cliente('c1', 'Don Pedro P')]);

    final filas = await nube.bajar(tienda, desde: 0);
    expect(filas, hasLength(1));
    expect(filas.single.version, greaterThan(primera));
    expect(filas.single.datos!['nombre'], 'Don Pedro P');
  });

  test(
    'bajar trae solo lo posterior al cursor, en orden y con límite',
    () async {
      await nube.subir(tienda, [
        for (var i = 0; i < 5; i++) cliente('c$i', 'Cliente $i'),
      ]);
      final todas = await nube.bajar(tienda, desde: 0);
      final desdeSegunda = await nube.bajar(
        tienda,
        desde: todas[1].version,
        limite: 2,
      );

      expect(desdeSegunda.map((f) => f.idGlobal), ['c2', 'c3']);
    },
  );

  test('sin conexión lanza ErrorSinConexion', () async {
    nube.sinConexion = true;
    expect(
      () => nube.bajar(tienda, desde: 0),
      throwsA(isA<ErrorSinConexion>()),
    );
  });

  group('celulares de vendedores', () {
    late NubeTiendaFalsa celular;

    setUp(() async {
      await nube.subir(tienda, [
        const CambioSubida(
          tabla: 'usuarios',
          idGlobal: 'u-beto',
          datos: {
            'nombre': 'Beto',
            'rol': 'vendedor',
            'activo': 1,
            'numero_vendedor': 1,
          },
          borrado: false,
        ),
      ]);
      await nube.guardarPin(tienda, 'u-beto', '1234', 0);
      celular = nube.otroCelular();
      await celular.iniciarSesionCelular();
    });

    test('código, número o PIN malos dan la misma respuesta', () async {
      final codigo = await nube.codigoTienda(tienda);
      final respuestas = [
        await celular.solicitarIngreso('ZZZ999', 1, '1234', 'Redmi'),
        await celular.solicitarIngreso(codigo, 9, '1234', 'Redmi'),
        await celular.solicitarIngreso(codigo, 1, '0000', 'Redmi'),
      ];

      for (final respuesta in respuestas) {
        expect(respuesta.resultado, ResultadoPin.incorrecto);
        expect(respuesta.tiendaId, isNull);
      }
      expect(await celular.miMembresia(), isNull);
    });

    test('cinco PIN malos bloquean aunque luego llegue el bueno', () async {
      final codigo = await nube.codigoTienda(tienda);
      for (var i = 0; i < 5; i++) {
        await celular.solicitarIngreso(codigo, 1, '0000', 'Redmi');
      }

      final respuesta = await celular.solicitarIngreso(
        codigo,
        1,
        '1234',
        'Redmi',
      );

      expect(respuesta.resultado, ResultadoPin.bloqueado);
      expect(await celular.miMembresia(), isNull);
    });

    test('pedir entrada deja el celular esperando y sin datos', () async {
      final codigo = await nube.codigoTienda(tienda);

      final respuesta = await celular.solicitarIngreso(
        codigo.toLowerCase(),
        1,
        '1234',
        'Redmi',
      );

      expect(respuesta.resultado, ResultadoPin.ok);
      expect(respuesta.tiendaId, tienda);
      expect(respuesta.nombreVendedor, 'Beto');
      expect((await celular.miMembresia())!.estado, EstadoMiembro.pendiente);
      expect(await celular.bajar(tienda, desde: 0), isEmpty);
      expect((await nube.solicitudes(tienda)).single.nombreVendedor, 'Beto');
    });

    test('un PIN legado se acepta y no pisa uno ya guardado', () async {
      await nube.guardarPinLegado(tienda, 'u-ana', hashPin('4321'), 0);
      await nube.guardarPinLegado(tienda, 'u-beto', hashPin('9999'), 0);

      expect(await nube.verificarPin(tienda, 'u-ana', '4321'), ResultadoPin.ok);
      expect(
        await nube.verificarPin(tienda, 'u-beto', '1234'),
        ResultadoPin.ok,
      );
    });
  });

  test('las respuestas del servidor se leen bien', () {
    final solicitud = SolicitudIngreso.desdeJson({
      'resultado': 'ok',
      'tienda': 't1',
      'nombre_tienda': 'La Esquina',
      'nombre_vendedor': 'Beto',
    });
    expect(solicitud.resultado, ResultadoPin.ok);
    expect(solicitud.tiendaId, 't1');
    expect(
      SolicitudIngreso.desdeJson({'resultado': 'bloqueado'}).resultado,
      ResultadoPin.bloqueado,
    );

    final membresia = Membresia.desdeJson({
      'tienda': 't1',
      'rol': 'vendedor',
      'estado': 'revocado',
      'revocado_en': '2026-11-06T10:00:00+00:00',
      'usuario_id_global': 'u-beto',
    });
    expect(membresia.estado, EstadoMiembro.revocado);
    expect(membresia.esVendedor, isTrue);
    expect(membresia.revocadoEn, DateTime.utc(2026, 11, 6, 10));
  });
}
