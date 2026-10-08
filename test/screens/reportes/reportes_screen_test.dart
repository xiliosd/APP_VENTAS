import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/database_provider.dart';
import 'package:app_ventas/providers/reporte_providers.dart';
import 'package:app_ventas/repositories/producto_repository.dart';
import 'package:app_ventas/repositories/proveedor_repository.dart';
import 'package:app_ventas/repositories/venta_repository.dart';
import 'package:app_ventas/screens/reportes/barras_por_dia.dart';
import 'package:app_ventas/screens/reportes/reportes_screen.dart';
import 'package:app_ventas/ui/colores_app.dart';
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
    expect(tester.widget<Barra>(find.byKey(const Key('barra_6'))).resaltada,
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

  testWidgets('muestra el ranking, otros montos y la hora pico',
      (tester) async {
    final arepa = await db
        .into(db.productos)
        .insert(ProductosCompanion.insert(nombre: 'Arepa', precio: 3500));
    await VentaRepository(db).registrarVenta(
      monto: 12000,
      esFiado: false,
      usuarioId: ana,
      fecha: DateTime(2026, 10, 6, 18, 20),
      lineas: [
        LineaNueva(
            productoId: arepa,
            descripcion: 'Arepa',
            precioUnitario: 3500,
            cantidad: 2),
        const LineaNueva(
            descripcion: r'$5.000', precioUnitario: 5000, cantidad: 1),
      ],
    );
    await vender(1000, DateTime(2026, 10, 6, 8));
    await montar(tester);

    expect(find.text('Productos más vendidos'), findsOneWidget);
    expect(find.text(r'1. Arepa · 2 u · $7.000'), findsOneWidget);
    expect(find.text(r'Otros montos · $5.000'), findsOneWidget);
    expect(find.text('Horas de más venta'), findsOneWidget);
    expect(find.text(r'Hora pico: 6 p. m. · $12.000'), findsOneWidget);
    expect(find.text('8 a. m.'), findsOneWidget);
    expect(tester.widget<Barra>(find.byKey(const Key('barra_h18'))).resaltada,
        isTrue);
  });

  testWidgets('con ventas sin detalle avisa en el ranking pero muestra horas',
      (tester) async {
    await vender(4000, DateTime(2026, 10, 6, 10));
    await montar(tester);

    expect(
        find.text('Aún no hay ventas con detalle de productos en este periodo'),
        findsOneWidget);
    expect(find.text(r'Hora pico: 10 a. m. · $4.000'), findsOneWidget);
  });

  testWidgets('muestra la ganancia en productos y lo vendido sin costo',
      (tester) async {
    final postobon = await ProveedorRepository(db).crear(nombre: 'Postobón');
    final arepa = await ProductoRepository(db).guardarProducto(
      nombre: 'Arepa',
      precio: 3500,
      proveedores: [
        ProveedorDeProducto(
            proveedorId: postobon, precioCompra: 2500, preferido: true),
      ],
    );
    await VentaRepository(db).registrarVenta(
      monto: 12000,
      esFiado: false,
      usuarioId: ana,
      fecha: DateTime(2026, 10, 6, 9),
      lineas: [
        LineaNueva(
            productoId: arepa,
            descripcion: 'Arepa',
            precioUnitario: 3500,
            cantidad: 2),
        const LineaNueva(
            descripcion: r'$5.000', precioUnitario: 5000, cantidad: 1),
      ],
    );
    await montar(tester);

    expect(find.text(r'Ganancia en productos: $2.000'), findsOneWidget);
    expect(find.text(r'1. Arepa · 2 u · $7.000 · gana $2.000'), findsOneWidget);
    expect(find.text(r'$5.000 vendidos sin costo registrado'), findsOneWidget);
  });

  testWidgets('si falla muestra un mensaje y deja reintentar', (tester) async {
    var intentos = 0;
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        comparacionReporteProvider.overrideWith((ref, consulta) async {
          intentos++;
          throw StateError('falla');
        }),
      ],
      child:
          MaterialApp(theme: temaApp(), home: ReportesScreen(reloj: () => hoy)),
    ));
    await tester.pumpAndSettle();

    expect(find.text('No se pudo cargar el reporte'), findsOneWidget);
    expect(find.textContaining('StateError'), findsNothing);
    await tester.tap(find.byKey(const Key('reintentar_reporte')));
    await tester.pumpAndSettle();
    expect(intentos, 2);
  });

  testWidgets('un producto vendido con pérdida dice cuánto pierde',
      (tester) async {
    final postobon = await ProveedorRepository(db).crear(nombre: 'Postobón');
    final arepa = await ProductoRepository(db).guardarProducto(
      nombre: 'Arepa',
      precio: 3500,
      proveedores: [
        ProveedorDeProducto(
            proveedorId: postobon, precioCompra: 4000, preferido: true),
      ],
    );
    await VentaRepository(db).registrarVenta(
      monto: 7000,
      esFiado: false,
      usuarioId: ana,
      fecha: DateTime(2026, 10, 6, 9),
      lineas: [
        LineaNueva(
            productoId: arepa,
            descripcion: 'Arepa',
            precioUnitario: 3500,
            cantidad: 2),
      ],
    );
    await montar(tester);

    expect(find.text(r'Pérdida en productos: $1.000'), findsOneWidget);
    final linea = find.text(r'1. Arepa · 2 u · $7.000 · pierde $1.000');
    expect(linea, findsOneWidget);
    expect(tester.widget<Text>(linea).style?.color, ColoresApp.sale);
  });

  testWidgets('una semana del año pasado muestra el año', (tester) async {
    await montar(tester, reloj: () => DateTime(2027, 1, 20));
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byKey(const Key('periodo_anterior')));
      await tester.pumpAndSettle();
    }
    expect(find.text('Semana del 21 al 27 dic. 2026'), findsOneWidget);
  });
}
