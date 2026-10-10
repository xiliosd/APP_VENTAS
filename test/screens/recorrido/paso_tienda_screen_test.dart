import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/database_provider.dart';
import 'package:app_ventas/providers/recorrido_provider.dart';
import 'package:app_ventas/providers/sesion_provider.dart';
import 'package:app_ventas/repositories/configuracion_repository.dart';
import 'package:app_ventas/respaldo/respaldo_provider.dart';
import 'package:app_ventas/screens/recorrido/paso_tienda_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('crear admin inicial guarda el usuario e inicia sesión',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        preferenciasProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: PasoTiendaScreen()),
      ),
    );

    expect(find.text('Paso 1 de 4'), findsOneWidget);
    expect(find.text('Continuar'), findsOneWidget);
    await tester.enterText(
        find.byKey(const Key('campo_nombre_tienda')), 'La Esquina');
    await tester.enterText(find.byKey(const Key('campo_nombre_admin')), 'Ana');
    await tester.enterText(find.byKey(const Key('campo_pin_admin')), '1234');
    await tester.tap(find.byKey(const Key('boton_crear_admin')));
    await tester.pumpAndSettle();

    final usuarios = await db.select(db.usuarios).get();
    expect(usuarios, hasLength(1));
    expect(usuarios.single.nombre, 'Ana');
    expect(usuarios.single.rol, 'admin');
    expect(container.read(sesionProvider).haySesion, isTrue);
    expect(await ConfiguracionRepository(db).nombreTienda(), 'La Esquina');
    expect(container.read(recorridoProvider), PasoRecorrido.productos);
  });

  testWidgets('sin nombre de tienda muestra el error y no crea nada',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        preferenciasProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: PasoTiendaScreen()),
    ));

    await tester.enterText(find.byKey(const Key('campo_nombre_admin')), 'Ana');
    await tester.enterText(find.byKey(const Key('campo_pin_admin')), '1234');
    await tester.tap(find.byKey(const Key('boton_crear_admin')));
    await tester.pumpAndSettle();

    expect(find.text('Escribe el nombre de tu tienda'), findsOneWidget);
    expect(await db.select(db.usuarios).get(), isEmpty);
    expect(container.read(sesionProvider).haySesion, isFalse);
    expect(container.read(recorridoProvider), PasoRecorrido.ninguno);
  });
}
