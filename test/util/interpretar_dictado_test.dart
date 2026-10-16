import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/repositories/producto_repository.dart';
import 'package:app_ventas/util/interpretar_dictado.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late List<Producto> activos;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    final repo = ProductoRepository(db);
    Future<void> nuevo(String nombre, {String? marca, String? tamano}) =>
        repo.guardarProducto(
          nombre: nombre,
          precio: 1000,
          detalles: DetallesProducto(marca: marca, tamano: tamano),
        );
    await nuevo('Coca-Cola', tamano: '400 ml');
    await nuevo('Coca-Cola', tamano: '1,5 L');
    await nuevo('Pan');
    await nuevo('Pan tajado');
    await nuevo('Empanada');
    await nuevo('Leche', marca: 'Alpina');
    await nuevo('Huevos');
    final inactivo = await repo.guardarProducto(nombre: 'Tornillo', precio: 1);
    await repo.desactivarProducto(inactivo);
    activos = await (db.select(
      db.productos,
    )..where((p) => p.activo.equals(true))).get();
  });

  tearDown(() => db.close());

  List<(int, TipoParteDictada, String)> resumen(String dicho) => [
    for (final p in interpretarDictado(dicho, activos))
      (
        p.cantidad,
        p.tipo,
        [for (final o in p.opciones) '${o.nombre} ${o.tamano ?? ''}'.trim()]
            .join(' | '),
      ),
  ];

  test('quita el prefijo y separa por "y"', () {
    expect(resumen('vecitienda registra venta dos coca colas y un pan'), [
      (2, TipoParteDictada.dudosa, 'Coca-Cola 400 ml | Coca-Cola 1,5 L'),
      (1, TipoParteDictada.reconocida, 'Pan'),
    ]);
  });

  test('separa donde empieza una cantidad en palabra, sin "y"', () {
    expect(
      resumen('dos coca colas un pan'),
      resumen('dos coca colas y un pan'),
    );
  });

  test('entiende docenas y cifras', () {
    expect(resumen('media docena de huevos'), [
      (6, TipoParteDictada.reconocida, 'Huevos'),
    ]);
    expect(resumen('una docena de huevos'), [
      (12, TipoParteDictada.reconocida, 'Huevos'),
    ]);
    expect(resumen('3 panes'), [(3, TipoParteDictada.reconocida, 'Pan')]);
  });

  test('compara por inicio de palabra y desempata por nombre igual', () {
    // "pan" no halla Empanada; entre Pan y Pan tajado gana el nombre igual.
    expect(resumen('un pan'), [(1, TipoParteDictada.reconocida, 'Pan')]);
    expect(resumen('pan tajado'), [
      (1, TipoParteDictada.reconocida, 'Pan tajado'),
    ]);
  });

  test('ignora palabras vacías y usa marca y tamaño', () {
    expect(resumen('leche alpina por favor'), [
      (1, TipoParteDictada.reconocida, 'Leche'),
    ]);
    expect(resumen('coca cola de 400'), [
      (1, TipoParteDictada.reconocida, 'Coca-Cola 400 ml'),
    ]);
  });

  test('"y" dentro de un tamaño no parte el producto', () {
    final partes = interpretarDictado('coca cola de litro y medio', activos);
    expect(partes, hasLength(1));
  });

  test('el mismo producto dos veces suma la cantidad', () {
    expect(resumen('una coca cola 400 y otra coca cola 400'), [
      (2, TipoParteDictada.reconocida, 'Coca-Cola 400 ml'),
    ]);
  });

  test('una cantidad mal oída se limita a 99', () {
    expect(resumen('doscientos panes'), [
      (99, TipoParteDictada.reconocida, 'Pan'),
    ]);
  });

  test('lo que no existe o está inactivo no se encuentra', () {
    final partes = interpretarDictado('dos tornillos', activos);
    expect(partes.single.tipo, TipoParteDictada.noEncontrada);
    expect(partes.single.texto, 'tornillos');
    expect(partes.single.opciones, isEmpty);
  });

  test('vacío o solo el prefijo no da nada', () {
    expect(interpretarDictado('', activos), isEmpty);
    expect(interpretarDictado('VeciTienda, registra venta', activos), isEmpty);
  });

  group('cifras como las escribe el celular', () {
    test('una cifra a mitad de frase empieza otro producto', () {
      expect(resumen('2 cocas 3 panes'), [
        (2, TipoParteDictada.dudosa, 'Coca-Cola 400 ml | Coca-Cola 1,5 L'),
        (3, TipoParteDictada.reconocida, 'Pan'),
      ]);
    });

    test('un tamaño con unidad no parte el producto', () {
      expect(resumen('una coca cola 400 ml'), [
        (1, TipoParteDictada.reconocida, 'Coca-Cola 400 ml'),
      ]);
      expect(resumen('coca cola de 400'), [
        (1, TipoParteDictada.reconocida, 'Coca-Cola 400 ml'),
      ]);
    });

    test('entiende del veintiuno al veintinueve', () {
      expect(resumen('veinticinco panes'), [
        (25, TipoParteDictada.reconocida, 'Pan'),
      ]);
    });
  });

  group('palabras parecidas', () {
    test('palabras pegadas: "cocacolas" halla Coca-Cola', () {
      expect(resumen('dos cocacolas'), [
        (2, TipoParteDictada.dudosa, 'Coca-Cola 400 ml | Coca-Cola 1,5 L'),
      ]);
    });

    test('una letra distinta: "lece" y "guevos"', () {
      expect(resumen('una lece y tres guevos'), [
        (1, TipoParteDictada.reconocida, 'Leche'),
        (3, TipoParteDictada.reconocida, 'Huevos'),
      ]);
    });

    test('palabras de más: pregunta con lo más parecido', () {
      expect(resumen('una leche entera'), [
        (1, TipoParteDictada.dudosa, 'Leche'),
      ]);
    });

    test('ignora "dame", "regálame" y "quiero"', () {
      expect(resumen('dame un pan'), [(1, TipoParteDictada.reconocida, 'Pan')]);
      expect(resumen('regálame dos huevos'), [
        (2, TipoParteDictada.reconocida, 'Huevos'),
      ]);
      expect(resumen('quiero una leche'), [
        (1, TipoParteDictada.reconocida, 'Leche'),
      ]);
    });

    test('lo exacto gana a lo parecido', () {
      expect(resumen('un pan'), [(1, TipoParteDictada.reconocida, 'Pan')]);
    });

    test('las palabras cortas no se aproximan', () {
      expect(resumen('dos pin'), [(2, TipoParteDictada.noEncontrada, '')]);
    });

    test('si casi nada coincide no inventa', () {
      expect(resumen('un destornillador grande'), [
        (1, TipoParteDictada.noEncontrada, ''),
      ]);
    });
  });
}
