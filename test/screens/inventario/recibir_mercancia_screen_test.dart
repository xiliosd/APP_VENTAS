import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/sesion_provider.dart';
import 'package:app_ventas/repositories/inventario_repository.dart';
import 'package:app_ventas/repositories/producto_repository.dart';
import 'package:app_ventas/repositories/proveedor_repository.dart';
import 'package:app_ventas/screens/inventario/recibir_mercancia_screen.dart';
import 'package:app_ventas/ui/boton_principal.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/montaje.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  bool guardarHabilitado(WidgetTester tester) =>
      tester
          .widget<BotonPrincipal>(find.byKey(const Key('boton_guardar_recibir')))
          .onPressed !=
      null;

  testWidgets('recibir de punta a punta suma existencias y actualiza el costo',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final container = await containerConSesion(db);
    addTearDown(container.dispose);
    final ana = container.read(sesionProvider).usuarioActivo!;
    final postobon = await ProveedorRepository(db).crear(nombre: 'Postobón');
    final arepa = await ProductoRepository(db).guardarProducto(
      nombre: 'Arepa',
      precio: 3500,
      proveedores: [
        ProveedorDeProducto(
            proveedorId: postobon, precioCompra: 2500, preferido: true),
      ],
    );
    await InventarioRepository(db, reloj: () => DateTime(2026, 10, 7, 8))
        .activarControl(arepa, cantidad: 5, minimo: 2, por: ana);
    int? devuelto;
    await tester.pumpWidget(appDePrueba(
      container,
      inicio: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              devuelto = await Navigator.of(context).push<int>(
                  MaterialPageRoute(
                      builder: (_) => const RecibirMercanciaScreen()));
            },
            child: const Text('abrir'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(guardarHabilitado(tester), isFalse);

    await tester.tap(find.byKey(Key('opcion_proveedor_recibir_$postobon')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('boton_agregar_producto_recibir')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('campo_buscar_producto')), 'are');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('opcion_producto_recibir_$arepa')));
    await tester.pumpAndSettle();

    expect(
        tester
            .widget<TextField>(find.byKey(Key('precio_recibir_$arepa')))
            .controller!
            .text,
        '2500');
    await tester.tap(find.byKey(Key('sumar_recibir_$arepa')));
    await tester.tap(find.byKey(Key('sumar_recibir_$arepa')));
    await tester.enterText(
        find.byKey(Key('precio_recibir_$arepa')), '2.600');
    await tester.pumpAndSettle();
    expect(find.text(r'Total $7.800'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('boton_guardar_recibir')));
    await tester.tap(find.byKey(const Key('boton_guardar_recibir')));
    await tester.pumpAndSettle();

    expect(devuelto, 7800);
    expect(find.byType(RecibirMercanciaScreen), findsNothing);
    expect(await InventarioRepository(db).existencias(arepa), 8);
    expect(await ProductoRepository(db).costoDe(arepa), 2600);
  });

  testWidgets('sin precio sugerido no deja guardar hasta escribirlo',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final container = await containerConSesion(db);
    addTearDown(container.dispose);
    final alpina = await ProveedorRepository(db).crear(nombre: 'Alpina');
    final avena =
        await ProductoRepository(db).guardarProducto(nombre: 'Avena', precio: 2000);
    await tester.pumpWidget(
        appDePrueba(container, inicio: const RecibirMercanciaScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(Key('opcion_proveedor_recibir_$alpina')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('boton_agregar_producto_recibir')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('opcion_producto_recibir_$avena')));
    await tester.pumpAndSettle();
    expect(guardarHabilitado(tester), isFalse);

    await tester.enterText(find.byKey(Key('precio_recibir_$avena')), '1.500');
    await tester.pumpAndSettle();
    expect(guardarHabilitado(tester), isTrue);
  });

  Future<(int, int, int)> dosProveedores() async {
    final proveedores = ProveedorRepository(db);
    final postobon = await proveedores.crear(nombre: 'Postobón');
    final alpina = await proveedores.crear(nombre: 'Alpina');
    final arepa = await ProductoRepository(db).guardarProducto(
      nombre: 'Arepa',
      precio: 3500,
      proveedores: [
        ProveedorDeProducto(
            proveedorId: postobon, precioCompra: 2500, preferido: true),
        ProveedorDeProducto(
            proveedorId: alpina, precioCompra: 2800, preferido: false),
      ],
    );
    return (postobon, alpina, arepa);
  }

  Future<void> abrirRecibir(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final container = await containerConSesion(db);
    addTearDown(container.dispose);
    await tester.pumpWidget(
        appDePrueba(container, inicio: const RecibirMercanciaScreen()));
    await tester.pumpAndSettle();
  }

  String precio(WidgetTester tester, int producto) => tester
      .widget<TextField>(find.byKey(Key('precio_recibir_$producto')))
      .controller!
      .text;

  testWidgets('sin proveedor no se pueden agregar productos', (tester) async {
    await dosProveedores();
    await abrirRecibir(tester);

    expect(
        tester
            .widget<TextButton>(
                find.byKey(const Key('boton_agregar_producto_recibir')))
            .onPressed,
        isNull);
  });

  testWidgets('cambiar de proveedor vuelve a sugerir los precios no editados',
      (tester) async {
    final (postobon, alpina, arepa) = await dosProveedores();
    await abrirRecibir(tester);

    await tester.tap(find.byKey(Key('opcion_proveedor_recibir_$postobon')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('boton_agregar_producto_recibir')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('opcion_producto_recibir_$arepa')));
    await tester.pumpAndSettle();
    expect(precio(tester, arepa), '2500');

    await tester.tap(find.byKey(Key('opcion_proveedor_recibir_$alpina')));
    await tester.pumpAndSettle();
    expect(precio(tester, arepa), '2800');

    await tester.enterText(find.byKey(Key('precio_recibir_$arepa')), '2.700');
    await tester.tap(find.byKey(Key('opcion_proveedor_recibir_$postobon')));
    await tester.pumpAndSettle();
    expect(precio(tester, arepa), '2.700');
  });

  testWidgets('si el proveedor se desactivó, guardar avisa y no se cierra',
      (tester) async {
    final (postobon, _, arepa) = await dosProveedores();
    await abrirRecibir(tester);
    await tester.tap(find.byKey(Key('opcion_proveedor_recibir_$postobon')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('boton_agregar_producto_recibir')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('opcion_producto_recibir_$arepa')));
    await tester.pumpAndSettle();

    await ProveedorRepository(db).desactivar(postobon);
    await tester.ensureVisible(find.byKey(const Key('boton_guardar_recibir')));
    await tester.tap(find.byKey(const Key('boton_guardar_recibir')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('No se pudo guardar, intenta de nuevo'), findsOneWidget);
    expect(find.byType(RecibirMercanciaScreen), findsOneWidget);
    expect(await db.select(db.entradasMercancia).get(), isEmpty);
  });

  testWidgets('arranca con el proveedor y las líneas que recibe', (tester) async {
    final (postobon, alpina, arepa) = await dosProveedores();
    final proveedor = await (db.select(db.proveedores)
          ..where((p) => p.id.equals(postobon)))
        .getSingle();
    final producto = await (db.select(db.productos)
          ..where((p) => p.id.equals(arepa)))
        .getSingle();
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final container = await containerConSesion(db);
    addTearDown(container.dispose);
    await tester.pumpWidget(appDePrueba(container,
        inicio: RecibirMercanciaScreen(
          proveedorInicial: proveedor,
          lineasIniciales: [
            LineaInicial(producto: producto, cantidad: 6, precio: 2500),
          ],
        )));
    await tester.pumpAndSettle();

    expect(
        tester
            .widget<ChoiceChip>(
                find.byKey(Key('opcion_proveedor_recibir_$postobon')))
            .selected,
        isTrue);
    expect(find.text('6'), findsOneWidget);
    expect(precio(tester, arepa), '2500');
    expect(find.text(r'Total $15.000'), findsOneWidget);

    await tester.tap(find.byKey(Key('opcion_proveedor_recibir_$alpina')));
    await tester.pumpAndSettle();
    expect(precio(tester, arepa), '2800');
  });

  testWidgets('líneas iniciales sin precio toman el del proveedor que se elija',
      (tester) async {
    final (_, alpina, arepa) = await dosProveedores();
    final producto = await (db.select(db.productos)
          ..where((p) => p.id.equals(arepa)))
        .getSingle();
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final container = await containerConSesion(db);
    addTearDown(container.dispose);
    await tester.pumpWidget(appDePrueba(container,
        inicio: RecibirMercanciaScreen(
          lineasIniciales: [LineaInicial(producto: producto, cantidad: 3)],
        )));
    await tester.pumpAndSettle();
    expect(precio(tester, arepa), '');

    await tester.tap(find.byKey(Key('opcion_proveedor_recibir_$alpina')));
    await tester.pumpAndSettle();

    expect(precio(tester, arepa), '2800');
  });
}
