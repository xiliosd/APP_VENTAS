import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/sesion_provider.dart';
import 'package:app_ventas/repositories/inventario_repository.dart';
import 'package:app_ventas/repositories/pedido_repository.dart';
import 'package:app_ventas/repositories/producto_repository.dart';
import 'package:app_ventas/repositories/proveedor_repository.dart';
import 'package:app_ventas/screens/inventario/detalle_entrada_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/montaje.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  /// Pedido de 24 Coca y 12 Pony a Postobón; llegan 20 Coca a $900 y 6
  /// Manzana a $800 (extra): total $22.800.
  Future<int> preparar(WidgetTester tester,
      {bool conPedido = true, String rol = 'admin', bool otroRecibe = false}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final container = await containerConSesion(db, rol: rol);
    addTearDown(container.dispose);
    var ana = container.read(sesionProvider).usuarioActivo!;
    if (otroRecibe) {
      final id = await db.into(db.usuarios).insert(UsuariosCompanion.insert(
          nombre: 'Beto', rol: 'vendedor', pinHash: 'x'));
      ana = await (db.select(db.usuarios)..where((u) => u.id.equals(id)))
          .getSingle();
    }
    final postobon = await ProveedorRepository(db).crear(nombre: 'Postobón');
    final productos = ProductoRepository(db);
    final coca = await productos.guardarProducto(nombre: 'Coca', precio: 1500);
    final pony = await productos.guardarProducto(nombre: 'Pony', precio: 1800);
    final manzana =
        await productos.guardarProducto(nombre: 'Manzana', precio: 1500);
    int? pedido;
    if (conPedido) {
      pedido = await PedidoRepository(db).guardarPedido(
        proveedorId: postobon,
        lineas: [
          LineaPedidoNueva(productoId: coca, cantidad: 24, precioEsperado: 900),
          LineaPedidoNueva(productoId: pony, cantidad: 12, precioEsperado: 1000),
        ],
        por: ana,
      );
    }
    final entrada = await InventarioRepository(db).recibirMercancia(
      proveedorId: postobon,
      lineas: [
        LineaRecibida(productoId: coca, cantidad: 20, precioCompra: 900),
        LineaRecibida(productoId: manzana, cantidad: 6, precioCompra: 800),
      ],
      por: ana,
      pedidoId: pedido,
    );
    await tester.pumpWidget(appDePrueba(container,
        inicio: DetalleEntradaScreen(entradaId: entrada)));
    await tester.pumpAndSettle();
    return entrada;
  }

  testWidgets('compara lo pedido con lo que llegó', (tester) async {
    await preparar(tester);

    final comparacion = find.byKey(const Key('comparacion_pedido'));
    expect(comparacion, findsOneWidget);
    Finder dentro(String texto) =>
        find.descendant(of: comparacion, matching: find.text(texto));
    expect(dentro('Coca · pedido 24 · llegó 20'), findsOneWidget);
    expect(dentro('Faltan 4'), findsOneWidget);
    expect(dentro('Pony · pedido 12 · llegó 0'), findsOneWidget);
    expect(dentro('No llegó'), findsOneWidget);
    expect(dentro('Manzana · no se pidió · llegó 6'), findsOneWidget);
    expect(dentro('Extra'), findsOneWidget);
  });

  testWidgets('muestra el gasto y lo avisa al anular', (tester) async {
    await preparar(tester, conPedido: false);

    expect(find.byKey(const Key('comparacion_pedido')), findsNothing);
    expect(find.text('Gasto Mercancía · Postobón'), findsOneWidget);
    expect(find.text(r'$22.800'), findsWidgets);

    await tester.tap(find.byKey(const Key('boton_anular_entrada')));
    await tester.pumpAndSettle();
    expect(find.textContaining(r'También se anula el gasto de $22.800'),
        findsOneWidget);
    await tester.tap(find.byKey(const Key('confirmar_anular_entrada')));
    await tester.pumpAndSettle();

    expect(find.text('Gasto anulado'), findsOneWidget);
    expect((await db.select(db.gastos).getSingle()).anulado, isTrue);
  });

  testWidgets('con gasto, quien no puede anularla no ve Anular entrada',
      (tester) async {
    await preparar(tester, conPedido: false, rol: 'vendedor', otroRecibe: true);

    expect(find.byKey(const Key('boton_anular_entrada')), findsNothing);
  });
}
