import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/database_provider.dart';
import 'package:app_ventas/screens/reportes/barras_por_dia.dart';
import 'package:app_ventas/screens/reportes/reportes_screen.dart';
import 'package:app_ventas/ui/monto.dart';
import 'package:app_ventas/ui/tema_app.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late int ana;
  late int pedro;
  final hoy = DateTime(2026, 10, 7); // miércoles

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    ana = await db.into(db.usuarios).insert(
        UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'x'));
    pedro = await db
        .into(db.clientes)
        .insert(ClientesCompanion.insert(nombre: 'Don Pedro'));
  });

  tearDown(() => db.close());

  Future<void> vender(int monto, DateTime fecha, {bool fiado = false}) =>
      db.into(db.ventas).insert(VentasCompanion.insert(
            monto: monto,
            fecha: fecha,
            usuarioId: ana,
            esFiado: Value(fiado),
            clienteId: Value(fiado ? pedro : null),
          ));

  Future<void> montar(WidgetTester tester,
      {DateTime Function()? reloj}) async {
    // Pantalla alta: el ListView construye todas las secciones.
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(theme: temaApp(), home: ReportesScreen(reloj: reloj ?? () => hoy)),
    ));
    await tester.pumpAndSettle();
  }

  Finder en(String clave, String texto) => find.descendant(
      of: find.byKey(Key(clave)), matching: find.text(texto));

  bool siguienteHabilitada(WidgetTester tester) =>
      tester
          .widget<IconButton>(find.byKey(const Key('periodo_siguiente')))
          .onPressed !=
      null;

  testWidgets('muestra la semana actual con sus cifras y la comparación',
      (tester) async {
    await vender(5000, DateTime(2026, 10, 6));
    await vender(4000, DateTime(2026, 9, 29));
    await montar(tester);

    expect(find.text('Reportes'), findsOneWidget);
    expect(find.text('Semana del 5 al 11 oct.'), findsOneWidget);
    expect(en('reporte_ventas', r'$5.000'), findsOneWidget);
    expect(find.text('↑ 25 % vs. semana pasada'), findsWidgets);
    expect(find.text(r'1 venta · promedio $5.000'), findsOneWidget);
    expect(en('reporte_efectivo', r'$5.000'), findsOneWidget);
    expect(siguienteHabilitada(tester), isFalse);
  });

  testWidgets('la flecha anterior va a la semana pasada', (tester) async {
    await vender(5000, DateTime(2026, 10, 6));
    await vender(4000, DateTime(2026, 9, 29));
    await montar(tester);

    await tester.tap(find.byKey(const Key('periodo_anterior')));
    await tester.pumpAndSettle();

    expect(find.text('Semana del 28 sep. al 4 oct.'), findsOneWidget);
    expect(en('reporte_ventas', r'$4.000'), findsOneWidget);
    expect(siguienteHabilitada(tester), isTrue);
  });

  testWidgets('Mes muestra el mes actual sin comparación si el anterior '
      'no vendió esos días', (tester) async {
    await vender(5000, DateTime(2026, 10, 6));
    await vender(4000, DateTime(2026, 9, 29));
    await montar(tester);

    await tester.tap(find.text('Mes'));
    await tester.pumpAndSettle();

    expect(find.text('Octubre 2026'), findsOneWidget);
    expect(en('reporte_ventas', r'$5.000'), findsOneWidget);
    expect(find.textContaining('vs. mes pasado'), findsNothing);
  });

  testWidgets('sin movimientos muestra el estado vacío con el selector',
      (tester) async {
    await montar(tester);

    expect(find.text('Sin ventas en este periodo'), findsOneWidget);
    expect(find.byKey(const Key('selector_periodo')), findsOneWidget);
    expect(find.byKey(const Key('periodo_anterior')), findsOneWidget);
  });

  testWidgets('con solo gastos no es vacío y la ganancia sale en rojo',
      (tester) async {
    await db.into(db.gastos).insert(GastosCompanion.insert(
        monto: 3000, fecha: DateTime(2026, 10, 6), usuarioId: ana));
    await montar(tester);

    expect(find.text('Sin ventas en este periodo'), findsNothing);
    expect(en('reporte_ganancia', r'-$3.000'), findsOneWidget);
    final ganancia = tester.widget<Monto>(find.descendant(
        of: find.byKey(const Key('reporte_ganancia')),
        matching: find.byType(Monto)));
    expect(ganancia.tono, TonoMonto.sale);
    expect(tester.takeException(), isNull);
  });

  testWidgets('muestra fiado, deuda y el mejor día', (tester) async {
    await vender(2000, DateTime(2026, 9, 30), fiado: true);
    await vender(3000, DateTime(2026, 10, 6), fiado: true);
    await vender(1000, DateTime(2026, 10, 5));
    await db.into(db.pagosFiado).insert(PagosFiadoCompanion.insert(
        clienteId: pedro,
        monto: 1000,
        fecha: DateTime(2026, 10, 7),
        usuarioId: ana));
    await montar(tester);

    expect(find.text(r'Fiaste $3.000 · Cobraste $1.000'), findsOneWidget);
    expect(find.text(r'Deuda: $2.000 → $4.000'), findsOneWidget);
    expect(find.text(r'Mejor día: martes 6 · $3.000'), findsOneWidget);
    expect(tester.widget<BarraDia>(find.byKey(const Key('barra_6'))).resaltada,
        isTrue);
  });

  testWidgets('una venta registrada con la pantalla abierta aparece sola',
      (tester) async {
    await montar(tester);
    expect(find.text('Sin ventas en este periodo'), findsOneWidget);

    await vender(7000, DateTime(2026, 10, 7, 9));
    await tester.pumpAndSettle();

    expect(en('reporte_ventas', r'$7.000'), findsOneWidget);
  });

  testWidgets('pasada la medianoche, una venta nueva cuenta en el día nuevo',
      (tester) async {
    var ahora = DateTime(2026, 10, 6, 23, 50); // martes
    await montar(tester, reloj: () => ahora);
    expect(find.text('Sin ventas en este periodo'), findsOneWidget);

    ahora = DateTime(2026, 10, 7, 0, 10); // miércoles
    await vender(7000, ahora);
    await tester.pumpAndSettle();

    expect(en('reporte_ventas', r'$7.000'), findsOneWidget);
  });
}
