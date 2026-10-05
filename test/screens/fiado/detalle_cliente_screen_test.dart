import 'dart:async';

import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/database_provider.dart';
import 'package:app_ventas/providers/repository_providers.dart';
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
  Future<int> montarDetalle(WidgetTester tester,
      {List<Override> overrides = const []}) async {
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
      overrides: [databaseProvider.overrideWithValue(db), ...overrides],
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


  testWidgets('un doble toque en Registrar abono registra un solo abono',
      (tester) async {
    // En producción la base corre en otro isolate, así que la lectura del
    // saldo tarda; el Completer reproduce esa espera para que el segundo
    // toque llegue mientras el primero sigue en curso.
    final lectura = Completer<void>();
    final clienteId = await montarDetalle(tester, overrides: [
      fiadoRepositoryProvider
          .overrideWithValue(_FiadoRepositoryLento(db, lectura.future)),
    ]);

    await tester.enterText(find.byKey(const Key('campo_monto_abono')), '2000');
    await tester.tap(find.byKey(const Key('boton_registrar_abono')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('boton_registrar_abono')));
    await tester.pump();
    lectura.complete();
    await tester.pumpAndSettle();

    expect(await FiadoRepository(db).pagosCliente(clienteId), hasLength(1));
    expect(await FiadoRepository(db).saldoCliente(clienteId), 3000);
  });
}

/// Espera a [_espera] antes de leer el saldo, para simular la latencia de la
/// base de datos en segundo plano.
class _FiadoRepositoryLento extends FiadoRepository {
  _FiadoRepositoryLento(super.db, this._espera);

  final Future<void> _espera;

  @override
  Future<int> saldoCliente(int clienteId) async {
    await _espera;
    return super.saldoCliente(clienteId);
  }
}
