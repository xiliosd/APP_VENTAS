import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/sesion_provider.dart';
import 'package:app_ventas/repositories/inventario_repository.dart';
import 'package:app_ventas/screens/configuracion/producto_screen.dart';
import 'package:app_ventas/screens/inventario/detalle_inventario_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/montaje.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> montar(WidgetTester tester, {required String rol}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final container = await containerConSesion(db, rol: rol);
    addTearDown(container.dispose);
    final usuario = container.read(sesionProvider).usuarioActivo!;
    final coca = await db
        .into(db.productos)
        .insert(ProductosCompanion.insert(nombre: 'Coca', precio: 3000));
    await InventarioRepository(db)
        .activarControl(coca, cantidad: 2, minimo: 6, por: usuario);
    await tester.pumpWidget(
      appDePrueba(container, inicio: DetalleInventarioScreen(productoId: coca)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'admin ve Editar en el detalle de inventario y abre el producto',
    (tester) async {
      await montar(tester, rol: 'admin');
      final boton = find.byKey(const Key('boton_editar_producto'));
      expect(boton, findsOneWidget);
      expect(find.byTooltip('Editar'), findsOneWidget);
      await tester.tap(boton);
      await tester.pumpAndSettle();
      expect(find.byType(ProductoScreen), findsOneWidget);
    },
  );

  testWidgets('vendedor no ve Editar en el detalle de inventario', (
    tester,
  ) async {
    await montar(tester, rol: 'vendedor');
    expect(find.byKey(const Key('boton_editar_producto')), findsNothing);
  });

  testWidgets('al guardar desde el detalle de inventario avisa Producto guardado', (
    tester,
  ) async {
    await montar(tester, rol: 'admin');
    await tester.tap(find.byKey(const Key('boton_editar_producto')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('boton_guardar_producto')));
    await tester.tap(find.byKey(const Key('boton_guardar_producto')));
    await tester.pumpAndSettle();
    expect(find.byType(ProductoScreen), findsNothing);
    expect(find.text('Producto guardado'), findsOneWidget);
  });
}
