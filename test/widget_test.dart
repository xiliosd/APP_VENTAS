import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/main.dart';
import 'package:app_ventas/providers/database_provider.dart';
import 'package:app_ventas/respaldo/respaldo_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('primer uso: Bienvenida → 4 pasos → ¡Listo!, sin ventas',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          preferenciasProvider.overrideWithValue(prefs),
        ],
        child: const AppVentas(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Crear tienda nueva'), findsOneWidget);

    // Paso 1 · Tu tienda
    await tester.tap(find.byKey(const Key('boton_crear_tienda')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('campo_nombre_tienda')), 'La Esquina');
    await tester.enterText(find.byKey(const Key('campo_nombre_admin')), 'Ana');
    await tester.enterText(find.byKey(const Key('campo_pin_admin')), '1234');
    await tester.tap(find.byKey(const Key('boton_crear_admin')));
    await tester.pumpAndSettle();

    // Paso 2 · Tus primeros productos
    expect(find.text('Paso 2 de 4'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('fila_nombre_0')), 'Pan');
    await tester.enterText(find.byKey(const Key('fila_precio_0')), '6000');
    await tester.tap(find.byKey(const Key('boton_guardar_productos')));
    await tester.pumpAndSettle();

    // Paso 3 · Venta de práctica guiada
    expect(find.text('Paso 3 de 4'), findsOneWidget);
    await tester.tap(find.byKey(const Key('boton_empezar_practica')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pan'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('boton_cobrar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pago_efectivo')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('boton_continuar_practica')));
    await tester.pumpAndSettle();

    // Paso 4 · Conoce tu Inicio
    expect(find.text('Hola, Ana'), findsOneWidget);
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byKey(const Key('boton_siguiente_globo')));
      await tester.pumpAndSettle();
    }
    expect(find.byKey(const Key('hoja_listo')), findsOneWidget);
    await tester.tap(find.byKey(const Key('boton_empezar_a_vender')));
    await tester.pumpAndSettle();

    expect(prefs.getString('recorrido_paso'), 'hecho');
    expect(await db.select(db.ventas).get(), isEmpty);
    expect(await db.select(db.productos).get(), hasLength(1));
    expect(find.byKey(const Key('capa_globos')), findsNothing);
  });
}
