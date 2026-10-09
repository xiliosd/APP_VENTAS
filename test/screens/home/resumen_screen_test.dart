import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/database_provider.dart';
import 'package:app_ventas/screens/home/resumen_screen.dart';
import 'package:app_ventas/screens/reportes/reportes_screen.dart';
import 'package:app_ventas/ui/monto.dart';
import 'package:app_ventas/util/fecha_util.dart';
import 'package:app_ventas/ui/tema_app.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:app_ventas/ui/colores_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/montaje.dart';

void main() {
  late AppDatabase db;
  late int ana;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    ana = await db.into(db.usuarios).insert(
          UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'x'),
        );
  });

  tearDown(() => db.close());

  Future<void> montar(WidgetTester tester, {VoidCallback? onVerFiado}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: temaClaro(),
          home: Scaffold(body: ResumenScreen(onVerFiado: onVerFiado)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder enTarjeta(String clave, String texto) => find.descendant(
      of: find.byKey(Key(clave)), matching: find.text(texto));

  Future<void> vender(int monto, {bool fiado = false, DateTime? fecha}) async {
    int? clienteId;
    if (fiado) {
      clienteId = await db
          .into(db.clientes)
          .insert(ClientesCompanion.insert(nombre: 'Cliente $monto'));
    }
    await db.into(db.ventas).insert(VentasCompanion.insert(
          monto: monto,
          fecha: fecha ?? DateTime.now(),
          esFiado: Value(fiado),
          clienteId: Value(clienteId),
          usuarioId: ana,
        ));
  }

  testWidgets('muestra ventas, gastos, ganancia y por cobrar del día',
      (tester) async {
    await vender(5000);
    await vender(2000, fiado: true);
    await db.into(db.gastos).insert(GastosCompanion.insert(
        monto: 1000, fecha: DateTime.now(), usuarioId: ana));

    await montar(tester);

    expect(enTarjeta('tarjeta_ventas', r'$7.000'), findsOneWidget);
    expect(enTarjeta('tarjeta_ventas', '2 ventas · 1 fiada'), findsOneWidget);
    expect(enTarjeta('tarjeta_gastos', r'$1.000'), findsOneWidget);
    expect(enTarjeta('tarjeta_ganancia', r'$6.000'), findsOneWidget);
    expect(enTarjeta('tarjeta_por_cobrar', r'$2.000'), findsOneWidget);
    expect(enTarjeta('tarjeta_por_cobrar', '1 cliente'), findsOneWidget);
  });

  testWidgets('una venta nueva cuenta el total sin repetir la entrada',
      (tester) async {
    await vender(5000);
    await montar(tester);

    await tester.runAsync(() => vender(10000));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
        find.descendant(
            of: find.byKey(const Key('tarjeta_ventas')),
            matching: find.byType(Opacity)),
        findsNothing);
    // Cuadro a cuadro: el monto pasa por valores intermedios.
    final vistos = <String>{};
    for (var i = 0; i < 60; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 16));
      vistos.addAll(tester
          .widgetList<Text>(find.descendant(
              of: find.byKey(const Key('tarjeta_ventas')),
              matching: find.byType(Text)))
          .map((t) => t.data ?? ''));
    }
    expect(
        vistos.where((t) =>
            t.startsWith(r'$') && t != r'$5.000' && t != r'$15.000'),
        isNotEmpty);
    await tester.pumpAndSettle();
    expect(enTarjeta('tarjeta_ventas', r'$15.000'), findsOneWidget);
  });

  testWidgets('una ganancia negativa se muestra en rojo', (tester) async {
    await db.into(db.gastos).insert(GastosCompanion.insert(
        monto: 3000, fecha: DateTime.now(), usuarioId: ana));

    await montar(tester);

    final monto = tester.widget<Monto>(find.descendant(
        of: find.byKey(const Key('tarjeta_ganancia')),
        matching: find.byType(Monto)).first);
    expect(monto.valor, -3000);
    expect(monto.tono, TonoMonto.sale);
  });

  testWidgets('tocar Por cobrar llama onVerFiado', (tester) async {
    var llamado = false;
    await montar(tester, onVerFiado: () => llamado = true);

    await tester.tap(find.byKey(const Key('tarjeta_por_cobrar')));
    expect(llamado, isTrue);
  });

  testWidgets('navegar al día anterior muestra las ventas de ese día',
      (tester) async {
    final ahora = DateTime.now();
    await vender(5000);
    await vender(7000,
        fecha: DateTime(ahora.year, ahora.month, ahora.day - 1, 12));

    await montar(tester);
    expect(find.text('Hoy'), findsOneWidget);
    expect(enTarjeta('tarjeta_ventas', r'$5.000'), findsOneWidget);

    await tester.tap(find.byKey(const Key('boton_dia_anterior')));
    await tester.pumpAndSettle();
    expect(enTarjeta('tarjeta_ventas', r'$7.000'), findsOneWidget);

    await tester.tap(find.byKey(const Key('boton_dia_siguiente')));
    await tester.pumpAndSettle();
    expect(find.text('Hoy'), findsOneWidget);
    expect(enTarjeta('tarjeta_ventas', r'$5.000'), findsOneWidget);
  });

  testWidgets('cifras grandes no desbordan en un celular pequeño',
      (tester) async {
    tester.view.physicalSize = const Size(720, 1560);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await vender(123456789);
    await vender(98765432, fiado: true);

    await montar(tester);

    expect(tester.takeException(), isNull);
  });

  testWidgets('Gastos lleva borde rojo claro y Ganancia borde verde claro',
      (tester) async {
    await montar(tester);

    Color borde(String clave) {
      final material = tester.widget<Material>(find
          .descendant(
              of: find.byKey(Key(clave)), matching: find.byType(Material))
          .first);
      return (material.shape! as RoundedRectangleBorder).side.color;
    }

    expect(borde('tarjeta_gastos'), ColoresApp.claro.saleSuave);
    expect(borde('tarjeta_ganancia'), ColoresApp.claro.entraSuave);
  });

  testWidgets('la etiqueta de la tarjeta principal va en Nunito',
      (tester) async {
    await montar(tester);

    final etiqueta = tester.widget<Text>(find.text('Ventas de hoy'));
    expect(etiqueta.style!.fontFamily, 'Nunito');
    expect(etiqueta.style!.fontVariations,
        contains(const FontVariation('wght', 800)));
  });

  testWidgets('la tarjeta de ventas muestra lo recibido por medio de pago',
      (tester) async {
    await vender(5000);
    await db.into(db.ventas).insert(VentasCompanion.insert(
          monto: 3000,
          fecha: DateTime.now(),
          usuarioId: ana,
          medioPago: const Value(MedioPago.transferencia),
        ));
    await vender(9000, fiado: true);

    await montar(tester);

    expect(
        enTarjeta('tarjeta_ventas',
            r'Recibido: efectivo $5.000 · transferencias $3.000'),
        findsOneWidget);
  });

  Future<void> montarConSesion(WidgetTester tester, String rol) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = await containerConSesion(db, nombre: 'Caro', rol: rol);
    addTearDown(container.dispose);
    await tester.pumpWidget(appDePrueba(container,
        inicio: const Scaffold(body: ResumenScreen())));
    await tester.pumpAndSettle();
  }

  testWidgets('el administrador ve Ver reportes y lo abre', (tester) async {
    await montarConSesion(tester, 'admin');

    await tester.tap(find.byKey(const Key('boton_ver_reportes')));
    await tester.pumpAndSettle();

    expect(find.byType(ReportesScreen), findsOneWidget);
  });

  testWidgets('el vendedor no ve Ver reportes', (tester) async {
    await montarConSesion(tester, 'vendedor');

    expect(find.byKey(const Key('boton_ver_reportes')), findsNothing);
  });

  testWidgets('la tarjeta del día compara con ayer y muestra la mini gráfica',
      (tester) async {
    final hoy = DateTime.now();
    await vender(11200, fecha: hoy);
    await vender(10000, fecha: hoy.subtract(const Duration(days: 1)));
    await montar(tester);
    expect(find.text('Ventas de hoy'), findsOneWidget);
    expect(enTarjeta('tarjeta_ventas', '▲ 12 % vs. ayer'), findsOneWidget);
    expect(
        find.descendant(
            of: find.byKey(const Key('tarjeta_ventas')),
            matching: find.byKey(const Key('mini_grafica'))),
        findsOneWidget);
  });

  testWidgets('otro día: título con fecha y "el día anterior"', (tester) async {
    final hoy = inicioDelDia(DateTime.now());
    await vender(5000, fecha: hoy.subtract(const Duration(days: 1)));
    await montar(tester);
    await tester.tap(find.byKey(const Key('boton_dia_anterior')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Ventas del '), findsOneWidget);
    expect(enTarjeta('tarjeta_ventas', 'El día anterior no hubo ventas'),
        findsOneWidget);
  });

  testWidgets('sin ventas ni ayer ni hoy no hay etiqueta de comparación',
      (tester) async {
    await montar(tester);
    expect(find.byKey(const Key('comparacion_ventas')), findsNothing);
  });

  testWidgets('Venta y Gasto quedan fijos abajo, fuera de la lista',
      (tester) async {
    await montar(tester);
    final barra = find.byKey(const Key('barra_acciones_inicio'));
    expect(
        find.descendant(
            of: barra, matching: find.byKey(const Key('boton_nueva_venta'))),
        findsOneWidget);
    expect(
        find.descendant(
            of: barra, matching: find.byKey(const Key('boton_nuevo_gasto'))),
        findsOneWidget);
    expect(
        find.descendant(
            of: find.byType(ListView),
            matching: find.byKey(const Key('boton_nueva_venta'))),
        findsNothing);
  });

  testWidgets('el admin ve Por vendedor con el enlace a reportes',
      (tester) async {
    await montarConSesion(tester, 'admin');
    final tarjeta = find.byKey(const Key('tarjeta_por_vendedor'));
    expect(
        find.descendant(
            of: tarjeta, matching: find.byKey(const Key('boton_ver_reportes'))),
        findsOneWidget);
  });

  testWidgets('el admin abre Reportes tocando la mini gráfica', (tester) async {
    await montarConSesion(tester, 'admin');
    await tester.tap(find.byKey(const Key('mini_grafica')));
    await tester.pumpAndSettle();
    expect(find.byType(ReportesScreen), findsOneWidget);
  });
}
