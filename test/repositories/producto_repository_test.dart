import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/repositories/producto_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late ProductoRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ProductoRepository(db);
  });

  tearDown(() => db.close());

  test('crearProducto queda activo por defecto y aparece en observarProductosActivos',
      () async {
    await repo.crearProducto(nombre: 'Arepa', precio: 3000);

    final activos = await repo.observarProductosActivos().first;
    expect(activos, hasLength(1));
    expect(activos.single.nombre, 'Arepa');
    expect(activos.single.precio, 3000);
    expect(activos.single.activo, isTrue);
  });

  test('desactivarProducto lo saca de observarProductosActivos pero sigue en listarTodos',
      () async {
    final id = await repo.crearProducto(nombre: 'Arepa', precio: 3000);
    await repo.desactivarProducto(id);

    expect(await repo.observarProductosActivos().first, isEmpty);
    expect(await repo.listarTodos(), hasLength(1));
  });

  test('actualizarProducto cambia nombre y precio', () async {
    final id = await repo.crearProducto(nombre: 'Arepa', precio: 3000);
    await repo.actualizarProducto(id, nombre: 'Arepa con queso', precio: 4000);

    final producto = (await repo.listarTodos()).single;
    expect(producto.nombre, 'Arepa con queso');
    expect(producto.precio, 4000);
  });

  test('reactivarProducto lo devuelve a activos y lo saca de inactivos',
      () async {
    final id = await repo.crearProducto(nombre: 'Arepa', precio: 3000);
    await repo.desactivarProducto(id);

    expect((await repo.observarProductosInactivos().first).single.id, id);
    expect(await repo.observarProductosActivos().first, isEmpty);

    await repo.reactivarProducto(id);

    expect((await repo.observarProductosActivos().first).single.id, id);
    expect(await repo.observarProductosInactivos().first, isEmpty);
  });

  group('código y detalles', () {
    test('guarda y lee los detalles; vacíos quedan nulos', () async {
      final repo = ProductoRepository(db);
      final id = await repo.guardarProducto(
        nombre: 'Coca-Cola',
        precio: 4500,
        detalles: const DetallesProducto(
          codigoBarras: ' 7702004003508\n',
          marca: 'Postobón ',
          tamano: '1,5 L',
          envase: 'botella_plastica',
          tipo: '  ',
        ),
      );
      final p = (await repo.productoPorCodigo('7702004003508'))!;
      expect(p.id, id);
      expect(p.marca, 'Postobón');
      expect(p.tamano, '1,5 L');
      expect(p.envase, 'botella_plastica');
      expect(p.tipo, isNull);
    });

    test('sin detalles, editar no borra los que había', () async {
      final repo = ProductoRepository(db);
      final id = await repo.guardarProducto(
          nombre: 'Pan',
          precio: 500,
          detalles: const DetallesProducto(marca: 'Bimbo'));
      await repo.guardarProducto(id: id, nombre: 'Pan tajado', precio: 600);
      final p = await (db.select(db.productos)..where((x) => x.id.equals(id)))
          .getSingle();
      expect(p.marca, 'Bimbo');
    });

    test('un código de otro producto activo no se puede repetir', () async {
      final repo = ProductoRepository(db);
      await repo.guardarProducto(
          nombre: 'Pan',
          precio: 500,
          detalles: const DetallesProducto(codigoBarras: '123'));
      expect(
        () => repo.guardarProducto(
            nombre: 'Leche',
            precio: 3000,
            detalles: const DetallesProducto(codigoBarras: '123')),
        throwsA(isA<CodigoRepetido>()
            .having((e) => e.nombre, 'nombre', 'Pan')),
      );
    });

    test('el mismo producto puede volver a guardar su código', () async {
      final repo = ProductoRepository(db);
      final id = await repo.guardarProducto(
          nombre: 'Pan',
          precio: 500,
          detalles: const DetallesProducto(codigoBarras: '123'));
      await repo.guardarProducto(
          id: id,
          nombre: 'Pan',
          precio: 600,
          detalles: const DetallesProducto(codigoBarras: '123'));
      expect((await repo.productoPorCodigo('123'))!.precio, 600);
    });

    test('un producto inactivo no bloquea su código', () async {
      final repo = ProductoRepository(db);
      final viejo = await repo.guardarProducto(
          nombre: 'Pan viejo',
          precio: 500,
          detalles: const DetallesProducto(codigoBarras: '123'));
      await repo.desactivarProducto(viejo);
      final nuevo = await repo.guardarProducto(
          nombre: 'Pan nuevo',
          precio: 600,
          detalles: const DetallesProducto(codigoBarras: '123'));
      expect((await repo.productoPorCodigo('123'))!.id, nuevo);
    });

    test('productoPorCodigo devuelve un inactivo si es el único', () async {
      final repo = ProductoRepository(db);
      final id = await repo.guardarProducto(
          nombre: 'Pan',
          precio: 500,
          detalles: const DetallesProducto(codigoBarras: '123'));
      await repo.desactivarProducto(id);
      final p = await repo.productoPorCodigo(' 123 ');
      expect(p!.activo, isFalse);
      expect(await repo.productoPorCodigo('999'), isNull);
    });

    test('marcasUsadas da las marcas de los activos sin repetir', () async {
      final repo = ProductoRepository(db);
      await repo.guardarProducto(
          nombre: 'A', precio: 1, detalles: const DetallesProducto(marca: 'Zenú'));
      await repo.guardarProducto(
          nombre: 'B', precio: 1, detalles: const DetallesProducto(marca: 'Alpina'));
      await repo.guardarProducto(
          nombre: 'C', precio: 1, detalles: const DetallesProducto(marca: 'Zenú'));
      final d = await repo.guardarProducto(
          nombre: 'D', precio: 1, detalles: const DetallesProducto(marca: 'Vieja'));
      await repo.desactivarProducto(d);
      expect(await repo.marcasUsadas(), ['Alpina', 'Zenú']);
    });
  });


  test('reactivar un producto cuyo código ya usa otro activo le quita el '
      'código y dice de quién es', () async {
    final repo = ProductoRepository(db);
    final viejo = await repo.guardarProducto(
        nombre: 'Coca vieja',
        precio: 500,
        detalles: const DetallesProducto(codigoBarras: '123'));
    await repo.desactivarProducto(viejo);
    final nuevo = await repo.guardarProducto(
        nombre: 'Coca nueva',
        precio: 600,
        detalles: const DetallesProducto(codigoBarras: '123'));
    expect(await repo.reactivarProducto(viejo), 'Coca nueva');
    final p = await (db.select(db.productos)..where((x) => x.id.equals(viejo)))
        .getSingle();
    expect(p.activo, isTrue);
    expect(p.codigoBarras, isNull);
    expect((await repo.productoPorCodigo('123'))!.id, nuevo);
  });

  test('reactivar sin conflicto conserva el código', () async {
    final repo = ProductoRepository(db);
    final id = await repo.guardarProducto(
        nombre: 'Pan',
        precio: 500,
        detalles: const DetallesProducto(codigoBarras: '123'));
    await repo.desactivarProducto(id);
    expect(await repo.reactivarProducto(id), isNull);
    expect((await repo.productoPorCodigo('123'))!.id, id);
  });

  test('los espacios dentro del código se quitan al guardar y al buscar',
      () async {
    final repo = ProductoRepository(db);
    final id = await repo.guardarProducto(
        nombre: 'Gaseosa',
        precio: 500,
        detalles: const DetallesProducto(codigoBarras: '7702 0040 03508'));
    expect((await repo.productoPorCodigo('7702004003508'))!.id, id);
    expect((await repo.productoPorCodigo(' 7702 004003508\n'))!.id, id);
  });
}
