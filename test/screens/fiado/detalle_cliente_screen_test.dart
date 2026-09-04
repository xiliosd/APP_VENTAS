import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/database_provider.dart';
import 'package:app_ventas/providers/sesion_provider.dart';
import 'package:app_ventas/repositories/fiado_repository.dart';
import 'package:app_ventas/screens/fiado/detalle_cliente_screen.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('registrar un abono descuenta el saldo en la base de datos',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final usuarioId = await db.into(db.usuarios).insert(
          UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'x'),
        );
    final usuario =
        await (db.select(db.usuarios)..where((u) => u.id.equals(usuarioId)))
            .getSingle();
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
    final cliente =
        await (db.select(db.clientes)..where((c) => c.id.equals(clienteId)))
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
        child: MaterialApp(
          home: DetalleClienteScreen(
            clienteConSaldo: ClienteConSaldo(
              cliente: cliente,
              saldo: 5000,
              fechaDeudaMasAntigua: DateTime.now(),
            ),
          ),
        ),
      ),
    );

    await tester.enterText(find.byKey(const Key('campo_monto_abono')), '2000');
    await tester.tap(find.byKey(const Key('boton_registrar_abono')));
    await tester.pumpAndSettle();

    final saldo = await FiadoRepository(db).saldoCliente(clienteId);
    expect(saldo, 3000);
  });
}
