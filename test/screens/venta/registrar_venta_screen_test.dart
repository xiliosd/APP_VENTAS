import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/database_provider.dart';
import 'package:app_ventas/providers/sesion_provider.dart';
import 'package:app_ventas/screens/venta/registrar_venta_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<ProviderContainer> _containerConSesion(AppDatabase db) async {
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
  return container;
}

void main() {
  testWidgets('tocar un monto rápido registra una venta de contado',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = await _containerConSesion(db);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: RegistrarVentaScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('monto_rapido_5000')));
    await tester.pumpAndSettle();

    final ventas = await db.select(db.ventas).get();
    expect(ventas, hasLength(1));
    expect(ventas.single.monto, 5000);
    expect(ventas.single.esFiado, isFalse);
  });

  testWidgets('marcar fiado con cliente nuevo crea el cliente y la venta fiada',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = await _containerConSesion(db);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: RegistrarVentaScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('checkbox_fiado')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('campo_cliente_nuevo')), 'Don Pedro');
    await tester.tap(find.byKey(const Key('monto_rapido_2000')));
    await tester.pumpAndSettle();

    final ventas = await db.select(db.ventas).get();
    expect(ventas.single.esFiado, isTrue);
    final clientes = await db.select(db.clientes).get();
    expect(clientes.single.nombre, 'Don Pedro');
    expect(ventas.single.clienteId, clientes.single.id);
  });
}
