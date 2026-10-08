import 'dart:async';

import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/repository_providers.dart';
import 'package:app_ventas/providers/sesion_provider.dart';
import 'package:app_ventas/repositories/inventario_repository.dart';
import 'package:app_ventas/repositories/producto_repository.dart';
import 'package:app_ventas/repositories/proveedor_repository.dart';
import 'package:app_ventas/screens/configuracion/producto_screen.dart';
import 'package:app_ventas/screens/configuracion/productos_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/montaje.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> montar(WidgetTester tester,
      {List<Override> overrides = const []}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final container = await containerConSesion(db, overrides: overrides);
    addTearDown(container.dispose);
    await tester.pumpWidget(
        appDePrueba(container, inicio: const ProductosScreen()));
    await tester.pumpAndSettle();
  }

  Future<int> crearArepa() => db.into(db.productos).insert(
        ProductosCompanion.insert(nombre: 'Arepa', precio: 3000),
      );

  Future<void> guardar(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const Key('boton_guardar_producto')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('boton_guardar_producto')));
    await tester.pumpAndSettle();
  }

  Future<void> agregarProveedor(
      WidgetTester tester, int proveedorId, String precio) async {
    await tester.ensureVisible(find.byKey(const Key('boton_agregar_proveedor')));
    await tester.tap(find.byKey(const Key('boton_agregar_proveedor')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('opcion_proveedor_$proveedorId')));
    await tester.enterText(find.byKey(const Key('campo_precio_compra')), precio);
    await tester.tap(find.byKey(const Key('boton_agregar_proveedor_producto')));
    await tester.pumpAndSettle();
  }

  testWidgets('sin productos muestra el estado vacío', (tester) async {
    await montar(tester);
    expect(find.text('Aún no tienes productos'), findsOneWidget);
  });

  testWidgets('crear un producto lo agrega sin costo y lo confirma',
      (tester) async {
    await montar(tester);

    await tester.tap(find.byKey(const Key('boton_agregar_producto')));
    await tester.pumpAndSettle();
    expect(find.text('Nuevo producto'), findsOneWidget);
    await tester.enterText(
        find.byKey(const Key('campo_nombre_producto')), 'Arepa');
    await tester.enterText(
        find.byKey(const Key('campo_precio_producto')), '3.000');
    expect(find.text('Sin costo: agrega un proveedor para ver la ganancia'),
        findsOneWidget);
    await guardar(tester);

    expect(find.byType(ProductoScreen), findsNothing);
    expect(find.text('Arepa'), findsOneWidget);
    expect(find.text(r'$3.000 · sin costo'), findsOneWidget);
    expect(find.text('Producto guardado'), findsOneWidget);
  });

  testWidgets('un precio inválido muestra error y no guarda', (tester) async {
    await montar(tester);

    await tester.tap(find.byKey(const Key('boton_agregar_producto')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('campo_nombre_producto')), 'Arepa');
    await tester.enterText(
        find.byKey(const Key('campo_precio_producto')), '2.5');
    await guardar(tester);

    expect(find.text('Escribe un precio válido'), findsOneWidget);
    expect(await db.select(db.productos).get(), isEmpty);
  });

  testWidgets('editar un producto cambia nombre y precio', (tester) async {
    final id = await crearArepa();
    await montar(tester);

    await tester.tap(find.byKey(Key('producto_item_$id')));
    await tester.pumpAndSettle();
    expect(find.text('Editar producto'), findsOneWidget);
    await tester.enterText(
        find.byKey(const Key('campo_nombre_producto')), 'Arepa rellena');
    await tester.enterText(
        find.byKey(const Key('campo_precio_producto')), '3.500');
    await guardar(tester);

    final producto = await db.select(db.productos).getSingle();
    expect(producto.nombre, 'Arepa rellena');
    expect(producto.precio, 3500);
    expect(find.text(r'$3.500 · sin costo'), findsOneWidget);
  });

  testWidgets(
      'dos proveedores: el primero queda preferido y se puede cambiar',
      (tester) async {
    final proveedores = ProveedorRepository(db);
    final postobon = await proveedores.crear(nombre: 'Postobón');
    final alpina = await proveedores.crear(nombre: 'Alpina');
    await montar(tester);

    await tester.tap(find.byKey(const Key('boton_agregar_producto')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('campo_nombre_producto')), 'Arepa');
    await tester.enterText(
        find.byKey(const Key('campo_precio_producto')), '3.500');
    await agregarProveedor(tester, postobon, '2.500');
    await agregarProveedor(tester, alpina, '2.300');
    expect(find.text(r'Costo $2.500 · Ganas $1.000 por unidad (29 %)'),
        findsOneWidget);

    await tester.tap(find.byKey(Key('preferido_$alpina')));
    await tester.pump();
    expect(find.text(r'Costo $2.300 · Ganas $1.200 por unidad (34 %)'),
        findsOneWidget);
    await guardar(tester);

    final id = (await db.select(db.productos).getSingle()).id;
    expect(await ProductoRepository(db).costoDe(id), 2300);
    expect(find.text(r'$3.500 · gana $1.200'), findsOneWidget);
  });

  testWidgets('quitar el preferido deja preferido al otro', (tester) async {
    final proveedores = ProveedorRepository(db);
    final postobon = await proveedores.crear(nombre: 'Postobón');
    final alpina = await proveedores.crear(nombre: 'Alpina');
    await montar(tester);

    await tester.tap(find.byKey(const Key('boton_agregar_producto')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('campo_nombre_producto')), 'Arepa');
    await tester.enterText(
        find.byKey(const Key('campo_precio_producto')), '3.500');
    await agregarProveedor(tester, postobon, '2.500');
    await agregarProveedor(tester, alpina, '2.300');
    await tester.tap(find.byKey(Key('quitar_proveedor_$postobon')));
    await tester.pump();
    await guardar(tester);

    final id = (await db.select(db.productos).getSingle()).id;
    final lista = await ProductoRepository(db).proveedoresDe(id);
    expect(lista.single.proveedorId, alpina);
    expect(lista.single.preferido, isTrue);
  });

  testWidgets('un costo mayor que el precio avisa la pérdida',
      (tester) async {
    final postobon = await ProveedorRepository(db).crear(nombre: 'Postobón');
    await montar(tester);

    await tester.tap(find.byKey(const Key('boton_agregar_producto')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('campo_nombre_producto')), 'Arepa');
    await tester.enterText(
        find.byKey(const Key('campo_precio_producto')), '2.000');
    await agregarProveedor(tester, postobon, '2.500');

    expect(find.text('Este producto se vende con pérdida'), findsOneWidget);
  });

  testWidgets('agregar un proveedor nuevo desde el producto', (tester) async {
    await montar(tester);

    await tester.tap(find.byKey(const Key('boton_agregar_producto')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('campo_nombre_producto')), 'Avena');
    await tester.enterText(
        find.byKey(const Key('campo_precio_producto')), '2.000');
    await tester.ensureVisible(find.byKey(const Key('boton_agregar_proveedor')));
    await tester.tap(find.byKey(const Key('boton_agregar_proveedor')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('campo_nuevo_proveedor')), 'Alpina');
    await tester.enterText(
        find.byKey(const Key('campo_precio_compra')), '1.500');
    await tester.tap(find.byKey(const Key('boton_agregar_proveedor_producto')));
    await tester.pumpAndSettle();
    await guardar(tester);

    expect((await db.select(db.proveedores).getSingle()).nombre, 'Alpina');
    final id = (await db.select(db.productos).getSingle()).id;
    expect(await ProductoRepository(db).costoDe(id), 1500);
  });

  testWidgets('desactivar lo pasa a Inactivos y reactivar lo devuelve',
      (tester) async {
    final id = await crearArepa();
    await montar(tester);

    await tester.tap(find.byKey(Key('boton_desactivar_$id')));
    await tester.pumpAndSettle();
    expect(find.byKey(Key('producto_inactivo_$id')), findsOneWidget);

    await tester.tap(find.byKey(Key('boton_reactivar_$id')));
    await tester.pumpAndSettle();
    expect(find.byKey(Key('producto_item_$id')), findsOneWidget);
  });

  testWidgets('un doble toque en Guardar cierra solo la pantalla del producto',
      (tester) async {
    final id = await crearArepa();
    final guardado = Completer<void>();
    await montar(tester, overrides: [
      productoRepositoryProvider
          .overrideWith((ref) => _ProductoRepositoryLento(db, guardado.future)),
    ]);

    await tester.tap(find.byKey(Key('producto_item_$id')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('boton_guardar_producto')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('boton_guardar_producto')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('boton_guardar_producto')),
        warnIfMissed: false);
    await tester.pump();
    guardado.complete();
    await tester.pumpAndSettle();

    expect(find.byType(ProductoScreen), findsNothing);
    expect(find.byType(ProductosScreen), findsOneWidget);
  });
  testWidgets(
      'mientras cargan los proveedores no se puede guardar ni agregar',
      (tester) async {
    final postobon = await ProveedorRepository(db).crear(nombre: 'Postobón');
    final id = await ProductoRepository(db).guardarProducto(
      nombre: 'Arepa',
      precio: 3500,
      proveedores: [
        ProveedorDeProducto(
            proveedorId: postobon, precioCompra: 2500, preferido: true),
      ],
    );
    final carga = Completer<void>();
    await montar(tester, overrides: [
      productoRepositoryProvider
          .overrideWith((ref) => _ProductoRepositoryCargaLenta(db, carga.future)),
    ]);

    await tester.tap(find.byKey(Key('producto_item_$id')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('boton_guardar_producto')));
    await tester.tap(find.byKey(const Key('boton_guardar_producto')),
        warnIfMissed: false);
    await tester.pump();

    expect(find.byType(ProductoScreen), findsOneWidget);
    expect(
        tester
            .widget<TextButton>(find.byKey(const Key('boton_agregar_proveedor')))
            .onPressed,
        isNull);
    expect(await ProductoRepository(db).costoDe(id), 2500);

    carga.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(Key('fila_proveedor_$postobon')), findsOneWidget);
  });

  testWidgets('activar el control pide cuántas hay y el mínimo',
      (tester) async {
    await montar(tester);

    await tester.tap(find.byKey(const Key('boton_agregar_producto')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('campo_nombre_producto')), 'Arepa');
    await tester.enterText(
        find.byKey(const Key('campo_precio_producto')), '3.500');
    await tester.ensureVisible(find.byKey(const Key('interruptor_existencias')));
    await tester.tap(find.byKey(const Key('interruptor_existencias')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('campo_hay_ahora')), '20');
    await tester.enterText(find.byKey(const Key('campo_minimo')), '5');
    await guardar(tester);

    final p = await db.select(db.productos).getSingle();
    expect(p.controlaExistencias, isTrue);
    expect(p.minimo, 5);
    expect(await InventarioRepository(db).existencias(p.id), 20);
  });

  testWidgets('sin "Hay ahora" no deja activar el control', (tester) async {
    await montar(tester);

    await tester.tap(find.byKey(const Key('boton_agregar_producto')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('campo_nombre_producto')), 'Arepa');
    await tester.enterText(
        find.byKey(const Key('campo_precio_producto')), '3.500');
    await tester.ensureVisible(find.byKey(const Key('interruptor_existencias')));
    await tester.tap(find.byKey(const Key('interruptor_existencias')));
    await tester.pumpAndSettle();
    await guardar(tester);

    expect(find.text('Escribe cuántas hay'), findsOneWidget);
    expect(await db.select(db.productos).get(), isEmpty);
  });

  testWidgets('con control muestra existencias, cambia el mínimo y desactiva',
      (tester) async {
    final id = await crearArepa();
    final container = await containerConSesion(db, nombre: 'Beto');
    final beto = container.read(sesionProvider).usuarioActivo!;
    container.dispose();
    await InventarioRepository(db)
        .activarControl(id, cantidad: 12, minimo: 3, por: beto);
    await montar(tester);

    await tester.tap(find.byKey(Key('producto_item_$id')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('interruptor_existencias')));
    expect(find.text('Hay 12 u'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('campo_minimo')), '4');
    await guardar(tester);
    expect((await db.select(db.productos).getSingle()).minimo, 4);

    await tester.tap(find.byKey(Key('producto_item_$id')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('interruptor_existencias')));
    await tester.tap(find.byKey(const Key('interruptor_existencias')));
    await tester.pumpAndSettle();
    expect(find.text('¿Dejar de controlar existencias?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirmar_dejar_de_controlar')));
    await tester.pumpAndSettle();
    await guardar(tester);

    expect((await db.select(db.productos).getSingle()).controlaExistencias,
        isFalse);
  });

  testWidgets('si activar el control falla, reintentar no duplica el producto',
      (tester) async {
    await montar(tester, overrides: [
      inventarioRepositoryProvider
          .overrideWith((ref) => _InventarioQueFallaUnaVez(db)),
    ]);

    await tester.tap(find.byKey(const Key('boton_agregar_producto')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('campo_nombre_producto')), 'Arepa');
    await tester.enterText(
        find.byKey(const Key('campo_precio_producto')), '3.500');
    await tester.ensureVisible(find.byKey(const Key('interruptor_existencias')));
    await tester.tap(find.byKey(const Key('interruptor_existencias')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('campo_hay_ahora')), '20');
    await guardar(tester);

    expect(find.text('No se pudo guardar, intenta de nuevo'), findsOneWidget);
    expect(find.byType(ProductoScreen), findsOneWidget);

    await guardar(tester);

    expect(find.byType(ProductoScreen), findsNothing);
    final productos = await db.select(db.productos).get();
    expect(productos, hasLength(1));
    expect(productos.single.controlaExistencias, isTrue);
  });

  testWidgets('pedir hasta se guarda, se borra y no puede ser menor al mínimo',
      (tester) async {
    await montar(tester);

    await tester.tap(find.byKey(const Key('boton_agregar_producto')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('campo_nombre_producto')), 'Arepa');
    await tester.enterText(
        find.byKey(const Key('campo_precio_producto')), '3.500');
    await tester.ensureVisible(find.byKey(const Key('interruptor_existencias')));
    await tester.tap(find.byKey(const Key('interruptor_existencias')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('campo_hay_ahora')), '2');
    await tester.enterText(find.byKey(const Key('campo_minimo')), '5');
    await tester.enterText(find.byKey(const Key('campo_pedir_hasta')), '3');
    await guardar(tester);

    expect(find.text('Debe ser mayor o igual que el mínimo'), findsOneWidget);
    expect(await db.select(db.productos).get(), isEmpty);

    await tester.enterText(find.byKey(const Key('campo_pedir_hasta')), '24');
    await guardar(tester);
    final producto = await db.select(db.productos).getSingle();
    expect(producto.pedirHasta, 24);

    await tester.tap(find.byKey(Key('producto_item_${producto.id}')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('campo_pedir_hasta')));
    await tester.enterText(find.byKey(const Key('campo_pedir_hasta')), '');
    await guardar(tester);
    expect((await db.select(db.productos).getSingle()).pedirHasta, isNull);
  });

  testWidgets('subir el mínimo por encima de pedir hasta muestra el error',
      (tester) async {
    final id = await crearArepa();
    final container = await containerConSesion(db, nombre: 'Beto');
    final beto = container.read(sesionProvider).usuarioActivo!;
    container.dispose();
    final inv = InventarioRepository(db);
    await inv.activarControl(id, cantidad: 10, minimo: 3, por: beto);
    await inv.cambiarPedirHasta(id, 12);
    await montar(tester);

    await tester.tap(find.byKey(Key('producto_item_$id')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('campo_minimo')));
    await tester.enterText(find.byKey(const Key('campo_minimo')), '15');
    await guardar(tester);

    expect(find.text('Debe ser mayor o igual que el mínimo'), findsOneWidget);
    final p = await db.select(db.productos).getSingle();
    expect((p.minimo, p.pedirHasta), (3, 12));
  });

  testWidgets('editar el precio de compra conserva el preferido',
      (tester) async {
    final postobon = await ProveedorRepository(db).crear(nombre: 'Postobón');
    final id = await ProductoRepository(db).guardarProducto(
      nombre: 'Coca',
      precio: 1500,
      proveedores: [
        ProveedorDeProducto(
            proveedorId: postobon, precioCompra: 900, preferido: true),
      ],
    );
    await montar(tester);

    await tester.tap(find.byKey(Key('producto_item_$id')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('editar_proveedor_$postobon')));
    await tester.pumpAndSettle();
    expect(find.text('900'), findsOneWidget);
    await tester.enterText(
        find.byKey(const Key('campo_precio_compra')), '1.000');
    await tester.tap(find.byKey(const Key('boton_guardar_precio_compra')));
    await tester.pumpAndSettle();
    await guardar(tester);

    final vinculo = (await ProductoRepository(db).proveedoresDe(id)).single;
    expect((vinculo.precioCompra, vinculo.preferido), (1000, true));
  });

  testWidgets('cancelar el producto no deja creado el proveedor nuevo',
      (tester) async {
    await montar(tester);

    await tester.tap(find.byKey(const Key('boton_agregar_producto')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('boton_agregar_proveedor')));
    await tester.tap(find.byKey(const Key('boton_agregar_proveedor')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('campo_nuevo_proveedor')), 'Alpina');
    await tester.enterText(
        find.byKey(const Key('campo_precio_compra')), '1.500');
    await tester.tap(find.byKey(const Key('boton_agregar_proveedor_producto')));
    await tester.pumpAndSettle();
    expect(find.text('Alpina'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(await db.select(db.proveedores).get(), isEmpty);
  });

  testWidgets('un nombre nuevo igual a uno existente usa ese proveedor',
      (tester) async {
    final alpina = await ProveedorRepository(db).crear(nombre: 'Alpina');
    await montar(tester);

    await tester.tap(find.byKey(const Key('boton_agregar_producto')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('campo_nombre_producto')), 'Avena');
    await tester.enterText(
        find.byKey(const Key('campo_precio_producto')), '2.000');
    await tester.ensureVisible(find.byKey(const Key('boton_agregar_proveedor')));
    await tester.tap(find.byKey(const Key('boton_agregar_proveedor')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('campo_nuevo_proveedor')), ' alpina ');
    await tester.enterText(
        find.byKey(const Key('campo_precio_compra')), '1.500');
    await tester.tap(find.byKey(const Key('boton_agregar_proveedor_producto')));
    await tester.pumpAndSettle();
    await guardar(tester);

    expect(await db.select(db.proveedores).get(), hasLength(1));
    final id = (await db.select(db.productos).getSingle()).id;
    expect((await ProductoRepository(db).proveedoresDe(id)).single.proveedorId,
        alpina);
  });

  testWidgets('un nombre igual a un proveedor desactivado pide reactivarlo',
      (tester) async {
    final alpina = await ProveedorRepository(db).crear(nombre: 'Alpina');
    await ProveedorRepository(db).desactivar(alpina);
    await montar(tester);

    await tester.tap(find.byKey(const Key('boton_agregar_producto')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('boton_agregar_proveedor')));
    await tester.tap(find.byKey(const Key('boton_agregar_proveedor')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('campo_nuevo_proveedor')), 'ALPINA');
    await tester.enterText(
        find.byKey(const Key('campo_precio_compra')), '1.500');
    await tester.tap(find.byKey(const Key('boton_agregar_proveedor_producto')));
    await tester.pumpAndSettle();

    expect(find.text('Alpina está desactivado: reactívalo en Proveedores'),
        findsOneWidget);
    expect(await db.select(db.proveedores).get(), hasLength(1));
  });

  testWidgets('no se agrega dos veces el mismo proveedor nuevo',
      (tester) async {
    await montar(tester);

    await tester.tap(find.byKey(const Key('boton_agregar_producto')));
    await tester.pumpAndSettle();
    for (final nombre in ['Alpina', 'ALPINA']) {
      await tester.ensureVisible(
          find.byKey(const Key('boton_agregar_proveedor')));
      await tester.tap(find.byKey(const Key('boton_agregar_proveedor')));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const Key('campo_nuevo_proveedor')), nombre);
      await tester.enterText(
          find.byKey(const Key('campo_precio_compra')), '1.500');
      await tester.tap(
          find.byKey(const Key('boton_agregar_proveedor_producto')));
      await tester.pumpAndSettle();
    }

    expect(find.text('Ese proveedor ya está en el producto'), findsOneWidget);
  });

  testWidgets('subir mínimo y "Pedir hasta" juntos se guarda', (tester) async {
    final id = await crearArepa();
    final container = await containerConSesion(db, nombre: 'Beto');
    final beto = container.read(sesionProvider).usuarioActivo!;
    container.dispose();
    final inv = InventarioRepository(db);
    await inv.activarControl(id, cantidad: 10, minimo: 3, por: beto);
    await inv.cambiarPedirHasta(id, 12);
    await montar(tester);

    await tester.tap(find.byKey(Key('producto_item_$id')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('campo_minimo')));
    await tester.enterText(find.byKey(const Key('campo_minimo')), '15');
    await tester.enterText(find.byKey(const Key('campo_pedir_hasta')), '20');
    await guardar(tester);

    final p = await db.select(db.productos).getSingle();
    expect((p.minimo, p.pedirHasta), (15, 20));
  });
}

/// Demora la carga de proveedores de un producto hasta [_espera].
class _ProductoRepositoryCargaLenta extends ProductoRepository {
  _ProductoRepositoryCargaLenta(super.db, this._espera);

  final Future<void> _espera;

  @override
  Future<List<ProductoProveedor>> proveedoresDe(int productoId) async {
    await _espera;
    return super.proveedoresDe(productoId);
  }
}


/// Espera a [_espera] antes de guardar, para simular la latencia de la base.
class _ProductoRepositoryLento extends ProductoRepository {
  _ProductoRepositoryLento(super.db, this._espera);

  final Future<void> _espera;

  @override
  Future<int> guardarProducto({
    int? id,
    required String nombre,
    required int precio,
    List<ProveedorDeProducto> proveedores = const [],
  }) async {
    await _espera;
    return super.guardarProducto(
        id: id, nombre: nombre, precio: precio, proveedores: proveedores);
  }
}

/// Falla la primera vez que activa el control, como un error de la base.
class _InventarioQueFallaUnaVez extends InventarioRepository {
  _InventarioQueFallaUnaVez(super.db);

  bool _fallo = false;

  @override
  Future<void> activarControl(
    int productoId, {
    required int cantidad,
    required int minimo,
    required Usuario por,
  }) async {
    if (!_fallo) {
      _fallo = true;
      throw Exception('falla de la base');
    }
    return super.activarControl(productoId,
        cantidad: cantidad, minimo: minimo, por: por);
  }
}
