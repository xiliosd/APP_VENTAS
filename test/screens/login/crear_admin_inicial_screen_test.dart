import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/database_provider.dart';
import 'package:app_ventas/providers/sesion_provider.dart';
import 'package:app_ventas/repositories/configuracion_repository.dart';
import 'package:app_ventas/screens/login/crear_admin_inicial_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('crear admin inicial guarda el usuario e inicia sesión',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: CrearAdminInicialScreen()),
      ),
    );

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
  });

  testWidgets('sin nombre de tienda muestra el error y no crea nada',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: CrearAdminInicialScreen()),
    ));

    await tester.enterText(find.byKey(const Key('campo_nombre_admin')), 'Ana');
    await tester.enterText(find.byKey(const Key('campo_pin_admin')), '1234');
    await tester.tap(find.byKey(const Key('boton_crear_admin')));
    await tester.pumpAndSettle();

    expect(find.text('Escribe el nombre de tu tienda'), findsOneWidget);
    expect(await db.select(db.usuarios).get(), isEmpty);
    expect(container.read(sesionProvider).haySesion, isFalse);
  });
}
