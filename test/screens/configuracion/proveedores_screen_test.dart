import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/repositories/producto_repository.dart';
import 'package:app_ventas/repositories/proveedor_repository.dart';
import 'package:app_ventas/screens/configuracion/ajustes_screen.dart';
import 'package:app_ventas/screens/configuracion/proveedores_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/montaje.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> montar(WidgetTester tester,
      {Widget inicio = const ProveedoresScreen()}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final container = await containerConSesion(db);
    addTearDown(container.dispose);
    await tester.pumpWidget(appDePrueba(container, inicio: inicio));
    await tester.pumpAndSettle();
  }

  testWidgets('sin proveedores muestra el estado vacío', (tester) async {
    await montar(tester);
    expect(find.text('Aún no tienes proveedores'), findsOneWidget);
  });

  testWidgets('crear un proveedor lo agrega a la lista', (tester) async {
    await montar(tester);

    await tester.tap(find.byKey(const Key('boton_agregar_proveedor_nuevo')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('campo_nombre_proveedor')), 'Postobón');
    await tester.enterText(
        find.byKey(const Key('campo_telefono_proveedor')), '3001234567');
    await tester.tap(find.byKey(const Key('boton_guardar_proveedor')));
    await tester.pumpAndSettle();

    expect(find.text('Postobón'), findsOneWidget);
    expect(find.text('3001234567 · Surte 0 productos'), findsOneWidget);
    expect(find.text('Proveedor guardado'), findsOneWidget);
  });

  testWidgets('sin nombre no se guarda', (tester) async {
    await montar(tester);

    await tester.tap(find.byKey(const Key('boton_agregar_proveedor_nuevo')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('boton_guardar_proveedor')));
    await tester.pumpAndSettle();

    expect(find.text('Escribe un nombre'), findsOneWidget);
    expect(await db.select(db.proveedores).get(), isEmpty);
  });

  testWidgets('editar muestra los productos que surte y guarda cambios',
      (tester) async {
    final id = await ProveedorRepository(db).crear(nombre: 'Postobón');
    await ProductoRepository(db).guardarProducto(
      nombre: 'Coca',
      precio: 1200,
      proveedores: [
        ProveedorDeProducto(proveedorId: id, precioCompra: 900, preferido: true),
      ],
    );
    await montar(tester);
    expect(find.text('Surte 1 producto'), findsOneWidget);

    await tester.tap(find.byKey(Key('proveedor_item_$id')));
    await tester.pumpAndSettle();
    expect(find.text('Productos que surte'), findsOneWidget);
    expect(find.text(r'Coca · $900'), findsOneWidget);
    await tester.enterText(
        find.byKey(const Key('campo_notas_proveedor')), 'Viene los martes');
    await tester.tap(find.byKey(const Key('boton_guardar_proveedor')));
    await tester.pumpAndSettle();

    final p = await db.select(db.proveedores).getSingle();
    expect(p.notas, 'Viene los martes');
  });

  testWidgets('desactivar y reactivar', (tester) async {
    final id = await ProveedorRepository(db).crear(nombre: 'Postobón');
    await montar(tester);

    await tester.tap(find.byKey(Key('boton_desactivar_proveedor_$id')));
    await tester.pumpAndSettle();
    expect(find.byKey(Key('proveedor_inactivo_$id')), findsOneWidget);

    await tester.tap(find.byKey(Key('boton_reactivar_proveedor_$id')));
    await tester.pumpAndSettle();
    expect(find.byKey(Key('proveedor_item_$id')), findsOneWidget);
  });

  testWidgets('Ajustes tiene la entrada Proveedores', (tester) async {
    await montar(tester, inicio: const Scaffold(body: AjustesScreen()));

    await tester.tap(find.byKey(const Key('menu_proveedores')));
    await tester.pumpAndSettle();

    expect(find.byType(ProveedoresScreen), findsOneWidget);
  });

  testWidgets('un nombre repetido muestra el error y no se guarda',
      (tester) async {
    await ProveedorRepository(db).crear(nombre: 'Postobón');
    await montar(tester);

    await tester.tap(find.byKey(const Key('boton_agregar_proveedor_nuevo')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('campo_nombre_proveedor')), 'postobón');
    await tester.tap(find.byKey(const Key('boton_guardar_proveedor')));
    await tester.pumpAndSettle();

    expect(find.text('Ya existe un proveedor con ese nombre'), findsOneWidget);
    expect(await db.select(db.proveedores).get(), hasLength(1));
  });
}
