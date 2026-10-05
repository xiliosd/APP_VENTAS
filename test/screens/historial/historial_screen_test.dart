import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/database_provider.dart';
import 'package:app_ventas/repositories/gasto_repository.dart';
import 'package:app_ventas/repositories/venta_repository.dart';
import 'package:app_ventas/screens/historial/historial_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late VentaRepository ventas;
  late GastoRepository gastos;
  late int ana;
  late int beto;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    ventas = VentaRepository(db);
    gastos = GastoRepository(db);
    ana = await db.into(db.usuarios).insert(
          UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'x'),
        );
    beto = await db.into(db.usuarios).insert(
          UsuariosCompanion.insert(nombre: 'Beto', rol: 'vendedor', pinHash: 'y'),
        );
  });

  tearDown(() => db.close());

  Future<void> montar(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: HistorialScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> cargarHoy() async {
    await ventas.registrarVenta(monto: 5000, esFiado: false, usuarioId: ana);
    await gastos.registrarGasto(
        monto: 1000, descripcion: 'Hielo', usuarioId: beto);
    await gastos.registrarGasto(monto: 500, usuarioId: ana);
  }

  testWidgets('muestra ventas y gastos del día con usuario', (tester) async {
    await cargarHoy();
    await montar(tester);

    expect(find.text('Historial'), findsOneWidget);
    expect(find.text(r'$5.000'), findsOneWidget);
    expect(find.text('Contado · Ana'), findsOneWidget);
    expect(find.text(r'$1.000'), findsOneWidget);
    expect(find.text('Hielo · Beto'), findsOneWidget);
    expect(find.text(r'$500'), findsOneWidget);
    expect(find.text('Gasto · Ana'), findsOneWidget);
  });

  testWidgets('el filtro por usuario oculta los movimientos de otros',
      (tester) async {
    await cargarHoy();
    await montar(tester);

    await tester.tap(find.byKey(const Key('filtro_usuario')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Beto').last);
    await tester.pumpAndSettle();

    expect(find.text('Hielo · Beto'), findsOneWidget);
    expect(find.text(r'$5.000'), findsNothing);
    expect(find.text('Gasto · Ana'), findsNothing);
  });

  testWidgets('una venta registrada con la pantalla abierta aparece sola',
      (tester) async {
    await montar(tester);
    expect(find.text('Sin movimientos este día'), findsOneWidget);

    await ventas.registrarVenta(monto: 8000, esFiado: true, usuarioId: ana);
    await tester.pumpAndSettle();

    expect(find.text(r'$8.000'), findsOneWidget);
    expect(find.text('Fiado · Ana'), findsOneWidget);
  });

  testWidgets('el día anterior muestra solo los movimientos de ese día',
      (tester) async {
    final ahora = DateTime.now();
    await ventas.registrarVenta(monto: 5000, esFiado: false, usuarioId: ana);
    await ventas.registrarVenta(
      monto: 7000,
      esFiado: false,
      usuarioId: ana,
      fecha: DateTime(ahora.year, ahora.month, ahora.day - 1, 12),
    );
    await montar(tester);

    await tester.tap(find.byKey(const Key('boton_dia_anterior')));
    await tester.pumpAndSettle();

    expect(find.text(r'$7.000'), findsOneWidget);
    expect(find.text(r'$5.000'), findsNothing);
  });
}
