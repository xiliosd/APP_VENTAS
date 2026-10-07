import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/sesion_provider.dart';
import 'package:app_ventas/repositories/configuracion_repository.dart';
import 'package:app_ventas/repositories/inventario_repository.dart';
import 'package:app_ventas/repositories/producto_repository.dart';
import 'package:app_ventas/repositories/proveedor_repository.dart';
import 'package:app_ventas/screens/home/home_screen.dart';
import 'package:app_ventas/screens/inventario/detalle_inventario_screen.dart';
import 'package:app_ventas/screens/inventario/inventario_screen.dart';
import 'package:app_ventas/ui/colores_app.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/montaje.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<(ProviderContainer, Usuario)> montar(WidgetTester tester,
      {String rol = 'admin'}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final container = await containerConSesion(db, rol: rol);
    addTearDown(container.dispose);
    final usuario = container.read(sesionProvider).usuarioActivo!;
    return (container, usuario);
  }

  Future<void> pintar(WidgetTester tester, ProviderContainer container,
      {Widget inicio = const Scaffold(body: InventarioScreen())}) async {
    await tester.pumpWidget(appDePrueba(container, inicio: inicio));
    await tester.pumpAndSettle();
  }

  Future<int> producto(String nombre, {int? proveedor}) =>
      ProductoRepository(db).guardarProducto(
        nombre: nombre,
        precio: 1000,
        proveedores: proveedor == null
            ? const []
            : [
                ProveedorDeProducto(
                    proveedorId: proveedor, precioCompra: 500, preferido: true),
              ],
      );

  testWidgets('sin productos con control muestra el estado vacío',
      (tester) async {
    final (container, _) = await montar(tester);
    await pintar(tester, container);
    expect(find.text('Aún no controlas existencias'), findsOneWidget);
    expect(find.byKey(const Key('boton_recibir_mercancia')), findsOneWidget);
  });

  testWidgets('abre en Por pedir y Todos marca en rojo lo que falta',
      (tester) async {
    final (container, ana) = await montar(tester);
    final postobon = await ProveedorRepository(db).crear(nombre: 'Postobón');
    final coca = await producto('Coca', proveedor: postobon);
    final pan = await producto('Pan');
    final inv = InventarioRepository(db);
    await inv.activarControl(coca, cantidad: 2, minimo: 6, por: ana);
    await inv.activarControl(pan, cantidad: 12, minimo: 5, por: ana);
    await pintar(tester, container);

    expect(find.text('Por pedir (1)'), findsOneWidget);
    expect(find.text('Postobón · 1 producto'), findsOneWidget);
    expect(find.text('quedan 2 · mín. 6'), findsOneWidget);

    await tester.tap(find.text('Todos'));
    await tester.pumpAndSettle();
    final deCoca = tester.widget<Text>(find.byKey(Key('existencias_$coca')));
    final dePan = tester.widget<Text>(find.byKey(Key('existencias_$pan')));
    expect(deCoca.data, '2 u');
    expect(deCoca.style?.color, ColoresApp.sale);
    expect(dePan.data, '12 u');
    expect(dePan.style?.color, isNot(ColoresApp.sale));
  });

  testWidgets('sin nada por pedir abre en Todos', (tester) async {
    final (container, ana) = await montar(tester);
    final pan = await producto('Pan');
    await InventarioRepository(db)
        .activarControl(pan, cantidad: 12, minimo: 5, por: ana);
    await pintar(tester, container);

    expect(find.text('Todos'), findsOneWidget);
    expect(find.text('12 u'), findsOneWidget);
    await tester.tap(find.text('Por pedir (0)'));
    await tester.pumpAndSettle();
    expect(find.text('Nada por pedir'), findsOneWidget);
  });

  testWidgets('el detalle muestra historial y ajusta el conteo',
      (tester) async {
    final (container, ana) = await montar(tester);
    final pan = await producto('Pan');
    await InventarioRepository(db, reloj: () => DateTime(2026, 10, 7, 8))
        .activarControl(pan, cantidad: 12, minimo: 5, por: ana);
    await pintar(tester, container);

    await tester.tap(find.byKey(Key('inventario_item_$pan')));
    await tester.pumpAndSettle();
    expect(find.byType(DetalleInventarioScreen), findsOneWidget);
    expect(find.text('Ana · conteo inicial 12'), findsOneWidget);

    await tester.tap(find.byKey(const Key('boton_ajustar_conteo')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('campo_conteo')), '9');
    await tester.tap(find.byKey(const Key('boton_guardar_conteo')));
    await tester.pumpAndSettle();

    expect(find.text('Ana · 12 → 9 (−3)'), findsOneWidget);
    expect(find.text('9 u'), findsOneWidget);
  });

  testWidgets('anular una entrada desde su detalle', (tester) async {
    final (container, ana) = await montar(tester);
    final postobon = await ProveedorRepository(db).crear(nombre: 'Postobón');
    final pan = await producto('Pan', proveedor: postobon);
    final inv = InventarioRepository(db, reloj: () => DateTime(2026, 10, 7, 8));
    await inv.activarControl(pan, cantidad: 2, minimo: 0, por: ana);
    final entrada = await InventarioRepository(db,
            reloj: () => DateTime(2026, 10, 7, 9))
        .recibirMercancia(
      proveedorId: postobon,
      lineas: [LineaRecibida(productoId: pan, cantidad: 24, precioCompra: 400)],
      por: ana,
    );
    await pintar(tester, container);

    await tester.scrollUntilVisible(find.byKey(Key('entrada_$entrada')), 200);
    await tester.tap(find.byKey(Key('entrada_$entrada')));
    await tester.pumpAndSettle();
    expect(find.text(r'24 × Pan · $400'), findsOneWidget);
    await tester.tap(find.byKey(const Key('boton_anular_entrada')));
    await tester.pumpAndSettle();
    expect(find.text('¿Anular esta entrada?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirmar_anular_entrada')));
    await tester.pumpAndSettle();

    expect(find.text('Entrada anulada'), findsWidgets);
    expect(await InventarioRepository(db).existencias(pan), 2);
  });

  testWidgets('el vendedor ve la pestaña Inventario', (tester) async {
    await ConfiguracionRepository(db).guardarNombreTienda('La Esquina');
    final (container, _) = await montar(tester, rol: 'vendedor');
    await pintar(tester, container, inicio: const HomeScreen());

    expect(find.text('Inventario'), findsOneWidget);
    await tester.tap(find.text('Inventario'));
    await tester.pumpAndSettle();
    expect(find.byType(InventarioScreen), findsOneWidget);
  });
}
