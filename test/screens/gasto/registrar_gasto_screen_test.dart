import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/screens/gasto/registrar_gasto_screen.dart';
import 'package:app_ventas/ui/boton_principal.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/montaje.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  final navegador = GlobalKey<NavigatorState>();

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    container = await containerConSesion(db);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> abrirGasto(WidgetTester tester) async {
    await tester.pumpWidget(appDePrueba(container, navegador: navegador));
    navegador.currentState!.push(
        MaterialPageRoute(builder: (_) => const RegistrarGastoScreen()));
    await tester.pumpAndSettle();
  }

  testWidgets('registrar un gasto lo guarda, vuelve y lo confirma',
      (tester) async {
    await abrirGasto(tester);

    await tester.tap(find.byKey(const Key('tecla_monto_2')));
    await tester.tap(find.byKey(const Key('tecla_monto_0')));
    await tester.tap(find.byKey(const Key('tecla_monto_000')));
    await tester.enterText(
        find.byKey(const Key('campo_descripcion_gasto')), 'Bolsas');
    await tester.tap(find.byKey(const Key('boton_registrar_gasto')));
    await tester.pumpAndSettle();

    final gasto = (await db.select(db.gastos).get()).single;
    expect(gasto.monto, 20000);
    expect(gasto.descripcion, 'Bolsas');
    expect(find.text('Inicio'), findsOneWidget);
    expect(find.text(r'Gasto registrado · $20.000'), findsOneWidget);
  });

  testWidgets('con monto 0 no se puede registrar', (tester) async {
    await abrirGasto(tester);

    final boton = tester
        .widget<BotonPrincipal>(find.byKey(const Key('boton_registrar_gasto')));
    expect(boton.onPressed, isNull);
  });

  testWidgets('una categoría llena la descripción y se guarda', (tester) async {
    await abrirGasto(tester);
    await tester.tap(find.byKey(const Key('tecla_monto_5')));
    await tester.tap(find.byKey(const Key('tecla_monto_000')));
    await tester.tap(find.byKey(const Key('categoria_mercancia')));
    await tester.pump();
    expect(find.widgetWithText(TextField, 'Mercancía'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('campo_descripcion_gasto')),
        'Mercancía · gaseosas');
    await tester.tap(find.byKey(const Key('categoria_servicios')));
    await tester.pump();
    expect(find.widgetWithText(TextField, 'Servicios · gaseosas'),
        findsOneWidget);
    await tester.tap(find.byKey(const Key('boton_registrar_gasto')));
    await tester.pumpAndSettle();
    expect((await db.select(db.gastos).get()).single.descripcion,
        'Servicios · gaseosas');
  });

  testWidgets('Otro y volver a tocar la categoría la quitan', (tester) async {
    await abrirGasto(tester);
    await tester.enterText(
        find.byKey(const Key('campo_descripcion_gasto')), 'taxi');
    await tester.tap(find.byKey(const Key('categoria_transporte')));
    await tester.pump();
    expect(find.widgetWithText(TextField, 'Transporte · taxi'), findsOneWidget);
    await tester.tap(find.byKey(const Key('categoria_transporte')));
    await tester.pump();
    expect(find.widgetWithText(TextField, 'taxi'), findsOneWidget);
    await tester.tap(find.byKey(const Key('categoria_arriendo')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('categoria_otro')));
    await tester.pump();
    expect(find.widgetWithText(TextField, 'taxi'), findsOneWidget);
  });

  testWidgets('el monto se muestra grande mientras se teclea', (tester) async {
    await abrirGasto(tester);
    await tester.tap(find.byKey(const Key('tecla_monto_2')));
    await tester.tap(find.byKey(const Key('tecla_monto_000')));
    await tester.pumpAndSettle();
    expect(
        find.descendant(
            of: find.byKey(const Key('texto_monto_gasto')),
            matching: find.text(r'$2.000')),
        findsOneWidget);
  });
}
