import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/database_provider.dart';
import 'package:app_ventas/screens/fiado/lista_fiado_screen.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('muestra clientes con deuda y el mensaje vacío cuando no hay deudas',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: ListaFiadoScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Nadie te debe por ahora'), findsOneWidget);

    final usuarioId = await db.into(db.usuarios).insert(
          UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'x'),
        );
    final clienteId = await db
        .into(db.clientes)
        .insert(ClientesCompanion.insert(nombre: 'Don Pedro'));
    await db.into(db.ventas).insert(
          VentasCompanion.insert(
            monto: 5000,
            fecha: DateTime.now(),
            esFiado: const Value(true),
            clienteId: Value(clienteId),
            usuarioId: usuarioId,
          ),
        );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: ListaFiadoScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Don Pedro'), findsOneWidget);
    expect(find.text(r'$5.000'), findsOneWidget);
  });
}
