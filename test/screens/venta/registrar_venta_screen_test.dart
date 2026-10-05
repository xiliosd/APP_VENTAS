import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/screens/venta/registrar_venta_screen.dart';
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

  Future<void> abrirVenta(WidgetTester tester) async {
    // Pantalla de celular (411x914 dp): en la de prueba por defecto (800x600)
    // la barra de cobro tapa los montos rápidos.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester
        .pumpWidget(appDePrueba(container, navegador: navegador));
    navegador.currentState!.push(
        MaterialPageRoute(builder: (_) => const RegistrarVentaScreen()));
    await tester.pumpAndSettle();
  }

  BotonPrincipal botonCobrar(WidgetTester tester) =>
      tester.widget<BotonPrincipal>(find.byKey(const Key('boton_cobrar')));

  testWidgets('tocar montos suma al ticket y solo Cobrar registra la venta',
      (tester) async {
    await abrirVenta(tester);

    await tester.tap(find.byKey(const Key('monto_rapido_5000')));
    await tester.tap(find.byKey(const Key('monto_rapido_5000')));
    await tester.tap(find.byKey(const Key('monto_rapido_1000')));
    await tester.pump();

    expect(await db.select(db.ventas).get(), isEmpty);
    expect(find.text(r'Cobrar $11.000'), findsOneWidget);
    expect(find.text('3 artículos'), findsOneWidget);

    await tester.tap(find.byKey(const Key('boton_cobrar')));
    await tester.pumpAndSettle();

    final ventas = await db.select(db.ventas).get();
    expect(ventas.single.monto, 11000);
    expect(ventas.single.esFiado, isFalse);
    expect(find.text('Inicio'), findsOneWidget);
    expect(find.text(r'Venta registrada · $11.000'), findsOneWidget);
  });

  testWidgets('con el ticket vacío no se puede cobrar', (tester) async {
    await abrirVenta(tester);

    expect(botonCobrar(tester).onPressed, isNull);
    expect(find.text('Agrega algo para cobrar'), findsOneWidget);
  });

  testWidgets('Deshacer elimina la venta recién registrada', (tester) async {
    await db.into(db.ventas).insert(VentasCompanion.insert(
        monto: 999, fecha: DateTime.now(), usuarioId: 1));
    await abrirVenta(tester);

    await tester.tap(find.byKey(const Key('monto_rapido_2000')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('boton_cobrar')));
    await tester.pumpAndSettle();
    expect(await db.select(db.ventas).get(), hasLength(2));

    await tester.tap(find.text('Deshacer'));
    await tester.pumpAndSettle();

    final ventas = await db.select(db.ventas).get();
    expect(ventas.single.monto, 999);
  });

  testWidgets('fiado sin cliente no deja cobrar; con cliente nuevo sí',
      (tester) async {
    await abrirVenta(tester);

    await tester.tap(find.text('Fiado'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('monto_rapido_2000')));
    await tester.pump();
    expect(botonCobrar(tester).onPressed, isNull);
    expect(find.text('Falta elegir el cliente'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('campo_cliente')), 'Don Pedro');
    await tester.pump();
    await tester.tap(find.byKey(const Key('boton_cliente_nuevo')));
    await tester.pump();
    expect(find.text(r'Fiar $2.000 a Don Pedro'), findsOneWidget);

    await tester.tap(find.byKey(const Key('boton_cobrar')));
    await tester.pumpAndSettle();

    final ventas = await db.select(db.ventas).get();
    final clientes = await db.select(db.clientes).get();
    expect(ventas.single.esFiado, isTrue);
    expect(clientes.single.nombre, 'Don Pedro');
    expect(ventas.single.clienteId, clientes.single.id);
  });

  testWidgets('elegir un cliente existente no crea un duplicado',
      (tester) async {
    final pedro = await db
        .into(db.clientes)
        .insert(ClientesCompanion.insert(nombre: 'Don Pedro'));
    await abrirVenta(tester);

    await tester.tap(find.text('Fiado'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('monto_rapido_1000')));
    await tester.enterText(find.byKey(const Key('campo_cliente')), 'don pedro');
    await tester.pump();
    expect(find.byKey(const Key('boton_cliente_nuevo')), findsNothing);
    await tester.tap(find.byKey(Key('cliente_sugerido_$pedro')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('boton_cobrar')));
    await tester.pumpAndSettle();

    expect(await db.select(db.clientes).get(), hasLength(1));
    expect((await db.select(db.ventas).get()).single.clienteId, pedro);
  });

  testWidgets('un ticket con un solo producto guarda el producto',
      (tester) async {
    final arepa = await db.into(db.productos).insert(
          ProductosCompanion.insert(nombre: 'Arepa', precio: 3500),
        );
    await abrirVenta(tester);

    await tester.tap(find.byKey(Key('producto_$arepa')));
    await tester.tap(find.byKey(Key('producto_$arepa')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('boton_cobrar')));
    await tester.pumpAndSettle();

    final venta = (await db.select(db.ventas).get()).single;
    expect(venta.monto, 7000);
    expect(venta.productoId, arepa);
  });

  testWidgets('Ver ticket permite restar y quitar líneas', (tester) async {
    final arepa = await db.into(db.productos).insert(
          ProductosCompanion.insert(nombre: 'Arepa', precio: 3500),
        );
    await abrirVenta(tester);

    await tester.tap(find.byKey(Key('producto_$arepa')));
    await tester.tap(find.byKey(Key('producto_$arepa')));
    await tester.tap(find.byKey(const Key('monto_rapido_1000')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('boton_ver_ticket')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(Key('restar_p$arepa')));
    await tester.pump();
    expect(find.text(r'Cobrar $4.500'), findsOneWidget);
    await tester.tap(find.byKey(const Key('quitar_m1000')));
    await tester.pump();
    expect(find.text(r'Cobrar $3.500'), findsOneWidget);
  });

  testWidgets('Otro monto agrega lo tecleado al ticket', (tester) async {
    await abrirVenta(tester);

    await tester.tap(find.byKey(const Key('boton_otro_monto')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tecla_monto_1')));
    await tester.tap(find.byKey(const Key('tecla_monto_2')));
    await tester.tap(find.byKey(const Key('tecla_monto_000')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('boton_agregar_monto')));
    await tester.pumpAndSettle();

    expect(find.text(r'Cobrar $12.000'), findsOneWidget);
  });

  testWidgets('salir sin cobrar descarta el ticket', (tester) async {
    await abrirVenta(tester);
    await tester.tap(find.byKey(const Key('monto_rapido_5000')));
    await tester.pump();

    navegador.currentState!.pop();
    await tester.pumpAndSettle();
    navegador.currentState!.push(
        MaterialPageRoute(builder: (_) => const RegistrarVentaScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Agrega algo para cobrar'), findsOneWidget);
    expect(await db.select(db.ventas).get(), isEmpty);
  });
}
