import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/database_provider.dart';
import 'package:app_ventas/screens/historial/historial_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('lista las ventas del día actual', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final usuarioId = await db.into(db.usuarios).insert(
          UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'x'),
        );
    await db.into(db.ventas).insert(
          VentasCompanion.insert(
            monto: 5000,
            fecha: DateTime.now(),
            usuarioId: usuarioId,
          ),
        );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: HistorialScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(r'$5.000'), findsOneWidget);
    expect(find.text('Contado'), findsOneWidget);
  });
}
