import 'package:app_ventas/sincronizacion/nube_tienda.dart';
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
}
