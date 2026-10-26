import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/repositories/cliente_repository.dart';
import 'package:app_ventas/screens/venta/registrar_venta_screen.dart';
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
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(appDePrueba(container, navegador: navegador));
    navegador.currentState!.push(
      MaterialPageRoute(builder: (_) => const RegistrarVentaScreen()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('monto_rapido_2000')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('boton_cobrar')));
    await tester.pumpAndSettle();
  }

  Future<void> elegirClienteExistente(WidgetTester tester, int id) async {
    await tester.tap(find.byKey(const Key('quien_compra')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('campo_cliente')), 'Pedro');
    await tester.pump();
    await tester.tap(find.byKey(Key('cliente_sugerido_$id')));
    await tester.pumpAndSettle();
  }

  Future<void> crearClienteNuevo(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('quien_compra')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('campo_cliente')), 'Luisa');
    await tester.pump();
    await tester.tap(find.byKey(const Key('boton_cliente_nuevo')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('campo_nombre_cliente')),
      'Luisa',
    );
    await tester.enterText(
      find.byKey(const Key('campo_apellido_cliente')),
      'Mora',
    );
    await tester.tap(find.byKey(const Key('boton_continuar_cliente')));
    await tester.pumpAndSettle();
  }

  testWidgets('efectivo sin elegir cliente registra la venta sin cliente', (
    tester,
  ) async {
    await abrirVenta(tester);
    expect(
      find.text('¿Quién compra? De paso', findRichText: true),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('pago_efectivo')));
    await tester.pumpAndSettle();

    final venta = (await db.select(db.ventas).get()).single;
    expect(venta.clienteId, isNull);
    expect(await db.select(db.clientes).get(), isEmpty);
  });

  testWidgets('efectivo con cliente existente guarda su clienteId', (
    tester,
  ) async {
    final id = await ClienteRepository(db)
        .crearCliente(nombre: 'Pedro', apellido: 'Gómez');
    await abrirVenta(tester);
    await elegirClienteExistente(tester, id);
    await tester.tap(find.byKey(const Key('pago_efectivo')));
    await tester.pumpAndSettle();

    final venta = (await db.select(db.ventas).get()).single;
    expect(venta.clienteId, id);
    expect(venta.esFiado, isFalse);
    expect(await db.select(db.clientes).get(), hasLength(1));
  });

  testWidgets(
    'transferencia con cliente nuevo lo crea y lo guarda en la venta',
    (tester) async {
      await abrirVenta(tester);
      await crearClienteNuevo(tester);
      await tester.tap(find.byKey(const Key('pago_transferencia')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('boton_qr_recibido')));
      await tester.pumpAndSettle();

      final clientes = await db.select(db.clientes).get();
      final venta = (await db.select(db.ventas).get()).single;
      expect(clientes.single.nombre, 'Luisa');
      expect(venta.clienteId, clientes.single.id);
      expect(venta.medioPago, MedioPago.transferencia);
    },
  );

  testWidgets(
    'deshacer la venta deja el cliente creado y no lo duplica al volver a cobrar',
    (tester) async {
      await abrirVenta(tester);
      await crearClienteNuevo(tester);
      await tester.tap(find.byKey(const Key('pago_efectivo')));
      await tester.pumpAndSettle();
      final clienteId = (await db.select(db.clientes).get()).single.id;

      await tester.tap(find.text('Deshacer'));
      await tester.pumpAndSettle();
      expect(await db.select(db.ventas).get(), isEmpty);
      expect(await db.select(db.clientes).get(), hasLength(1));

      // Un nuevo cobro con el cliente ya creado lo reutiliza, no lo duplica.
      navegador.currentState!.push(
        MaterialPageRoute(builder: (_) => const RegistrarVentaScreen()),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('monto_rapido_2000')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('boton_cobrar')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('quien_compra')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('campo_cliente')), 'Luisa');
      await tester.pump();
      await tester.tap(find.byKey(Key('cliente_sugerido_$clienteId')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('pago_efectivo')));
      await tester.pumpAndSettle();
      expect(await db.select(db.clientes).get(), hasLength(1));
      expect((await db.select(db.ventas).get()).single.clienteId, clienteId);
    },
  );
}
