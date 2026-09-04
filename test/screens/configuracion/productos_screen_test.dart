import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/database_provider.dart';
import 'package:app_ventas/screens/configuracion/productos_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('crear un producto lo agrega a la lista visible', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: ProductosScreen()),
      ),
    );

    await tester.enterText(
        find.byKey(const Key('campo_nombre_producto')), 'Arepa');
    await tester.enterText(
        find.byKey(const Key('campo_precio_producto')), '3000');
    await tester.tap(find.byKey(const Key('boton_crear_producto')));
    await tester.pumpAndSettle();

    expect(find.text('Arepa'), findsOneWidget);
    expect(find.text(r'$3.000'), findsOneWidget);
  });

  testWidgets('desactivar un producto lo saca de la lista', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final id = await db.into(db.productos).insert(
          ProductosCompanion.insert(nombre: 'Arepa', precio: 3000),
        );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: ProductosScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(Key('boton_desactivar_$id')));
    await tester.pumpAndSettle();

    expect(find.text('Arepa'), findsNothing);
  });
}
