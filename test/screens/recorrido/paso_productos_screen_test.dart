import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/recorrido_provider.dart';
import 'package:app_ventas/screens/recorrido/paso_productos_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/montaje.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({'recorrido_paso': 'productos'});
    final prefs = await SharedPreferences.getInstance();
    container = await containerConSesion(db,
        preferencias: prefs);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> montar(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
        appDePrueba(container, inicio: const PasoProductosScreen()));
    await tester.pumpAndSettle();
  }

  testWidgets('guarda solo las filas completas', (tester) async {
    await montar(tester);
    expect(find.text('Paso 2 de 4'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('fila_nombre_0')), 'Gaseosa');
    await tester.enterText(find.byKey(const Key('fila_precio_0')), '2500');
    await tester.enterText(find.byKey(const Key('fila_nombre_2')), 'Pan');
    await tester.enterText(find.byKey(const Key('fila_precio_2')), '6000');
    await tester.tap(find.byKey(const Key('boton_guardar_productos')));
    await tester.pumpAndSettle();
    final productos = await db.select(db.productos).get();
    expect(productos.map((p) => (p.nombre, p.precio)),
        unorderedEquals([('Gaseosa', 2500), ('Pan', 6000)]));
    expect(container.read(recorridoProvider), PasoRecorrido.venta);
  });

  testWidgets('una fila a medias se marca y no avanza', (tester) async {
    await montar(tester);
    await tester.enterText(find.byKey(const Key('fila_nombre_0')), 'Leche');
    await tester.tap(find.byKey(const Key('boton_guardar_productos')));
    await tester.pumpAndSettle();
    expect(find.text('Falta el precio'), findsOneWidget);
    expect(await db.select(db.productos).get(), isEmpty);
    expect(container.read(recorridoProvider), PasoRecorrido.productos);
  });

  testWidgets('nombres repetidos o ya existentes se marcan', (tester) async {
    await db
        .into(db.productos)
        .insert(ProductosCompanion.insert(nombre: 'Arroz', precio: 3900));
    await montar(tester);
    await tester.enterText(find.byKey(const Key('fila_nombre_0')), 'Pan');
    await tester.enterText(find.byKey(const Key('fila_precio_0')), '6000');
    await tester.enterText(find.byKey(const Key('fila_nombre_1')), ' pan ');
    await tester.enterText(find.byKey(const Key('fila_precio_1')), '6000');
    await tester.enterText(find.byKey(const Key('fila_nombre_2')), 'arroz');
    await tester.enterText(find.byKey(const Key('fila_precio_2')), '3900');
    await tester.tap(find.byKey(const Key('boton_guardar_productos')));
    await tester.pumpAndSettle();
    expect(find.text('Ya está en la lista'), findsNWidgets(2));
    expect(await db.select(db.productos).get(), hasLength(1));
    expect(container.read(recorridoProvider), PasoRecorrido.productos);
  });

  testWidgets('Omitir no guarda y avanza', (tester) async {
    await montar(tester);
    await tester.enterText(find.byKey(const Key('fila_nombre_0')), 'Pan');
    await tester.tap(find.byKey(const Key('boton_omitir_productos')));
    await tester.pumpAndSettle();
    expect(await db.select(db.productos).get(), isEmpty);
    expect(container.read(recorridoProvider), PasoRecorrido.venta);
  });

  testWidgets('empieza con 3 filas y no pasa de 20', (tester) async {
    await montar(tester);
    expect(find.byKey(const Key('fila_nombre_2')), findsOneWidget);
    expect(find.byKey(const Key('fila_nombre_3')), findsNothing);
    Future<void> alFinal() async {
      await tester.drag(find.byType(ListView), const Offset(0, -20000));
      await tester.pumpAndSettle();
    }

    // De 3 a 20 filas son 17 toques.
    for (var i = 0; i < 17; i++) {
      await alFinal();
      await tester.tap(find.byKey(const Key('boton_agregar_fila')));
      await tester.pump();
    }
    await alFinal();
    expect(find.byKey(const Key('fila_nombre_19')), findsOneWidget);
    expect(find.byKey(const Key('fila_nombre_20')), findsNothing);
    expect(find.byKey(const Key('boton_agregar_fila')), findsNothing);
  });
}
