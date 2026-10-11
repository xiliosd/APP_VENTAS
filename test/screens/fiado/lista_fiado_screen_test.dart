import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/database_provider.dart';
import 'package:app_ventas/screens/fiado/detalle_cliente_screen.dart';
import 'package:app_ventas/screens/fiado/lista_fiado_screen.dart';
import 'package:app_ventas/ui/colores_app.dart';
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

  Future<void> montar(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
            theme: temaClaro(), home: const Scaffold(body: ListaFiadoScreen())),
      ),
    );
    await tester.pumpAndSettle();
  }

  int? anaId;
  Future<int> usuario() async => anaId ??= await db.into(db.usuarios).insert(
      UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'x'));

  /// Crea un cliente con una venta fiada de [monto] hace [dias] días.
  Future<int> deudor(String nombre, int monto, int dias) async {
    final ana = await usuario();
    final id = await db
        .into(db.clientes)
        .insert(ClientesCompanion.insert(nombre: nombre));
    final hoy = DateTime.now();
    await db.into(db.ventas).insert(VentasCompanion.insert(
        monto: monto,
        fecha: DateTime(hoy.year, hoy.month, hoy.day - dias, 10),
        esFiado: const Value(true),
        clienteId: Value(id),
        usuarioId: ana));
    return id;
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


  testWidgets('quien ya pagó todo aparece en Al día y abre su detalle',
      (tester) async {
    final ana = await db.into(db.usuarios).insert(
          UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'x'),
        );
    final pedro = await db
        .into(db.clientes)
        .insert(ClientesCompanion.insert(nombre: 'Don Pedro'));
    await db.into(db.ventas).insert(VentasCompanion.insert(
          monto: 5000,
          fecha: DateTime(2026, 9, 1),
          esFiado: const Value(true),
          clienteId: Value(pedro),
          usuarioId: ana,
        ));
    await db.into(db.pagosFiado).insert(PagosFiadoCompanion.insert(
        clienteId: pedro, monto: 5000, fecha: DateTime(2026, 9, 2), usuarioId: ana));

    await montar(tester);

    expect(find.text('Nadie te debe'), findsOneWidget);
    expect(find.byKey(Key('cliente_al_dia_$pedro')), findsNothing);
    expect(find.text('Al día (1)'), findsOneWidget);
    await tester.tap(find.byKey(const Key('boton_al_dia')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('cliente_al_dia_$pedro')));
    await tester.pumpAndSettle();

    expect(find.byType(DetalleClienteScreen), findsOneWidget);
    expect(
        find.descendant(
            of: find.byKey(const Key('tarjeta_saldo_cliente')),
            matching: find.text('Al día')),
        findsOneWidget);
  });

  List<String> orden(WidgetTester tester) => tester
      .widgetList<Text>(find.byKey(const Key('nombre_cliente')))
      .map((t) => t.data!)
      .toList();

  testWidgets('ordena por mayor deuda y por más antigua', (tester) async {
    await deudor('Ana María', 3000, 40);
    await deudor('Beto', 9000, 2);
    await deudor('Carla', 5000, 10);
    await montar(tester);
    expect(orden(tester), ['Beto', 'Carla', 'Ana María']);
    expect(find.text(r'Mayor deuda: Beto $9.000'), findsOneWidget);
    await tester.tap(find.text('Más antigua'));
    await tester.pumpAndSettle();
    expect(orden(tester), ['Ana María', 'Carla', 'Beto']);
  });

  testWidgets('el buscador ignora tildes y se mantiene al cambiar el orden',
      (tester) async {
    for (final n in ['Ángela', 'Beto', 'Carla', 'Darío', 'Elsa', 'Fabio']) {
      await deudor(n, 1000, 1);
    }
    await montar(tester);
    await tester.enterText(find.byKey(const Key('buscador_fiado')), 'angel');
    await tester.pump();
    expect(orden(tester), ['Ángela']);
    await tester.tap(find.text('Más antigua'));
    await tester.pumpAndSettle();
    expect(orden(tester), ['Ángela']);
    await tester.enterText(find.byKey(const Key('buscador_fiado')), 'zzz');
    await tester.pump();
    expect(find.byKey(const Key('texto_sin_resultados_fiado')), findsOneWidget);
  });

  testWidgets('con 5 clientes o menos no hay buscador', (tester) async {
    for (final n in ['A', 'B', 'C', 'D', 'E']) {
      await deudor(n, 1000, 1);
    }
    await montar(tester);
    expect(find.byKey(const Key('buscador_fiado')), findsNothing);
  });

  testWidgets('la etiqueta de antigüedad cambia de color con los días',
      (tester) async {
    final reciente = await deudor('Uno', 1000, 7);
    final media = await deudor('Dos', 1000, 8);
    final vieja = await deudor('Tres', 1000, 31);
    await montar(tester);
    Color fondo(int id) => (tester
            .widget<Container>(find.byKey(Key('antiguedad_$id')))
            .decoration! as BoxDecoration)
        .color!;
    final c = ColoresApp.claro;
    expect(fondo(reciente), c.primarioSuave);
    expect(fondo(media), c.fiadoSuave);
    expect(fondo(vieja), c.sale.withValues(alpha: 0.15));
  });

  testWidgets('el texto de cada etiqueta de antigüedad se lee (≥ 4,5:1)',
      (tester) async {
    final ids = [
      await deudor('Uno', 1000, 7),
      await deudor('Dos', 1000, 8),
      await deudor('Tres', 1000, 31),
    ];
    await montar(tester);
    double contraste(Color a, Color b) {
      final la = a.computeLuminance(), lb = b.computeLuminance();
      return ((la > lb ? la : lb) + 0.05) / ((la > lb ? lb : la) + 0.05);
    }
    for (final id in ids) {
      final etiqueta = find.byKey(Key('antiguedad_$id'));
      final fondo = (tester.widget<Container>(etiqueta).decoration!
              as BoxDecoration)
          .color!;
      // El fondo es translúcido sobre la tarjeta (superficie).
      final fondoReal = Color.alphaBlend(fondo, ColoresApp.claro.superficie);
      final texto = tester
          .widget<Text>(find.descendant(of: etiqueta, matching: find.byType(Text)))
          .style!
          .color!;
      expect(contraste(texto, fondoReal), greaterThanOrEqualTo(4.5),
          reason: 'cliente $id');
    }
  });
}
