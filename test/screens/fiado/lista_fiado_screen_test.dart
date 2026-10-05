import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/database_provider.dart';
import 'package:app_ventas/screens/fiado/lista_fiado_screen.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> montar(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: ListaFiadoScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('sin deudas muestra el estado vacío', (tester) async {
    await montar(tester);
    expect(find.text('Nadie te debe'), findsOneWidget);
    expect(find.text('Las ventas fiadas aparecerán aquí'), findsOneWidget);
  });

  testWidgets('muestra el total y cada cliente con desde cuándo debe',
      (tester) async {
    final ana = await db.into(db.usuarios).insert(
          UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'x'),
        );
    final pedro = await db
        .into(db.clientes)
        .insert(ClientesCompanion.insert(nombre: 'Don Pedro'));
    final ahora = DateTime.now();
    await db.into(db.ventas).insert(VentasCompanion.insert(
          monto: 5000,
          fecha: DateTime(ahora.year, ahora.month, ahora.day - 1, 10),
          esFiado: const Value(true),
          clienteId: Value(pedro),
          usuarioId: ana,
        ));

    await montar(tester);

    expect(
        find.descendant(
            of: find.byKey(const Key('tarjeta_te_deben')),
            matching: find.text(r'$5.000')),
        findsOneWidget);
    expect(find.text('Don Pedro'), findsOneWidget);
    expect(find.text('Debe desde ayer'), findsOneWidget);
  });
}
