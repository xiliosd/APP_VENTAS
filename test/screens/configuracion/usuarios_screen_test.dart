import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/database_provider.dart';
import 'package:app_ventas/screens/configuracion/usuarios_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('crear un vendedor lo agrega a la lista', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: UsuariosScreen()),
      ),
    );

    await tester.enterText(
        find.byKey(const Key('campo_nombre_vendedor')), 'Beto');
    await tester.enterText(find.byKey(const Key('campo_pin_vendedor')), '4321');
    await tester.tap(find.byKey(const Key('boton_crear_vendedor')));
    await tester.pumpAndSettle();

    final usuarios = await db.select(db.usuarios).get();
    expect(usuarios.single.nombre, 'Beto');
    expect(usuarios.single.rol, 'vendedor');
    expect(find.text('Beto'), findsOneWidget);
  });
}
