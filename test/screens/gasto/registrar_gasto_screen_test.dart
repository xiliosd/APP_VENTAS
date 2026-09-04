import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/database_provider.dart';
import 'package:app_ventas/providers/sesion_provider.dart';
import 'package:app_ventas/screens/gasto/registrar_gasto_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('registrar un gasto lo guarda en la base de datos', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final usuarioId = await db.into(db.usuarios).insert(
          UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'x'),
        );
    final usuario =
        await (db.select(db.usuarios)..where((u) => u.id.equals(usuarioId)))
            .getSingle();

    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    container.read(sesionProvider.notifier).state =
        SesionState(usuarioActivo: usuario);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: RegistrarGastoScreen()),
      ),
    );

    await tester.enterText(find.byKey(const Key('campo_monto_gasto')), '20000');
    await tester.enterText(
        find.byKey(const Key('campo_descripcion_gasto')), 'Bolsas');
    await tester.tap(find.byKey(const Key('boton_registrar_gasto')));
    await tester.pumpAndSettle();

    final gastos = await db.select(db.gastos).get();
    expect(gastos.single.monto, 20000);
    expect(gastos.single.descripcion, 'Bolsas');
  });
}
