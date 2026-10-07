import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/sesion_provider.dart';
import 'package:app_ventas/repositories/inventario_repository.dart';
import 'package:app_ventas/repositories/producto_repository.dart';
import 'package:app_ventas/repositories/proveedor_repository.dart';
import 'package:app_ventas/screens/inventario/inventario_screen.dart';
import 'package:app_ventas/screens/inventario/recibir_mercancia_screen.dart';
import 'package:app_ventas/ui/boton_principal.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/montaje.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  bool habilitado(WidgetTester tester, String clave) =>
      tester.widget<BotonPrincipal>(find.byKey(Key(clave))).onPressed != null;

  /// Postobón con Coca ($900, quedan 2, mín. 6, hasta 24 → 22) y Pan ($400,
  /// quedan 1, mín. 5 → 9); y Agua sin proveedor (quedan 0, mín. 0 → 1).
  Future<(int, int, int, int)> preparar(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final container = await containerConSesion(db);
    addTearDown(container.dispose);
    final ana = container.read(sesionProvider).usuarioActivo!;
    final postobon = await ProveedorRepository(db).crear(nombre: 'Postobón');
    final productos = ProductoRepository(db);
    final coca = await productos.guardarProducto(
        nombre: 'Coca',
        precio: 1500,
        proveedores: [
          ProveedorDeProducto(proveedorId: postobon, precioCompra: 900, preferido: true),
        ]);
    final pan = await productos.guardarProducto(
        nombre: 'Pan',
        precio: 600,
        proveedores: [
          ProveedorDeProducto(proveedorId: postobon, precioCompra: 400, preferido: true),
        ]);
    final agua = await productos.guardarProducto(nombre: 'Agua', precio: 1000);
    final inv = InventarioRepository(db, reloj: () => DateTime(2026, 10, 7, 8));
    await inv.activarControl(coca, cantidad: 2, minimo: 6, por: ana);
    await inv.cambiarPedirHasta(coca, 24);
    await inv.activarControl(pan, cantidad: 1, minimo: 5, por: ana);
    await inv.activarControl(agua, cantidad: 0, minimo: 0, por: ana);
    await tester.pumpWidget(appDePrueba(container,
        inicio: const Scaffold(body: InventarioScreen())));
    await tester.pumpAndSettle();
    return (postobon, coca, pan, agua);
  }

  testWidgets('muestra sugeridos, precios y total, y se puede editar',
      (tester) async {
    final (postobon, coca, pan, _) = await preparar(tester);

    await tester.tap(find.byKey(Key('ver_pedido_$postobon')));
    await tester.pumpAndSettle();

    expect(find.text('Pedido sugerido · Postobón'), findsOneWidget);
    expect(find.text('quedan 2 · mín. 6 · hasta 24'), findsOneWidget);
    expect(find.text('quedan 1 · mín. 5'), findsOneWidget);
    expect(
        tester.widget<Text>(find.byKey(Key('cantidad_pedido_$coca'))).data, '22');
    expect(
        tester.widget<Text>(find.byKey(Key('cantidad_pedido_$pan'))).data, '9');
    expect(find.text(r'$900 c/u'), findsOneWidget);
    expect(find.text(r'Total estimado $23.400'), findsOneWidget);

    await tester.tap(find.byKey(Key('restar_pedido_$coca')));
    await tester.tap(find.byKey(Key('sumar_pedido_$pan')));
    await tester.pump();
    expect(find.text(r'Total estimado $22.900'), findsOneWidget);
  });

  testWidgets('Recibir este pedido abre Recibir lleno y suma existencias',
      (tester) async {
    final (postobon, coca, pan, _) = await preparar(tester);
    await tester.tap(find.byKey(Key('ver_pedido_$postobon')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('boton_recibir_pedido')));
    await tester.pumpAndSettle();
    expect(find.byType(RecibirMercanciaScreen), findsOneWidget);
    expect(find.text(r'Total $23.400'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('boton_guardar_recibir')));
    await tester.tap(find.byKey(const Key('boton_guardar_recibir')));
    await tester.pumpAndSettle();

    expect(find.byType(InventarioScreen), findsOneWidget);
    expect(find.text(r'Mercancía recibida · $23.400'), findsOneWidget);
    final inv = InventarioRepository(db);
    expect(await inv.existencias(coca), 24);
    expect(await inv.existencias(pan), 10);
  });

  testWidgets('sin proveedor: sin precio y Recibir sin proveedor elegido',
      (tester) async {
    final (_, _, _, agua) = await preparar(tester);

    await tester.scrollUntilVisible(find.byKey(const Key('ver_pedido_sin')), 200);
    await tester.tap(find.byKey(const Key('ver_pedido_sin')));
    await tester.pumpAndSettle();

    expect(find.text('Pedido sugerido · Sin proveedor'), findsOneWidget);
    expect(find.text('Sin precio'), findsOneWidget);
    expect(find.text(r'Total estimado $0'), findsOneWidget);

    await tester.tap(find.byKey(Key('restar_pedido_$agua')));
    await tester.pump();
    expect(habilitado(tester, 'boton_recibir_pedido'), isFalse);

    await tester.tap(find.byKey(Key('sumar_pedido_$agua')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('boton_recibir_pedido')));
    await tester.pumpAndSettle();
    expect(find.byType(RecibirMercanciaScreen), findsOneWidget);
    expect(habilitado(tester, 'boton_guardar_recibir'), isFalse);
  });

  testWidgets('un proveedor desactivado no llega elegido a Recibir',
      (tester) async {
    final (postobon, _, _, _) = await preparar(tester);
    await ProveedorRepository(db).desactivar(postobon);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(Key('ver_pedido_$postobon')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('boton_recibir_pedido')));
    await tester.pumpAndSettle();

    expect(find.byType(RecibirMercanciaScreen), findsOneWidget);
    expect(habilitado(tester, 'boton_guardar_recibir'), isFalse);
  });
}
