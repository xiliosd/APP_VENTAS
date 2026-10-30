import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/ticket_provider.dart';
import 'package:app_ventas/repositories/configuracion_repository.dart';
import 'package:app_ventas/repositories/producto_repository.dart';
import 'package:app_ventas/servicios/lector_codigo.dart';
import 'package:app_ventas/servicios/open_food_facts.dart';
import 'package:app_ventas/screens/venta/registrar_venta_screen.dart';
import 'package:app_ventas/util/nombre_cliente.dart';
import 'package:app_ventas/ui/boton_principal.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/imagen_prueba.dart';
import '../../support/lector_falso.dart';
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
    await tester.pumpWidget(appDePrueba(container, navegador: navegador));
    navegador.currentState!.push(
      MaterialPageRoute(builder: (_) => const RegistrarVentaScreen()),
    );
    await tester.pumpAndSettle();
  }

  BotonPrincipal botonCobrar(WidgetTester tester) =>
      tester.widget<BotonPrincipal>(find.byKey(const Key('boton_cobrar')));

  BotonPrincipal botonFiar(WidgetTester tester) =>
      tester.widget<BotonPrincipal>(find.byKey(const Key('boton_fiar')));

  /// Toca Cobrar y elige la forma de pago en la hoja "¿Cómo paga?".
  Future<void> cobrarCon(WidgetTester tester, String clave) async {
    await tester.tap(find.byKey(const Key('boton_cobrar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key(clave)));
    await tester.pumpAndSettle();
  }

  /// Toca Cobrar y escoge Fiado (el selector de cliente queda en la hoja).
  Future<void> abrirFiado(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('boton_cobrar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pago_fiado')));
    await tester.pumpAndSettle();
  }

  testWidgets('tocar montos suma al ticket y solo Cobrar registra la venta', (
    tester,
  ) async {
    await abrirVenta(tester);

    await tester.tap(find.byKey(const Key('monto_rapido_5000')));
    await tester.tap(find.byKey(const Key('monto_rapido_5000')));
    await tester.tap(find.byKey(const Key('monto_rapido_1000')));
    await tester.pump();

    expect(await db.select(db.ventas).get(), isEmpty);
    expect(find.text(r'Cobrar $11.000'), findsOneWidget);
    expect(find.text('3 artículos'), findsOneWidget);

    await cobrarCon(tester, 'pago_efectivo');

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
    await db
        .into(db.ventas)
        .insert(
          VentasCompanion.insert(
            monto: 999,
            fecha: DateTime.now(),
            usuarioId: 1,
          ),
        );
    await abrirVenta(tester);

    await tester.tap(find.byKey(const Key('monto_rapido_2000')));
    await tester.pump();
    await cobrarCon(tester, 'pago_efectivo');
    expect(await db.select(db.ventas).get(), hasLength(2));

    await tester.tap(find.text('Deshacer'));
    await tester.pumpAndSettle();

    final ventas = await db.select(db.ventas).get();
    expect(ventas.single.monto, 999);
  });

  /// Escribe [texto], toca "Nuevo" y llena el formulario de cliente.
  Future<void> crearClienteNuevo(
    WidgetTester tester,
    String texto,
    String nombre,
    String apellido,
  ) async {
    await tester.enterText(find.byKey(const Key('campo_cliente')), texto);
    await tester.pump();
    await tester.tap(find.byKey(const Key('boton_cliente_nuevo')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('campo_nombre_cliente')),
      nombre,
    );
    await tester.enterText(
      find.byKey(const Key('campo_apellido_cliente')),
      apellido,
    );
    await tester.tap(find.byKey(const Key('boton_continuar_cliente')));
    await tester.pumpAndSettle();
  }

  testWidgets('fiado sin cliente no deja cobrar; con cliente nuevo sí', (
    tester,
  ) async {
    await abrirVenta(tester);

    await tester.tap(find.byKey(const Key('monto_rapido_2000')));
    await tester.pump();
    await abrirFiado(tester);
    expect(botonFiar(tester).onPressed, isNull);

    await crearClienteNuevo(tester, 'Pedro', 'Pedro', 'Gómez');
    expect(find.text(r'Fiar $2.000 a Pedro Gómez'), findsOneWidget);

    await tester.tap(find.byKey(const Key('boton_fiar')));
    await tester.pumpAndSettle();

    final ventas = await db.select(db.ventas).get();
    final clientes = await db.select(db.clientes).get();
    expect(ventas.single.esFiado, isTrue);
    expect(clientes.single.nombreCompleto, 'Pedro Gómez');
    expect(ventas.single.clienteId, clientes.single.id);
  });

  testWidgets('elegir un cliente existente no crea un duplicado', (
    tester,
  ) async {
    final pedro = await db
        .into(db.clientes)
        .insert(ClientesCompanion.insert(nombre: 'Don Pedro'));
    await abrirVenta(tester);

    await tester.tap(find.byKey(const Key('monto_rapido_1000')));
    await tester.pump();
    await abrirFiado(tester);
    await tester.enterText(find.byKey(const Key('campo_cliente')), 'don pedro');
    await tester.pump();
    await tester.tap(find.byKey(Key('cliente_sugerido_$pedro')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('boton_fiar')));
    await tester.pumpAndSettle();

    expect(await db.select(db.clientes).get(), hasLength(1));
    expect((await db.select(db.ventas).get()).single.clienteId, pedro);
  });

  testWidgets('un ticket con un solo producto guarda el producto', (
    tester,
  ) async {
    final arepa = await db
        .into(db.productos)
        .insert(ProductosCompanion.insert(nombre: 'Arepa', precio: 3500));
    await abrirVenta(tester);

    await tester.tap(find.byKey(Key('producto_$arepa')));
    await tester.tap(find.byKey(Key('producto_$arepa')));
    await tester.pump();
    await cobrarCon(tester, 'pago_efectivo');

    final venta = (await db.select(db.ventas).get()).single;
    expect(venta.monto, 7000);
    expect(venta.productoId, arepa);
  });

  testWidgets('Ver ticket permite restar y quitar líneas', (tester) async {
    final arepa = await db
        .into(db.productos)
        .insert(ProductosCompanion.insert(nombre: 'Arepa', precio: 3500));
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
      MaterialPageRoute(builder: (_) => const RegistrarVentaScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Agrega algo para cobrar'), findsOneWidget);
    expect(await db.select(db.ventas).get(), isEmpty);
  });

  testWidgets('escribir el nombre sin elegir cliente no deja fiar', (
    tester,
  ) async {
    await abrirVenta(tester);

    await tester.tap(find.byKey(const Key('monto_rapido_1000')));
    await tester.pump();
    await abrirFiado(tester);
    await tester.enterText(
      find.byKey(const Key('campo_cliente')),
      'don pedro ',
    );
    await tester.pump();

    expect(botonFiar(tester).onPressed, isNull);
  });

  testWidgets(
    'los productos no se desbordan con letra grande en celular pequeño',
    (tester) async {
      await db
          .into(db.productos)
          .insert(
            ProductosCompanion.insert(
              nombre: 'Arroz Diana libra',
              precio: 3800,
            ),
          );
      await db
          .into(db.productos)
          .insert(ProductosCompanion.insert(nombre: 'Pan', precio: 123456789));
      await tester.pumpWidget(appDePrueba(container, navegador: navegador));
      tester.view.physicalSize = const Size(720, 1560);
      tester.view.devicePixelRatio = 2;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      navegador.currentState!.push(
        MaterialPageRoute(builder: (_) => const RegistrarVentaScreen()),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('en un celular de 360 dp "Ver ticket" se lee completo', (
    tester,
  ) async {
    await abrirVenta(tester);
    tester.view.physicalSize = const Size(720, 1560);
    tester.view.devicePixelRatio = 2;
    await tester.pumpAndSettle();

    final texto = tester.renderObject<RenderParagraph>(find.text('Ver ticket'));
    expect(texto.didExceedMaxLines, isFalse);
  });

  testWidgets('Transferencia: el QR se muestra y Recibido guarda la venta', (
    tester,
  ) async {
    await ConfiguracionRepository(db).guardarImagenQr(pngDePrueba);
    await abrirVenta(tester);
    await tester.tap(find.byKey(const Key('monto_rapido_5000')));
    await tester.pump();
    await cobrarCon(tester, 'pago_transferencia');
    expect(find.byKey(const Key('imagen_qr')), findsOneWidget);
    expect(await db.select(db.ventas).get(), isEmpty);

    await tester.tap(find.byKey(const Key('boton_qr_recibido')));
    await tester.pumpAndSettle();

    final venta = (await db.select(db.ventas).get()).single;
    expect(venta.monto, 5000);
    expect(venta.medioPago, MedioPago.transferencia);
    expect(find.text(r'Venta registrada · $5.000'), findsOneWidget);
  });

  testWidgets('Cancelar en el QR no guarda y deja el ticket igual', (
    tester,
  ) async {
    await abrirVenta(tester);
    await tester.tap(find.byKey(const Key('monto_rapido_5000')));
    await tester.pump();
    await cobrarCon(tester, 'pago_transferencia');

    await tester.tap(find.byKey(const Key('boton_qr_cancelar')));
    await tester.pumpAndSettle();

    expect(await db.select(db.ventas).get(), isEmpty);
    expect(find.text(r'Cobrar $5.000'), findsOneWidget);
  });

  testWidgets('volver atrás desde el QR no guarda y deja el ticket igual', (
    tester,
  ) async {
    await abrirVenta(tester);
    await tester.tap(find.byKey(const Key('monto_rapido_5000')));
    await tester.pump();
    await cobrarCon(tester, 'pago_transferencia');

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(await db.select(db.ventas).get(), isEmpty);
    expect(find.text(r'Cobrar $5.000'), findsOneWidget);
    expect(find.byKey(const Key('boton_cobrar')), findsOneWidget);
  });

  testWidgets('Nueva venta ya no muestra selectores de pago arriba', (
    tester,
  ) async {
    await abrirVenta(tester);
    expect(find.byKey(const Key('selector_tipo_venta')), findsNothing);
    expect(find.byKey(const Key('selector_medio_pago')), findsNothing);
  });

  testWidgets('Efectivo registra como siempre, en efectivo', (tester) async {
    await abrirVenta(tester);
    await tester.tap(find.byKey(const Key('monto_rapido_1000')));
    await tester.pump();
    await cobrarCon(tester, 'pago_efectivo');

    expect(
      (await db.select(db.ventas).get()).single.medioPago,
      MedioPago.efectivo,
    );
  });

  testWidgets('cobrar un ticket guarda una línea por producto o monto', (
    tester,
  ) async {
    final arepa = await db
        .into(db.productos)
        .insert(ProductosCompanion.insert(nombre: 'Arepa', precio: 3500));
    await abrirVenta(tester);

    await tester.tap(find.byKey(Key('producto_$arepa')));
    await tester.tap(find.byKey(const Key('monto_rapido_5000')));
    await tester.tap(find.byKey(const Key('monto_rapido_5000')));
    await tester.pump();
    await cobrarCon(tester, 'pago_efectivo');

    final venta = (await db.select(db.ventas).get()).single;
    expect(venta.monto, 13500);
    final lineas = await db.select(db.lineasVenta).get();
    expect(lineas, hasLength(2));
    final deArepa = lineas.singleWhere((l) => l.productoId == arepa);
    expect(deArepa.cantidad, 1);
    expect(deArepa.descripcion, 'Arepa');
    final suelto = lineas.singleWhere((l) => l.productoId == null);
    expect(suelto.cantidad, 2);
    expect(suelto.precioUnitario, 5000);
    expect(suelto.descripcion, r'$5.000');
  });

  testWidgets('Deshacer no deja líneas huérfanas', (tester) async {
    final arepa = await db
        .into(db.productos)
        .insert(ProductosCompanion.insert(nombre: 'Arepa', precio: 3500));
    await abrirVenta(tester);

    await tester.tap(find.byKey(Key('producto_$arepa')));
    await tester.pump();
    await cobrarCon(tester, 'pago_efectivo');
    expect(await db.select(db.lineasVenta).get(), hasLength(1));

    await tester.tap(find.text('Deshacer'));
    await tester.pumpAndSettle();

    expect(await db.select(db.ventas).get(), isEmpty);
    expect(await db.select(db.lineasVenta).get(), isEmpty);
  });

  Future<void> crearProductos(List<String> nombres) async {
    for (final n in nombres) {
      await db
          .into(db.productos)
          .insert(ProductosCompanion.insert(nombre: n, precio: 1000));
    }
  }

  const siete = ['Café', 'Pan', 'Leche', 'Arroz', 'Huevos', 'Azúcar', 'Sal'];

  testWidgets('el buscador filtra sin importar tildes y mayúsculas', (
    tester,
  ) async {
    await crearProductos(siete);
    await abrirVenta(tester);
    await tester.enterText(find.byKey(const Key('buscador_productos')), 'CAFE');
    await tester.pump();
    expect(find.text('Café'), findsOneWidget);
    expect(find.text('Pan'), findsNothing);
    expect(find.byKey(const Key('boton_otro_monto')), findsOneWidget);
  });

  testWidgets('sin coincidencias muestra Sin resultados', (tester) async {
    await crearProductos(siete);
    await abrirVenta(tester);
    await tester.enterText(find.byKey(const Key('buscador_productos')), 'zzz');
    await tester.pump();
    expect(find.byKey(const Key('texto_sin_resultados')), findsOneWidget);
    expect(find.byKey(const Key('boton_otro_monto')), findsOneWidget);
  });

  testWidgets('vaciar el ticket limpia la búsqueda', (tester) async {
    await crearProductos(siete);
    await abrirVenta(tester);
    await tester.tap(find.text('Pan'));
    await tester.enterText(find.byKey(const Key('buscador_productos')), 'caf');
    await tester.pump();
    expect(find.text('Pan'), findsNothing);
    await tester.tap(find.byKey(const Key('boton_vaciar')));
    await tester.pump();
    expect(find.text('Pan'), findsOneWidget);
  });

  testWidgets('con muchos productos el buscador sigue a la vista al bajar', (
    tester,
  ) async {
    await crearProductos([for (var i = 0; i < 40; i++) 'Producto $i']);
    await abrirVenta(tester);
    await tester.drag(find.text('Producto 0'), const Offset(0, -1500));
    await tester.pumpAndSettle();
    final buscador = find.byKey(const Key('buscador_productos'));
    expect(buscador, findsOneWidget);
    expect(tester.getRect(buscador).top, greaterThanOrEqualTo(0));
    // La lista bajó por debajo del buscador, que se quedó arriba.
    expect(
      tester.getRect(find.text('Producto 0')).bottom,
      lessThan(tester.getRect(buscador).bottom),
    );
    await tester.enterText(buscador, 'producto 3');
    await tester.pump();
    expect(find.text('Producto 3'), findsOneWidget);
  });

  testWidgets('la ✕ del buscador borra la búsqueda', (tester) async {
    await crearProductos(siete);
    await abrirVenta(tester);
    expect(find.byKey(const Key('borrar_busqueda')), findsNothing);
    await tester.enterText(find.byKey(const Key('buscador_productos')), 'caf');
    await tester.pump();
    expect(find.text('Pan'), findsNothing);
    await tester.tap(find.byKey(const Key('borrar_busqueda')));
    await tester.pump();
    expect(find.text('Pan'), findsOneWidget);
    expect(find.byKey(const Key('borrar_busqueda')), findsNothing);
  });

  testWidgets('el − del mosaico resta y en 1 muestra la caneca y lo quita', (
    tester,
  ) async {
    await crearProductos(['Pan']);
    await abrirVenta(tester);
    final pan = find.byKey(const Key('producto_1'));
    Finder restar() => find.descendant(
      of: pan,
      matching: find.byKey(const Key('restar_mosaico')),
    );
    expect(restar(), findsNothing);

    await tester.tap(find.text('Pan'));
    await tester.tap(find.text('Pan'));
    await tester.pumpAndSettle();
    expect(find.descendant(of: pan, matching: find.text('2')), findsOneWidget);
    expect(
      find.descendant(
        of: restar(),
        matching: find.byIcon(Icons.remove_rounded),
      ),
      findsOneWidget,
    );

    await tester.tap(restar());
    await tester.pumpAndSettle();
    expect(find.descendant(of: pan, matching: find.text('1')), findsOneWidget);
    expect(
      find.descendant(
        of: restar(),
        matching: find.byIcon(Icons.delete_outline_rounded),
      ),
      findsOneWidget,
    );

    await tester.tap(restar());
    await tester.pumpAndSettle();
    expect(restar(), findsNothing);
    expect(container.read(ticketProvider).estaVacio, isTrue);
  });

  testWidgets('con 6 productos o menos no hay buscador', (tester) async {
    await crearProductos(['Pan', 'Leche', 'Arroz']);
    await abrirVenta(tester);
    expect(find.byKey(const Key('buscador_productos')), findsNothing);
  });

  testWidgets('la hoja ofrece Efectivo, Transferencia y Fiado con el total', (
    tester,
  ) async {
    await abrirVenta(tester);
    await tester.tap(find.byKey(const Key('monto_rapido_5000')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('boton_cobrar')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('hoja_como_paga')), findsOneWidget);
    // Título de la hoja + botón de la barra.
    expect(find.text(r'Cobrar $5.000'), findsNWidgets(2));
    for (final k in ['pago_efectivo', 'pago_transferencia', 'pago_fiado']) {
      expect(find.byKey(Key(k)), findsOneWidget);
    }
  });

  testWidgets('cerrar la hoja tras escoger Fiado deja el ticket de contado', (
    tester,
  ) async {
    await abrirVenta(tester);
    await tester.tap(find.byKey(const Key('monto_rapido_5000')));
    await tester.pump();
    await abrirFiado(tester);
    await tester.enterText(find.byKey(const Key('campo_cliente')), 'Don Pedro');
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10)); // fuera de la hoja
    await tester.pumpAndSettle();
    expect(await db.select(db.ventas).get(), isEmpty);

    await cobrarCon(tester, 'pago_efectivo');
    final venta = (await db.select(db.ventas).get()).single;
    expect(venta.esFiado, isFalse);
    expect(venta.clienteId, isNull);
  });

  testWidgets('doble toque en Efectivo registra una sola venta', (
    tester,
  ) async {
    await abrirVenta(tester);
    await tester.tap(find.byKey(const Key('monto_rapido_5000')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('boton_cobrar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pago_efectivo')));
    await tester.tap(
      find.byKey(const Key('pago_efectivo')),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    expect(await db.select(db.ventas).get(), hasLength(1));
  });

  testWidgets('al escoger Fiado la hoja deja solo el cliente y Fiar', (
    tester,
  ) async {
    await abrirVenta(tester);
    await tester.tap(find.byKey(const Key('monto_rapido_5000')));
    await tester.pump();
    await abrirFiado(tester);
    expect(find.byKey(const Key('pago_efectivo')), findsNothing);
    expect(find.byKey(const Key('pago_transferencia')), findsNothing);
    expect(find.byKey(const Key('campo_cliente')), findsOneWidget);
    expect(find.byKey(const Key('boton_fiar')), findsOneWidget);
  });

  Future<void> abrirVentaCon(
    WidgetTester tester, {
    required List<String?> codigos,
    DatosProducto? datos,
    String rol = 'admin',
  }) async {
    container.dispose();
    container = await containerConSesion(
      db,
      rol: rol,
      overrides: [
        lectorCodigoProvider.overrideWithValue(LectorFalso(codigos)),
        consultaProductoProvider.overrideWithValue(_Consulta(datos)),
      ],
    );
    await abrirVenta(tester);
  }

  Future<void> escanear(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('boton_escanear_venta')));
    await tester.pumpAndSettle();
  }

  testWidgets('escanear un producto conocido lo suma al ticket', (
    tester,
  ) async {
    final id = await ProductoRepository(db).guardarProducto(
      nombre: 'Gaseosa',
      precio: 4500,
      detalles: const DetallesProducto(codigoBarras: '7702'),
    );
    await abrirVentaCon(tester, codigos: ['7702']);
    await escanear(tester);
    expect(container.read(ticketProvider).cantidadDe('p$id'), 1);
    expect(find.text('Gaseosa agregado'), findsOneWidget);
  });

  testWidgets('el mismo código dos veces seguidas solo suma uno', (
    tester,
  ) async {
    final id = await ProductoRepository(db).guardarProducto(
      nombre: 'Gaseosa',
      precio: 4500,
      detalles: const DetallesProducto(codigoBarras: '7702'),
    );
    await abrirVentaCon(tester, codigos: ['7702', '7702']);
    await escanear(tester);
    await escanear(tester);
    expect(container.read(ticketProvider).cantidadDe('p$id'), 1);
  });

  testWidgets('un código desconocido abre la hoja, pide precio y lo agrega', (
    tester,
  ) async {
    await abrirVentaCon(
      tester,
      codigos: ['7702'],
      datos: const DatosProducto(
        nombre: 'Gaseosa Colombiana',
        marca: 'Postobón',
        tipo: 'bebidas',
      ),
    );
    await escanear(tester);
    expect(find.byKey(const Key('hoja_producto_rapido')), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('campo_nombre_rapido')))
          .controller!
          .text,
      'Gaseosa Colombiana',
    );
    await tester.tap(find.byKey(const Key('boton_guardar_producto_rapido')));
    await tester.pumpAndSettle();
    expect(find.text('Escribe un precio válido'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('campo_precio_rapido')),
      '4.500',
    );
    await tester.tap(find.byKey(const Key('boton_guardar_producto_rapido')));
    await tester.pumpAndSettle();

    final p = await db.select(db.productos).getSingle();
    expect(
      (p.nombre, p.precio, p.codigoBarras, p.marca, p.tipo),
      ('Gaseosa Colombiana', 4500, '7702', 'Postobón', 'bebidas'),
    );
    expect(container.read(ticketProvider).cantidadDe('p${p.id}'), 1);
  });

  testWidgets('un vendedor también puede crear el producto escaneado', (
    tester,
  ) async {
    await abrirVentaCon(tester, codigos: ['555'], rol: 'vendedor');
    await escanear(tester);
    await tester.enterText(
      find.byKey(const Key('campo_nombre_rapido')),
      'Arepa',
    );
    await tester.enterText(
      find.byKey(const Key('campo_precio_rapido')),
      '2.000',
    );
    await tester.tap(find.byKey(const Key('boton_guardar_producto_rapido')));
    await tester.pumpAndSettle();
    expect((await db.select(db.productos).getSingle()).codigoBarras, '555');
  });

  testWidgets('un código de un producto inactivo avisa y no crea otro', (
    tester,
  ) async {
    final repo = ProductoRepository(db);
    final id = await repo.guardarProducto(
      nombre: 'Pan viejo',
      precio: 500,
      detalles: const DetallesProducto(codigoBarras: '123'),
    );
    await repo.desactivarProducto(id);
    await abrirVentaCon(tester, codigos: ['123']);
    await escanear(tester);
    expect(find.byKey(const Key('hoja_producto_rapido')), findsNothing);
    expect(
      find.text(
        'Ese código es de Pan viejo (inactivo). Reactívalo en '
        'Productos',
      ),
      findsOneWidget,
    );
    expect((await db.select(db.productos).get()).length, 1);
  });

  testWidgets('código exacto + Enter en el buscador agrega el producto', (
    tester,
  ) async {
    await crearProductos(siete);
    final id = await ProductoRepository(db).guardarProducto(
      nombre: 'Gaseosa',
      precio: 4500,
      detalles: const DetallesProducto(codigoBarras: '7702'),
    );
    await abrirVenta(tester);
    await tester.enterText(
      find.byKey(const Key('buscador_productos')),
      '7702\n',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(container.read(ticketProvider).cantidadDe('p$id'), 1);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('buscador_productos')))
          .controller!
          .text,
      '',
    );
  });

  testWidgets('los chips de tipo filtran y el mosaico muestra el tamaño', (
    tester,
  ) async {
    await crearProductos(siete);
    final repo = ProductoRepository(db);
    final coca = await repo.guardarProducto(
      nombre: 'Gaseosa',
      precio: 4500,
      detalles: const DetallesProducto(tipo: 'bebidas', tamano: '1,5 L'),
    );
    await repo.guardarProducto(
      nombre: 'Yogur',
      precio: 2500,
      detalles: const DetallesProducto(tipo: 'lacteos'),
    );
    await abrirVenta(tester);
    expect(find.text(r'1,5 L · $4.500'), findsOneWidget);
    await tester.tap(find.byKey(const Key('filtro_tipo_venta_bebidas')));
    await tester.pumpAndSettle();
    expect(find.byKey(Key('producto_$coca')), findsOneWidget);
    expect(find.text('Yogur'), findsNothing);
    expect(find.text('Pan'), findsNothing);
  });

  testWidgets('en la venta de práctica hay botón de escanear', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      appDePrueba(
        container,
        inicio: const RegistrarVentaScreen(practica: true, conGlobos: false),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('boton_escanear_venta')), findsOneWidget);
  });
}

class _Consulta implements ConsultaProducto {
  _Consulta(this.datos);
  final DatosProducto? datos;
  @override
  Future<DatosProducto?> buscar(String codigo) async => datos;
}
