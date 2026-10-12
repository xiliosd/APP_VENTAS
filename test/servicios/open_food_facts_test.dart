import 'dart:convert';
import 'dart:io';

import 'package:app_ventas/servicios/open_food_facts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late HttpServer servidor;
  late void Function(HttpRequest) responder;
  String? userAgent;
  String? ruta;

  setUp(() async {
    servidor = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    servidor.listen((r) {
      userAgent = r.headers.value('user-agent');
      ruta = r.uri.toString();
      responder(r);
    });
  });
  tearDown(() => servidor.close(force: true));

  OpenFoodFacts cliente({Duration limite = const Duration(seconds: 2)}) =>
      OpenFoodFacts(
          base: Uri.parse('http://127.0.0.1:${servidor.port}'), limite: limite);

  void json(Object cuerpo, {int estado = 200}) => responder = (r) {
        r.response
          ..statusCode = estado
          ..headers.contentType = ContentType.json
          ..write(jsonEncode(cuerpo))
          ..close();
      };

  test('una respuesta completa se traduce a DatosProducto', () async {
    json({
      'status': 1,
      'product': {
        'product_name': 'Coca-Cola',
        'product_name_es': 'Coca-Cola Original',
        'brands': 'Coca-Cola,FEMSA',
        'quantity': '1,5 L',
        'packaging_tags': ['en:plastic-bottle'],
        'categories_tags': ['en:beverages', 'en:sodas'],
      },
    });
    final d = (await cliente().buscar('7702535011072'))!;
    expect(d.nombre, 'Coca-Cola Original');
    expect(d.marca, 'Coca-Cola');
    expect(d.tamano, '1,5 L');
    expect(d.envase, 'botella_plastica');
    expect(d.tipo, 'bebidas');
    expect(userAgent, startsWith('VeciTienda/1.0'));
    expect(ruta, startsWith('/api/v2/product/7702535011072?fields='));
  });

  test('nombre en español vacío usa el general; campos vacíos son nulos',
      () async {
    json({
      'status': 1,
      'product': {'product_name': 'Avena', 'product_name_es': '', 'brands': ''},
    });
    final d = (await cliente().buscar('1'))!;
    expect(d.nombre, 'Avena');
    expect(d.marca, isNull);
    expect(d.tamano, isNull);
  });

  test('status 0, 404 y JSON dañado dan null', () async {
    json({'status': 0});
    expect(await cliente().buscar('1'), isNull);
    json({'status': 0}, estado: 404);
    expect(await cliente().buscar('1'), isNull);
    responder = (r) => r.response
      ..write('{no es json')
      ..close();
    expect(await cliente().buscar('1'), isNull);
  });

  test('si tarda más del límite da null', () async {
    responder = (r) async {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      r.response
        ..write('{}')
        ..close();
    };
    expect(
        await cliente(limite: const Duration(milliseconds: 100)).buscar('1'),
        isNull);
  });

  test('sin servidor da null', () async {
    final c = OpenFoodFacts(base: Uri.parse('http://127.0.0.1:1'));
    expect(await c.buscar('1'), isNull);
  });
}
