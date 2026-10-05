import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/database_provider.dart';
import 'package:app_ventas/screens/home/resumen_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('muestra los totales del día', (tester) async {
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
    await db.into(db.gastos).insert(
          GastosCompanion.insert(
            monto: 1000,
            fecha: DateTime.now(),
            usuarioId: usuarioId,
          ),
        );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: Scaffold(body: ResumenScreen())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(r'Vendiste: $5.000'), findsOneWidget);
    expect(find.text(r'Gastaste: $1.000'), findsOneWidget);
    expect(find.text(r'Por cobrar: $0'), findsOneWidget);
  });

  testWidgets('navegar al día anterior muestra los totales de ese día',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final usuarioId = await db.into(db.usuarios).insert(
          UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'x'),
        );
    final ahora = DateTime.now();
    await db.into(db.ventas).insert(
          VentasCompanion.insert(
              monto: 5000, fecha: ahora, usuarioId: usuarioId),
        );
    await db.into(db.ventas).insert(
          VentasCompanion.insert(
            monto: 7000,
            fecha: DateTime(ahora.year, ahora.month, ahora.day - 1, 12),
            usuarioId: usuarioId,
          ),
        );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: Scaffold(body: ResumenScreen())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Hoy'), findsOneWidget);
    expect(find.text(r'Vendiste: $5.000'), findsOneWidget);

    await tester.tap(find.byKey(const Key('boton_dia_anterior')));
    await tester.pumpAndSettle();
    expect(find.text(r'Vendiste: $7.000'), findsOneWidget);

    await tester.tap(find.byKey(const Key('boton_dia_siguiente')));
    await tester.pumpAndSettle();
    expect(find.text('Hoy'), findsOneWidget);
    expect(find.text(r'Vendiste: $5.000'), findsOneWidget);
  });
}
