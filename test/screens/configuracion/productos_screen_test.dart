import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/database_provider.dart';
import 'package:app_ventas/screens/configuracion/productos_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> montar(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: ProductosScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<int> crearArepa() => db.into(db.productos).insert(
        ProductosCompanion.insert(nombre: 'Arepa', precio: 3000),
      );

  testWidgets('crear un producto lo agrega a la lista visible', (tester) async {
    await montar(tester);

    await tester.enterText(
        find.byKey(const Key('campo_nombre_producto')), 'Arepa');
    await tester.enterText(
        find.byKey(const Key('campo_precio_producto')), '3.000');
    await tester.tap(find.byKey(const Key('boton_crear_producto')));
    await tester.pumpAndSettle();

    expect(find.text('Arepa'), findsOneWidget);
    expect(find.text(r'$3.000'), findsOneWidget);
  });

  testWidgets('editar un producto cambia nombre y precio', (tester) async {
    final id = await crearArepa();
    await montar(tester);

    await tester.tap(find.byKey(Key('producto_item_$id')));
    await tester.pumpAndSettle();
    expect(find.text('Editar producto'), findsOneWidget);

    await tester.enterText(
        find.byKey(const Key('campo_editar_nombre')), 'Arepa rellena');
    await tester.enterText(
        find.byKey(const Key('campo_editar_precio')), '3.500');
    await tester.tap(find.byKey(const Key('boton_guardar_producto')));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Arepa rellena'), findsOneWidget);
    expect(find.text(r'$3.500'), findsOneWidget);
    final producto = await db.select(db.productos).getSingle();
    expect(producto.nombre, 'Arepa rellena');
    expect(producto.precio, 3500);
  });

  testWidgets('precio inválido al editar muestra error y no guarda',
      (tester) async {
    final id = await crearArepa();
    await montar(tester);

    await tester.tap(find.byKey(Key('producto_item_$id')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('campo_editar_precio')), 'abc');
    await tester.tap(find.byKey(const Key('boton_guardar_producto')));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Escribe un precio válido'), findsOneWidget);
    expect((await db.select(db.productos).getSingle()).precio, 3000);
  });

  testWidgets('desactivar lo pasa a Inactivos y reactivar lo devuelve',
      (tester) async {
    final id = await crearArepa();
    await montar(tester);
    expect(find.text('Inactivos'), findsNothing);

    await tester.tap(find.byKey(Key('boton_desactivar_$id')));
    await tester.pumpAndSettle();

    expect(find.byKey(Key('producto_item_$id')), findsNothing);
    expect(find.text('Inactivos'), findsOneWidget);
    expect(find.byKey(Key('producto_inactivo_$id')), findsOneWidget);

    await tester.tap(find.byKey(Key('boton_reactivar_$id')));
    await tester.pumpAndSettle();

    expect(find.byKey(Key('producto_item_$id')), findsOneWidget);
    expect(find.text('Inactivos'), findsNothing);
  });
}
