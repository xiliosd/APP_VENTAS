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
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  /// Crea un cliente que debe $5.000 (una venta fiada el 01/09/2026 10:00),
  /// abre su detalle con una sesión activa y devuelve el id del cliente.
  Future<int> montarDetalle(WidgetTester tester) async {
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
            fecha: DateTime(2026, 9, 1, 10, 0),
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
              fechaDeudaMasAntigua: DateTime(2026, 9, 1),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return clienteId;
  }

  testWidgets('muestra los movimientos del cliente', (tester) async {
    await montarDetalle(tester);

    expect(find.text(r'Debe: $5.000'), findsOneWidget);
    expect(find.text('Movimientos'), findsOneWidget);
    expect(find.text('Venta fiada'), findsOneWidget);
    expect(find.text('01/09/2026 10:00'), findsOneWidget);
  });

  testWidgets(
      'registrar un abono actualiza saldo y movimientos y la pantalla '
      'sigue abierta', (tester) async {
    final clienteId = await montarDetalle(tester);

    await tester.enterText(find.byKey(const Key('campo_monto_abono')), '2.000');
    await tester.tap(find.byKey(const Key('boton_registrar_abono')));
    await tester.pumpAndSettle();

    expect(await FiadoRepository(db).saldoCliente(clienteId), 3000);
    expect(find.byType(DetalleClienteScreen), findsOneWidget);
    expect(find.text(r'Debe: $3.000'), findsOneWidget);
    expect(find.text('Abono registrado'), findsOneWidget);
    expect(find.text('Abono'), findsOneWidget);
    final campo =
        tester.widget<TextField>(find.byKey(const Key('campo_monto_abono')));
    expect(campo.controller!.text, isEmpty);
  });

  testWidgets('un abono mayor que la deuda muestra error y no se registra',
      (tester) async {
    final clienteId = await montarDetalle(tester);

    await tester.enterText(find.byKey(const Key('campo_monto_abono')), '9000');
    await tester.tap(find.byKey(const Key('boton_registrar_abono')));
    await tester.pumpAndSettle();

    expect(find.text(r'El abono no puede ser mayor que la deuda ($5.000)'),
        findsOneWidget);
    expect(await FiadoRepository(db).saldoCliente(clienteId), 5000);
    expect(find.text('Abono'), findsNothing);
  });

  testWidgets('un monto inválido muestra error y no se registra',
      (tester) async {
    final clienteId = await montarDetalle(tester);

    await tester.enterText(find.byKey(const Key('campo_monto_abono')), 'abc');
    await tester.tap(find.byKey(const Key('boton_registrar_abono')));
    await tester.pumpAndSettle();

    expect(find.text('Escribe un monto válido'), findsOneWidget);
    expect(await FiadoRepository(db).saldoCliente(clienteId), 5000);
  });
}
