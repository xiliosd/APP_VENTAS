import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/screens/clientes/detalle_cliente_general_screen.dart';
import 'package:app_ventas/screens/fiado/detalle_cliente_screen.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/montaje.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> montar(
    WidgetTester tester, {
    required Future<int> Function(int usuarioId) sembrar,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    container = await containerConSesion(db);
    addTearDown(container.dispose);
    final usuarioId = (await db.select(db.usuarios).get()).first.id;
    final clienteId = await sembrar(usuarioId);
    await tester.pumpWidget(
      appDePrueba(
        container,
        inicio: DetalleClienteGeneralScreen(clienteId: clienteId),
      ),
    );
    await tester.pumpAndSettle();
    return clienteId;
  }

  Future<void> venta(
    int usuarioId,
    int clienteId,
    int monto,
    DateTime fecha, {
    bool fiado = false,
  }) async {
    await db
        .into(db.ventas)
        .insert(
          VentasCompanion.insert(
            monto: monto,
            fecha: fecha,
            esFiado: Value(fiado),
            clienteId: Value(clienteId),
            usuarioId: usuarioId,
          ),
        );
  }

  testWidgets(
    'el detalle muestra compras de contado y fiado con fecha y hora',
    (tester) async {
      await montar(
        tester,
        sembrar: (usuarioId) async {
          final id = await db
              .into(db.clientes)
              .insert(
                ClientesCompanion.insert(
                  nombre: 'Ana',
                  apellido: const Value('Gómez'),
                  telefono: const Value('3001112233'),
                ),
              );
          await venta(usuarioId, id, 5000, DateTime(2026, 3, 4, 15, 30));
          await venta(
            usuarioId,
            id,
            8000,
            DateTime(2026, 3, 5, 9, 5),
            fiado: true,
          );
          return id;
        },
      );
      expect(find.text('Ana Gómez'), findsWidgets);
      expect(find.text('3001112233'), findsOneWidget);
      expect(find.text('04/03/2026 15:30'), findsOneWidget);
      expect(find.text('05/03/2026 09:05'), findsOneWidget);
      expect(find.text('Contado'), findsOneWidget);
      expect(find.text('Fiado'), findsOneWidget);
      expect(find.byKey(const Key('boton_ver_fiado')), findsOneWidget);
      await tester.tap(find.byKey(const Key('boton_ver_fiado')));
      await tester.pumpAndSettle();
      expect(find.byType(DetalleClienteScreen), findsOneWidget);
    },
  );

  testWidgets('sin fiado dice "Al día" y no ofrece "Ver fiado"', (
    tester,
  ) async {
    await montar(
      tester,
      sembrar: (_) =>
          db.into(db.clientes).insert(ClientesCompanion.insert(nombre: 'Luis')),
    );
    expect(find.text('Al día'), findsOneWidget);
    expect(find.byKey(const Key('boton_ver_fiado')), findsNothing);
    expect(find.text('Aún no tiene compras'), findsOneWidget);
  });
}
