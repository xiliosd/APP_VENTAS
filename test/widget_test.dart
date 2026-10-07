import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/main.dart';
import 'package:app_ventas/providers/database_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('primer uso: Bienvenida → crear tienda → entra al Inicio',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const AppVentas(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Crear tienda nueva'), findsOneWidget);

    await tester.tap(find.byKey(const Key('boton_crear_tienda')));
    await tester.pumpAndSettle();
    expect(find.text('Configura tu tienda'), findsOneWidget);

    await tester.enterText(
        find.byKey(const Key('campo_nombre_tienda')), 'La Esquina');
    await tester.enterText(find.byKey(const Key('campo_nombre_admin')), 'Ana');
    await tester.enterText(find.byKey(const Key('campo_pin_admin')), '1234');
    await tester.tap(find.byKey(const Key('boton_crear_admin')));
    await tester.pumpAndSettle();

    expect(find.text('Hola, Ana'), findsOneWidget);
    expect(find.text('La Esquina'), findsOneWidget);
    expect(find.text('Configura tu tienda'), findsNothing);
    expect(find.text('¿Cómo se llama tu tienda?'), findsNothing);
  });
}
