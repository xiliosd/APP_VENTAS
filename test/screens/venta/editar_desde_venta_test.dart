import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/ticket_provider.dart';
import 'package:app_ventas/repositories/producto_repository.dart';
import 'package:app_ventas/screens/configuracion/producto_screen.dart';
import 'package:app_ventas/screens/venta/registrar_venta_screen.dart';
import 'package:app_ventas/servicios/lector_codigo.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/lector_falso.dart';
import '../../support/montaje.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late int productoId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    productoId = await ProductoRepository(db).guardarProducto(
      nombre: 'Gaseosa',
      precio: 4500,
      detalles: const DetallesProducto(codigoBarras: '7702'),
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> abrir(
    WidgetTester tester, {
    String rol = 'admin',
    bool practica = false,
    List<String?> codigos = const [],
  }) async {
    container = await containerConSesion(
      db,
      rol: rol,
      overrides: [lectorCodigoProvider.overrideWithValue(LectorFalso(codigos))],
    );
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      appDePrueba(
        container,
        inicio: RegistrarVentaScreen(practica: practica, conGlobos: false),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> mantener(WidgetTester tester) async {
    await tester.longPress(find.byKey(Key('producto_$productoId')));
    await tester.pumpAndSettle();
  }

  testWidgets('admin: mantener presionado un producto abre Editar producto', (
    tester,
  ) async {
    await abrir(tester);
    await mantener(tester);
    expect(find.byKey(const Key('menu_editar_producto')), findsOneWidget);
    expect(find.text('Editar producto'), findsOneWidget);
    await tester.tap(find.byKey(const Key('menu_editar_producto')));
    await tester.pumpAndSettle();
    expect(find.byType(ProductoScreen), findsOneWidget);
  });

  testWidgets('vendedor: mantener presionado no muestra el menú', (
    tester,
  ) async {
    await abrir(tester, rol: 'vendedor');
    await mantener(tester);
    expect(find.byKey(const Key('menu_editar_producto')), findsNothing);
  });

  testWidgets(
    'práctica del recorrido: mantener presionado no muestra el menú',
    (tester) async {
      await abrir(tester, practica: true);
      await mantener(tester);
      expect(find.byKey(const Key('menu_editar_producto')), findsNothing);
    },
  );

  testWidgets('editar el precio no cambia la línea ya agregada al ticket', (
    tester,
  ) async {
    await abrir(tester);
    await tester.tap(find.byKey(Key('producto_$productoId')));
    await tester.pump();
    expect(container.read(ticketProvider).total, 4500);
    await mantener(tester);
    await tester.tap(find.byKey(const Key('menu_editar_producto')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('campo_precio_producto')),
      '5.000',
    );
    await tester.ensureVisible(find.byKey(const Key('boton_guardar_producto')));
    await tester.tap(find.byKey(const Key('boton_guardar_producto')));
    await tester.pumpAndSettle();
    expect(find.byType(ProductoScreen), findsNothing);
    final producto = await ProductoRepository(db).productoPorCodigo('7702');
    expect(producto!.precio, 5000);
    expect(container.read(ticketProvider).total, 4500);
  });

  testWidgets('admin: al escanear un producto existente el aviso trae Editar', (
    tester,
  ) async {
    await abrir(tester, codigos: ['7702']);
    await tester.tap(find.byKey(const Key('boton_escanear_venta')));
    await tester.pumpAndSettle();
    expect(find.text('Gaseosa agregado'), findsOneWidget);
    expect(find.text('Editar'), findsOneWidget);
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    expect(find.byType(ProductoScreen), findsOneWidget);
  });

  testWidgets('vendedor: al escanear el aviso no trae Editar', (tester) async {
    await abrir(tester, rol: 'vendedor', codigos: ['7702']);
    await tester.tap(find.byKey(const Key('boton_escanear_venta')));
    await tester.pumpAndSettle();
    expect(find.text('Gaseosa agregado'), findsOneWidget);
    expect(find.text('Editar'), findsNothing);
  });

  Future<void> enviarCodigoEnBuscador(WidgetTester tester) async {
    for (var i = 0; i < 7; i++) {
      await ProductoRepository(db).guardarProducto(
        nombre: 'Relleno $i',
        precio: 1000,
      );
    }
    await tester.pumpAndSettle();
    final campo = find.byType(TextField).first;
    await tester.enterText(campo, '7702');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
  }

  testWidgets('admin: Enter en el buscador con un código trae Editar', (
    tester,
  ) async {
    await abrir(tester);
    await enviarCodigoEnBuscador(tester);
    expect(find.text('Gaseosa agregado'), findsOneWidget);
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    expect(find.byType(ProductoScreen), findsOneWidget);
  });

  testWidgets('vendedor: Enter en el buscador no trae Editar', (tester) async {
    await abrir(tester, rol: 'vendedor');
    await enviarCodigoEnBuscador(tester);
    expect(find.text('Gaseosa agregado'), findsOneWidget);
    expect(find.text('Editar'), findsNothing);
  });
}
