import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/database_provider.dart';
import 'package:app_ventas/providers/sesion_provider.dart';
import 'package:app_ventas/screens/home/home_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<ProviderContainer> _containerConSesion(
  AppDatabase db, {
  required String rol,
}) async {
  final usuarioId = await db.into(db.usuarios).insert(
        UsuariosCompanion.insert(nombre: 'Persona', rol: rol, pinHash: 'x'),
      );
  final usuario =
      await (db.select(db.usuarios)..where((u) => u.id.equals(usuarioId)))
          .getSingle();
  final container = ProviderContainer(
    overrides: [databaseProvider.overrideWithValue(db)],
  );
  container.read(sesionProvider.notifier).state =
      SesionState(usuarioActivo: usuario);
  return container;
}

void main() {
  testWidgets('el admin ve la pestaña Config', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = await _containerConSesion(db, rol: 'admin');
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Config'), findsOneWidget);
  });

  testWidgets('el vendedor no ve la pestaña Config', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = await _containerConSesion(db, rol: 'vendedor');
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Config'), findsNothing);
  });

  testWidgets('cerrar sesión limpia el usuario activo', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = await _containerConSesion(db, rol: 'admin');
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('boton_cerrar_sesion')));
    await tester.pumpAndSettle();

    expect(container.read(sesionProvider).haySesion, isFalse);
  });

  testWidgets('los íconos de las pestañas se ven oscuros sobre la barra clara',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = await _containerConSesion(db, rol: 'admin');
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Con 4 pestañas BottomNavigationBar usa por defecto el modo "shifting",
    // que pinta los íconos casi blancos sobre el fondo claro: invisibles.
    for (final icono in [Icons.people, Icons.history, Icons.settings]) {
      final elemento = tester.element(find.byIcon(icono));
      expect(IconTheme.of(elemento).color!.computeLuminance(), lessThan(0.5),
          reason: 'el ícono $icono debe verse sobre el fondo de la barra');
    }
  });
}
