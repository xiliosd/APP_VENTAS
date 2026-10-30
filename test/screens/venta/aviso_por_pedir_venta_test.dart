import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/aviso_por_pedir_provider.dart';
import 'package:app_ventas/providers/database_provider.dart';
import 'package:app_ventas/providers/repository_providers.dart';
import 'package:app_ventas/providers/sesion_provider.dart';
import 'package:app_ventas/repositories/inventario_repository.dart';
import 'package:app_ventas/repositories/producto_repository.dart';
import 'package:app_ventas/screens/venta/registrar_venta_screen.dart';
import 'package:app_ventas/util/aviso_existencias.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/montaje.dart';

class _InventarioQueFalla extends InventarioRepository {
  _InventarioQueFalla(super.db);

  @override
  Future<List<AvisoExistencias>> avisosTrasVenta(Map<int, int> antes) =>
      throw StateError('falla simulada');
}

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late int productoId;
  final navegador = GlobalKey<NavigatorState>();

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    productoId = await ProductoRepository(db)
        .guardarProducto(nombre: 'Gaseosa', precio: 4500);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> abrirVenta(WidgetTester tester, {bool falla = false}) async {
    container = await containerConSesion(
      db,
      overrides: [
        if (falla)
          inventarioRepositoryProvider.overrideWith(
            (ref) => _InventarioQueFalla(ref.watch(databaseProvider)),
          ),
      ],
    );
    final usuario = container.read(sesionProvider).usuarioActivo!;
    // Hay 6 y el mínimo es 5: vender 1 deja 5, justo en el mínimo.
    // El conteo se fecha una hora antes: la fecha se guarda en segundos y una
    // venta en el mismo segundo no contaría como posterior al conteo.
    await InventarioRepository(
      db,
      reloj: () => DateTime.now().subtract(const Duration(hours: 1)),
    ).activarControl(productoId, cantidad: 6, minimo: 5, por: usuario);
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(appDePrueba(container, navegador: navegador));
    navegador.currentState!.push(
      MaterialPageRoute(builder: (_) => const RegistrarVentaScreen()),
    );
    await tester.pumpAndSettle();
  }

  Future<void> cobrarUnProducto(WidgetTester tester) async {
    await tester.tap(find.byKey(Key('producto_$productoId')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('boton_cobrar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pago_efectivo')));
    // La base responde en tiempo real: se espera a que la pantalla se cierre.
    for (var i = 0; i < 50; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pumpAndSettle();
      if (find.byType(RegistrarVentaScreen).evaluate().isEmpty) break;
    }
  }

  testWidgets('cobrar un producto que cruza el mínimo deja el aviso', (
    tester,
  ) async {
    await abrirVenta(tester);
    await cobrarUnProducto(tester);

    final avisos = container.read(avisoPorPedirProvider);
    expect(avisos.single.productoId, productoId);
    expect(avisos.single.existencias, 5);
  });

  testWidgets('Deshacer elimina la venta y quita el aviso', (tester) async {
    await abrirVenta(tester);
    await cobrarUnProducto(tester);
    expect(container.read(avisoPorPedirProvider), hasLength(1));

    await tester.tap(find.text('Deshacer'));
    await tester.pumpAndSettle();

    expect(await db.select(db.ventas).get(), isEmpty);
    expect(container.read(avisoPorPedirProvider), isEmpty);
  });

  testWidgets(
    'si avisosTrasVenta falla, la venta queda, sale "Venta registrada" y se '
    'cierra',
    (tester) async {
      await abrirVenta(tester, falla: true);
      await cobrarUnProducto(tester);

      expect(await db.select(db.ventas).get(), hasLength(1));
      expect(find.textContaining('Venta registrada'), findsOneWidget);
      expect(find.byType(RegistrarVentaScreen), findsNothing);
      expect(container.read(avisoPorPedirProvider), isEmpty);
    },
  );
}
