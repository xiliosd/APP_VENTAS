import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/sesion_provider.dart';
import 'package:app_ventas/repositories/configuracion_repository.dart';
import 'package:app_ventas/repositories/inventario_repository.dart';
import 'package:app_ventas/repositories/producto_repository.dart';
import 'package:app_ventas/repositories/proveedor_repository.dart';
import 'package:app_ventas/screens/configuracion/ajustes_screen.dart';
import 'package:app_ventas/screens/configuracion/producto_screen.dart';
import 'package:app_ventas/screens/configuracion/productos_screen.dart';
import 'package:app_ventas/screens/configuracion/proveedores_screen.dart';
import 'package:app_ventas/screens/configuracion/usuarios_screen.dart';
import 'package:app_ventas/screens/inventario/detalle_entrada_screen.dart';
import 'package:app_ventas/screens/inventario/detalle_inventario_screen.dart';
import 'package:app_ventas/screens/inventario/inventario_screen.dart';
import 'package:app_ventas/screens/inventario/pedido_sugerido_screen.dart';
import 'package:app_ventas/screens/inventario/recibir_mercancia_screen.dart';
import 'package:app_ventas/screens/qr/configurar_qr_screen.dart';
import 'package:app_ventas/ui/tema_app.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/montaje.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  /// Datos de ejemplo: tienda, proveedor con teléfono, tres productos
  /// controlados (uno agotado, uno bajo, uno bien) y una entrada.
  Future<({int coca, int entrada, Producto producto})> datos(
      ProviderContainer container) async {
    final ana = container.read(sesionProvider).usuarioActivo!;
    await ConfiguracionRepository(db)
        .guardarNombreTienda('Tienda Doña Rosa del Barrio');
    final prov = await ProveedorRepository(db)
        .crear(nombre: 'Distribuidora Postobón', telefono: '3001234567');
    final productos = ProductoRepository(db);
    Future<int> nuevo(String nombre, int precio) => productos.guardarProducto(
          nombre: nombre,
          precio: precio,
          proveedores: [
            ProveedorDeProducto(
                proveedorId: prov, precioCompra: 900, preferido: true),
          ],
        );
    final coca = await nuevo('Coca-Cola 1,5 litros familiar', 4500);
    final pan = await nuevo('Pan tajado integral', 600);
    final agua = await nuevo('Agua', 1500);
    final inv = InventarioRepository(db);
    await inv.activarControl(coca, cantidad: 2, minimo: 6, por: ana);
    await inv.activarControl(pan, cantidad: 30, minimo: 5, por: ana);
    await inv.activarControl(agua, cantidad: 0, minimo: 3, por: ana);
    final entrada = await inv.recibirMercancia(
      proveedorId: prov,
      lineas: [LineaRecibida(productoId: coca, cantidad: 24, precioCompra: 900)],
      por: ana,
    );
    final producto = await (db.select(db.productos)
          ..where((p) => p.id.equals(coca)))
        .getSingle();
    return (coca: coca, entrada: entrada, producto: producto);
  }

  /// Monta [construir] en 360×800 dp, tema oscuro y letra 2,0×.
  Future<void> montar(WidgetTester tester,
      Widget Function(({int coca, int entrada, Producto producto})) construir,
      {double escala = 2.0}) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = await containerConSesion(db);
    addTearDown(container.dispose);
    final d = await datos(container);
    await tester.pumpWidget(appDePrueba(
      container,
      tema: temaOscuro(),
      inicio: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(escala)),
          child: construir(d),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  final pantallas =
      <String, Widget Function(({int coca, int entrada, Producto producto}))>{
    'inventario (por pedir)': (_) =>
        const Scaffold(body: InventarioScreen()),
    'detalle de inventario': (d) => DetalleInventarioScreen(productoId: d.coca),
    'recibir mercancía': (d) => RecibirMercanciaScreen(lineasIniciales: [
          LineaInicial(producto: d.producto, cantidad: 12, precio: 900),
        ]),
    'pedido sugerido': (_) => const PedidoSugeridoScreen(proveedor: null),
    'detalle de entrada': (d) => DetalleEntradaScreen(entradaId: d.entrada),
    'ajustes': (_) => const Scaffold(body: AjustesScreen()),
    'productos': (_) => const ProductosScreen(),
    'ficha de producto': (d) => ProductoScreen(producto: d.producto),
    'proveedores': (_) => const ProveedoresScreen(),
    'usuarios': (_) => const UsuariosScreen(),
    'configurar QR': (_) => const ConfigurarQrScreen(),
  };

  for (final MapEntry(key: nombre, value: construir) in pantallas.entries) {
    testWidgets('$nombre en oscuro con letra 2,0× no desborda',
        (tester) async {
      await montar(tester, construir);
      expect(tester.takeException(), isNull);
      expect(
          Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
          Brightness.dark);
    });
  }

  testWidgets('inventario en la vista Todos con letra 2,0× no desborda',
      (tester) async {
    await montar(tester, (_) => const Scaffold(body: InventarioScreen()));
    await tester.tap(find.text('Todos'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
