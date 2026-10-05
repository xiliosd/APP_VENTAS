import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/database_provider.dart';
import 'package:app_ventas/screens/login/seleccionar_usuario_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('muestra la marca, cada usuario con su inicial y su rol',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.into(db.usuarios).insert(
        UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'x'));
    await db.into(db.usuarios).insert(
        UsuariosCompanion.insert(nombre: 'Beto', rol: 'vendedor', pinHash: 'y'));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: SeleccionarUsuarioScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('App Ventas'), findsOneWidget);
    expect(find.text('¿Quién eres?'), findsOneWidget);
    expect(find.text('Administrador'), findsOneWidget);
    expect(find.text('Vendedor'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
  });
}
