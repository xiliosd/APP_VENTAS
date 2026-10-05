import 'dart:async';

import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/database_provider.dart';
import 'package:app_ventas/providers/repository_providers.dart';
import 'package:app_ventas/providers/sesion_provider.dart';
import 'package:app_ventas/repositories/fiado_repository.dart';
import 'package:app_ventas/screens/fiado/detalle_cliente_screen.dart';
import 'package:app_ventas/ui/boton_principal.dart';
import 'package:app_ventas/ui/tema_app.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  /// Cliente que debe $5.000 (venta fiada el 01/09/2026 10:00), con su detalle
  /// abierto y una sesión activa. Devuelve el id del cliente.
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
    await db.into(db.ventas).insert(VentasCompanion.insert(
          monto: 5000,
          fecha: DateTime(2026, 9, 1, 10, 0),
          esFiado: const Value(true),
          clienteId: Value(clienteId),
          usuarioId: usuarioId,
        ));
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
          theme: temaApp(),
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

  Finder saldo(String texto) => find.descendant(
      of: find.byKey(const Key('tarjeta_saldo_cliente')),
      matching: find.text(texto));

  Future<void> teclear(WidgetTester tester, List<String> teclas) async {
    for (final tecla in teclas) {
      await tester.tap(find.byKey(Key('tecla_monto_$tecla')));
    }
    await tester.pump();
  }

  testWidgets('muestra el saldo y los movimientos del cliente', (tester) async {
    await montarDetalle(tester);

    expect(saldo(r'$5.000'), findsOneWidget);
    expect(find.text('Movimientos'), findsOneWidget);
    expect(find.text('Venta fiada'), findsOneWidget);
    expect(find.text('01/09/2026 10:00'), findsOneWidget);
  });

  testWidgets(
      'registrar un abono desde el panel actualiza saldo y movimientos y '
      'la pantalla sigue abierta', (tester) async {
    final clienteId = await montarDetalle(tester);

    await tester.tap(find.byKey(const Key('boton_registrar_abono')));
    await tester.pumpAndSettle();
    await teclear(tester, ['2', '000']);
    await tester.tap(find.byKey(const Key('boton_confirmar_abono')));
    await tester.pumpAndSettle();

    expect(await FiadoRepository(db).saldoCliente(clienteId), 3000);
    expect(find.byType(DetalleClienteScreen), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    expect(saldo(r'$3.000'), findsOneWidget);
    expect(find.text('Abono registrado'), findsOneWidget);
    expect(find.text('Abono'), findsOneWidget);
  });

  testWidgets('un abono mayor que la deuda muestra error y no se registra',
      (tester) async {
    final clienteId = await montarDetalle(tester);

    await tester.tap(find.byKey(const Key('boton_registrar_abono')));
    await tester.pumpAndSettle();
    await teclear(tester, ['9', '000']);
    await tester.tap(find.byKey(const Key('boton_confirmar_abono')));
    await tester.pumpAndSettle();

    expect(find.text(r'El abono no puede ser mayor que la deuda ($5.000)'),
        findsOneWidget);
    expect(await FiadoRepository(db).saldoCliente(clienteId), 5000);
    expect(find.byType(BottomSheet), findsOneWidget);
  });

  testWidgets('con monto 0 no se puede confirmar el abono', (tester) async {
    await montarDetalle(tester);

    await tester.tap(find.byKey(const Key('boton_registrar_abono')));
    await tester.pumpAndSettle();

    final boton = tester.widget<BotonPrincipal>(
        find.byKey(const Key('boton_confirmar_abono')));
    expect(boton.onPressed, isNull);
  });

  testWidgets('un doble toque al confirmar registra un solo abono',
      (tester) async {
    // En producción la base corre en otro isolate, así que la lectura del
    // saldo tarda; el Completer reproduce esa espera.
    final lectura = Completer<void>();
    final clienteId = await montarDetalle(tester, overrides: [
      fiadoRepositoryProvider
          .overrideWithValue(_FiadoRepositoryLento(db, lectura.future)),
    ]);

    await tester.tap(find.byKey(const Key('boton_registrar_abono')));
    await tester.pumpAndSettle();
    await teclear(tester, ['2', '000']);
    await tester.tap(find.byKey(const Key('boton_confirmar_abono')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('boton_confirmar_abono')),
        warnIfMissed: false);
    await tester.pump();
    lectura.complete();
    await tester.pumpAndSettle();

    expect(await FiadoRepository(db).pagosCliente(clienteId), hasLength(1));
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
