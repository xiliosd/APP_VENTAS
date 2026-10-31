import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/sesion_provider.dart';
import 'package:app_ventas/repositories/pedido_repository.dart';
import 'package:app_ventas/repositories/producto_repository.dart';
import 'package:app_ventas/repositories/proveedor_repository.dart';
import 'package:app_ventas/screens/inventario/inventario_screen.dart';
import 'package:app_ventas/screens/inventario/pedido_por_llegar_screen.dart';
import 'package:app_ventas/ui/boton_principal.dart';
import 'package:app_ventas/util/formato_moneda.dart';
import 'package:drift/drift.dart' show Value;
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

  /// Pedido de Postobón del 16 oct: 24 Coca a $900 y 10 Pan sin precio,
  /// hecho por quien tiene la sesión o, con [otroAutor], por Beto.
  Future<({int pedido, int postobon, int coca, int pan})> preparar(
    WidgetTester tester, {
    String rol = 'admin',
    bool otroAutor = false,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final container = await containerConSesion(db, rol: rol);
    addTearDown(container.dispose);
    final sesion = container.read(sesionProvider).usuarioActivo!;
    var autor = sesion;
    if (otroAutor) {
      final id = await db
          .into(db.usuarios)
          .insert(
            UsuariosCompanion.insert(
              nombre: 'Beto',
              rol: 'vendedor',
              pinHash: 'x',
            ),
          );
      autor = await (db.select(
        db.usuarios,
      )..where((u) => u.id.equals(id))).getSingle();
    }
    final postobon = await ProveedorRepository(db).crear(nombre: 'Postobón');
    final productos = ProductoRepository(db);
    final coca = await productos.guardarProducto(nombre: 'Coca', precio: 1500);
    final pan = await productos.guardarProducto(nombre: 'Pan', precio: 600);
    final pedido =
        await PedidoRepository(
          db,
          reloj: () => DateTime(2026, 10, 16, 8),
        ).guardarPedido(
          proveedorId: postobon,
          lineas: [
            LineaPedidoNueva(
              productoId: coca,
              cantidad: 24,
              precioEsperado: 900,
            ),
            LineaPedidoNueva(productoId: pan, cantidad: 10),
          ],
          por: autor,
        );
    await tester.pumpWidget(
      appDePrueba(container, inicio: const Scaffold(body: InventarioScreen())),
    );
    await tester.pumpAndSettle();
    return (pedido: pedido, postobon: postobon, coca: coca, pan: pan);
  }

  testWidgets('Inventario muestra la tarjeta Por llegar', (tester) async {
    final p = await preparar(tester);

    expect(find.text('POR LLEGAR'), findsOneWidget);
    final tarjeta = find.byKey(Key('pedido_por_llegar_${p.pedido}'));
    expect(tarjeta, findsOneWidget);
    expect(
      find.descendant(of: tarjeta, matching: find.text('Postobón')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: tarjeta,
        matching: find.text(r'pedido el 16 oct · 2 productos · $21.600'),
      ),
      findsOneWidget,
    );
    expect(habilitado(tester, 'llego_pedido_${p.pedido}'), isTrue);
  });

  testWidgets('sin pedidos no hay sección Por llegar', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final container = await containerConSesion(db);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      appDePrueba(container, inicio: const Scaffold(body: InventarioScreen())),
    );
    await tester.pumpAndSettle();

    expect(find.text('POR LLEGAR'), findsNothing);
  });

  testWidgets('con el proveedor inactivo no se puede recibir', (tester) async {
    final p = await preparar(tester);
    await ProveedorRepository(db).desactivar(p.postobon);
    await tester.pumpAndSettle();

    expect(
      find.text('Proveedor inactivo: actívalo para recibir'),
      findsOneWidget,
    );
    expect(habilitado(tester, 'llego_pedido_${p.pedido}'), isFalse);
  });

  testWidgets('el pedido se edita y guarda', (tester) async {
    final p = await preparar(tester);
    await tester.tap(find.byKey(Key('pedido_por_llegar_${p.pedido}')));
    await tester.pumpAndSettle();
    expect(find.byType(PedidoPorLlegarScreen), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(Key('cantidad_pedido_${p.coca}'))).data,
      '24',
    );

    await tester.tap(find.byKey(Key('restar_pedido_${p.coca}')));
    await tester.tap(find.byKey(Key('quitar_pedido_${p.pan}')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('boton_guardar_cambios_pedido')));
    await tester.pumpAndSettle();

    expect(find.byType(InventarioScreen), findsOneWidget);
    expect(find.text('Pedido actualizado'), findsOneWidget);
    final lineas = await db.select(db.lineasPedido).get();
    expect(
      [for (final l in lineas) (l.productoId, l.cantidad, l.precioEsperado)],
      [(p.coca, 23, 900)],
    );
  });

  testWidgets('se agrega un producto al pedido', (tester) async {
    final p = await preparar(tester);
    final agua = await ProductoRepository(db)
        .guardarProducto(nombre: 'Agua', precio: 1000);
    await tester.tap(find.byKey(Key('pedido_por_llegar_${p.pedido}')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('boton_agregar_producto_pedido')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('opcion_producto_recibir_$agua')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('boton_guardar_cambios_pedido')));
    await tester.pumpAndSettle();

    final lineas = await db.select(db.lineasPedido).get();
    expect(
      [for (final l in lineas) (l.productoId, l.cantidad)],
      [(p.coca, 24), (p.pan, 10), (agua, 1)],
    );
  });

  testWidgets('anular pide confirmación y lo saca de Por llegar', (
    tester,
  ) async {
    final p = await preparar(tester);
    await tester.tap(find.byKey(Key('pedido_por_llegar_${p.pedido}')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('boton_anular_pedido')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmar_anular_pedido')));
    await tester.pumpAndSettle();

    expect(find.byType(InventarioScreen), findsOneWidget);
    expect(find.text('Pedido anulado'), findsOneWidget);
    expect(find.text('POR LLEGAR'), findsNothing);
  });

  testWidgets('un vendedor no edita ni anula el pedido de otro', (
    tester,
  ) async {
    final p = await preparar(tester, rol: 'vendedor', otroAutor: true);
    await tester.tap(find.byKey(Key('pedido_por_llegar_${p.pedido}')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('boton_anular_pedido')), findsNothing);
    expect(find.byKey(const Key('boton_guardar_cambios_pedido')), findsNothing);
    expect(find.byKey(Key('sumar_pedido_${p.coca}')), findsNothing);
    expect(find.text('24 × Coca'), findsOneWidget);
  });

  testWidgets('al agregar un producto del proveedor usa su precio de compra', (
    tester,
  ) async {
    final p = await preparar(tester);
    final agua = await ProductoRepository(db).guardarProducto(
      nombre: 'Agua',
      precio: 1000,
      proveedores: [
        ProveedorDeProducto(
          proveedorId: p.postobon,
          precioCompra: 2500,
          preferido: true,
        ),
      ],
    );
    await tester.tap(find.byKey(Key('pedido_por_llegar_${p.pedido}')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('boton_agregar_producto_pedido')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('opcion_producto_recibir_$agua')));
    await tester.pumpAndSettle();

    // 24 × 900 + 1 × 2500
    expect(find.text('Total estimado ${formatoMoneda(24100)}'), findsOneWidget);
    await tester.tap(find.byKey(const Key('boton_guardar_cambios_pedido')));
    await tester.pumpAndSettle();

    final lineas = await db.select(db.lineasPedido).get();
    expect(
      [for (final l in lineas) (l.productoId, l.precioEsperado)],
      [(p.coca, 900), (p.pan, null), (agua, 2500)],
    );
  });

  testWidgets('si el pedido ya no está por llegar, lo dice al guardar', (
    tester,
  ) async {
    final p = await preparar(tester);
    await tester.tap(find.byKey(Key('pedido_por_llegar_${p.pedido}')));
    await tester.pumpAndSettle();
    await (db.update(db.pedidos)..where((x) => x.id.equals(p.pedido))).write(
      const PedidosCompanion(estado: Value(EstadoPedido.anulado)),
    );

    await tester.tap(find.byKey(const Key('boton_guardar_cambios_pedido')));
    await tester.pumpAndSettle();

    expect(find.text('Este pedido ya se recibió o se anuló'), findsOneWidget);
  });

  testWidgets(
    'si el pedido se cierra con la pantalla abierta, ya no se edita',
    (tester) async {
      final p = await preparar(tester);
      await tester.tap(find.byKey(Key('pedido_por_llegar_${p.pedido}')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('boton_anular_pedido')), findsOneWidget);
      await (db.update(db.pedidos)..where((x) => x.id.equals(p.pedido))).write(
        const PedidosCompanion(estado: Value(EstadoPedido.anulado)),
      );
      await tester.tap(find.byKey(const Key('boton_guardar_cambios_pedido')));
      await tester.pumpAndSettle();

      expect(find.text('Este pedido ya se recibió o se anuló'), findsOneWidget);
      expect(
        find.byKey(const Key('boton_guardar_cambios_pedido')),
        findsNothing,
      );
      expect(find.byKey(const Key('boton_anular_pedido')), findsNothing);
    },
  );

  testWidgets('sin permiso, lo dice al anular', (tester) async {
    // La sesión es la autora; luego el pedido pasa a ser de otro usuario.
    final p = await preparar(tester, rol: 'vendedor');
    final beto = await db
        .into(db.usuarios)
        .insert(
          UsuariosCompanion.insert(
            nombre: 'Beto',
            rol: 'vendedor',
            pinHash: 'x',
          ),
        );
    await tester.tap(find.byKey(Key('pedido_por_llegar_${p.pedido}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('boton_anular_pedido')));
    await tester.pumpAndSettle();
    // El pedido cambia de dueño mientras el diálogo de confirmación está abierto.
    await (db.update(db.pedidos)..where((x) => x.id.equals(p.pedido))).write(
      PedidosCompanion(usuarioId: Value(beto)),
    );
    await tester.tap(find.byKey(const Key('confirmar_anular_pedido')));
    await tester.pumpAndSettle();

    expect(
      find.text('No tienes permiso para cambiar este pedido'),
      findsOneWidget,
    );
  });

  testWidgets('el error se ve aunque la lista esté desplazada al final', (
    tester,
  ) async {
    final p = await preparar(tester);
    final repo = ProductoRepository(db);
    for (var n = 0; n < 15; n++) {
      final id = await repo.guardarProducto(nombre: 'Extra $n', precio: 500);
      await db
          .into(db.lineasPedido)
          .insert(
            LineasPedidoCompanion.insert(
              pedidoId: p.pedido,
              productoId: id,
              cantidad: 1,
            ),
          );
    }
    await tester.tap(find.byKey(Key('pedido_por_llegar_${p.pedido}')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('boton_anular_pedido')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await (db.update(db.pedidos)..where((x) => x.id.equals(p.pedido))).write(
      const PedidosCompanion(estado: Value(EstadoPedido.anulado)),
    );

    await tester.tap(find.byKey(const Key('boton_anular_pedido')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmar_anular_pedido')));
    await tester.pumpAndSettle();

    final error = find.text('Este pedido ya se recibió o se anuló');
    expect(error, findsOneWidget);
    final pantalla = tester.view.physicalSize / tester.view.devicePixelRatio;
    final rect = tester.getRect(error);
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(rect.bottom, lessThanOrEqualTo(pantalla.height));
    expect(error.hitTestable(), findsOneWidget);
  });
}
