import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/repository_providers.dart';
import 'package:app_ventas/providers/sesion_provider.dart';
import 'package:app_ventas/repositories/pedido_repository.dart';
import 'package:app_ventas/repositories/producto_repository.dart';
import 'package:app_ventas/repositories/proveedor_repository.dart';
import 'package:app_ventas/screens/inventario/recibir_mercancia_screen.dart';
import 'package:app_ventas/ui/boton_principal.dart';
import 'package:app_ventas/respaldo/respaldo_provider.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/montaje.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  bool habilitado(WidgetTester tester, String clave) =>
      tester.widget<BotonPrincipal>(find.byKey(Key(clave))).onPressed != null;

  String texto(WidgetTester tester, String clave) =>
      tester.widget<Text>(find.byKey(Key(clave))).data!;

  late ProviderContainer container;
  late SharedPreferences preferencias;
  int? devuelto;

  /// Pedido de Postobón: 24 Coca a $900, 12 Agua a $700 y 12 Pony a $1.000.
  Future<({int pedido, int postobon, int coca, int agua, int pony})> preparar(
    WidgetTester tester, {
    bool abrirConPedido = true,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    preferencias = await SharedPreferences.getInstance();
    container = await containerConSesion(db, preferencias: preferencias);
    addTearDown(container.dispose);
    final ana = container.read(sesionProvider).usuarioActivo!;
    final postobon = await ProveedorRepository(db).crear(nombre: 'Postobón');
    final productos = ProductoRepository(db);
    final coca = await productos.guardarProducto(nombre: 'Coca', precio: 1500);
    final agua = await productos.guardarProducto(nombre: 'Agua', precio: 1200);
    final pony = await productos.guardarProducto(nombre: 'Pony', precio: 1800);
    final pedido = await PedidoRepository(db).guardarPedido(
      proveedorId: postobon,
      lineas: [
        LineaPedidoNueva(productoId: coca, cantidad: 24, precioEsperado: 900),
        LineaPedidoNueva(productoId: agua, cantidad: 12, precioEsperado: 700),
        LineaPedidoNueva(productoId: pony, cantidad: 12, precioEsperado: 1000),
      ],
      por: ana,
    );
    devuelto = null;
    await tester.pumpWidget(
      appDePrueba(
        container,
        inicio: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                devuelto = await Navigator.of(context).push<int>(
                  MaterialPageRoute(
                    builder: (_) => RecibirMercanciaScreen(
                      pedidoId: abrirConPedido ? pedido : null,
                    ),
                  ),
                );
              },
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    return (
      pedido: pedido,
      postobon: postobon,
      coca: coca,
      agua: agua,
      pony: pony,
    );
  }

  /// La lista se arma al desplazarse: baja (o sube con [delta] negativo)
  /// hasta que [finder] se vea, y lo deja al centro.
  Future<void> ver(
    WidgetTester tester,
    Finder finder, {
    double delta = 200,
  }) async {
    await tester.scrollUntilVisible(
      finder,
      delta,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    // Al centro: pegado abajo quedaría detrás de la barra fija de Guardar.
    await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
    await tester.pumpAndSettle();
  }

  Future<void> cantidad(WidgetTester tester, int producto, int n) async {
    await ver(tester, find.byKey(Key('cantidad_recibir_$producto')));
    await tester.tap(find.byKey(Key('cantidad_recibir_$producto')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('campo_cantidad')), '$n');
    await tester.tap(find.byKey(const Key('aceptar_cantidad')));
    await tester.pumpAndSettle();
  }

  Future<void> guardar(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('boton_guardar_recibir')));
    await tester.pumpAndSettle();
  }

  testWidgets('arranca con lo pedido: todo completo y el gasto anunciado', (
    tester,
  ) async {
    final p = await preparar(tester);

    expect(texto(tester, 'cantidad_recibir_${p.coca}'), '24');
    expect(find.text('pedido 24 · llegó 24'), findsOneWidget);
    expect(find.text('Completo'), findsNWidgets(3));
    expect(find.text(r'Total $42.000'), findsOneWidget);
    await ver(tester, find.byKey(const Key('interruptor_caja')));
    final interruptor = tester.widget<SwitchListTile>(
      find.byKey(const Key('interruptor_caja')),
    );
    expect(interruptor.value, isTrue);
    expect(find.text('Lo pagué de la caja (efectivo)'), findsOneWidget);
    expect(
      find.text(r'Se registra gasto Mercancía · Postobón por $42.000'),
      findsOneWidget,
    );
  });

  testWidgets(
    'muestra faltantes, lo que no llegó, extras y precios cambiados',
    (tester) async {
      final p = await preparar(tester);
      final manzana = await ProductoRepository(db)
          .guardarProducto(nombre: 'Manzana', precio: 1500);

      await cantidad(tester, p.agua, 6);
      await cantidad(tester, p.pony, 0);
      await tester.enterText(
        find.byKey(Key('precio_recibir_${p.coca}')),
        '1000',
      );
      await tester.pump();
      await ver(
        tester,
        find.byKey(const Key('boton_agregar_producto_recibir')),
      );
      await tester.tap(find.byKey(const Key('boton_agregar_producto_recibir')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('opcion_producto_recibir_$manzana')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(Key('precio_recibir_$manzana')), '800');
      await tester.pump();

      await ver(
        tester,
        find.byKey(const Key('resumen_recepcion')),
        delta: -200,
      );
      expect(find.text('pedido 12 · llegó 6'), findsOneWidget);
      expect(find.text('Faltan 6'), findsOneWidget);
      expect(find.text('No llegó'), findsOneWidget);
      expect(find.text(r'$900 → $1.000'), findsOneWidget);
      final resumen = find.byKey(const Key('resumen_recepcion'));
      expect(
        find.descendant(
          of: resumen,
          matching: find.text(r'Pedido $42.000 · Llegó $29.000'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: resumen,
          matching: find.text(
            '1 completo · 1 incompleto · 1 no llegó · 1 extra · 1 precio cambiado',
          ),
        ),
        findsOneWidget,
      );
      // Lo pedido baja hasta 0 sin quitarse; lo extra se quita.
      expect(find.byKey(Key('quitar_recibir_${p.pony}')), findsNothing);
      await ver(tester, find.byKey(Key('quitar_recibir_$manzana')));
      expect(find.text('Extra'), findsOneWidget);
    },
  );

  testWidgets('guarda solo lo que llegó, cierra el pedido y crea el gasto', (
    tester,
  ) async {
    final p = await preparar(tester);
    await cantidad(tester, p.pony, 0);

    await guardar(tester);
    await tester.tap(find.byKey(const Key('entendido_aviso_gasto')));
    await tester.pumpAndSettle();

    expect(devuelto, 30000);
    final lineas = await db.select(db.lineasEntrada).get();
    expect(
      [for (final l in lineas) (l.productoId, l.cantidad)],
      [(p.coca, 24), (p.agua, 12)],
    );
    final pedido = await db.select(db.pedidos).getSingle();
    expect(pedido.estado, EstadoPedido.recibido);
    final gasto = await db.select(db.gastos).getSingle();
    expect((gasto.monto, gasto.descripcion), (30000, 'Mercancía · Postobón'));
  });

  testWidgets(
    'el aviso de no registrar la mercancía a mano sale una sola vez',
    (tester) async {
      final p = await preparar(tester, abrirConPedido: false);

      /// Recibe una Coca sin pedido; [precio] solo hace falta la primera vez.
      Future<void> recibirCoca({String? precio}) async {
        await tester.tap(
          find.byKey(Key('opcion_proveedor_recibir_${p.postobon}')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('otra_mercancia')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('boton_agregar_producto_recibir')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(Key('opcion_producto_recibir_${p.coca}')));
        await tester.pumpAndSettle();
        if (precio != null) {
          await tester.enterText(
            find.byKey(Key('precio_recibir_${p.coca}')),
            precio,
          );
          await tester.pump();
        }
        await guardar(tester);
      }

      await recibirCoca(precio: '900');
      expect(
        find.text(
          'Ya no registres la mercancía como gasto a mano; '
          'se anota sola',
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('entendido_aviso_gasto')));
      await tester.pumpAndSettle();
      expect(preferencias.getBool('aviso_mercancia_gasto'), isTrue);

      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      await recibirCoca();

      expect(find.byKey(const Key('entendido_aviso_gasto')), findsNothing);
      expect(find.byType(RecibirMercanciaScreen), findsNothing);
      expect(await db.select(db.gastos).get(), hasLength(2));
    },
  );

  testWidgets('con el interruptor apagado no hay gasto ni aviso', (
    tester,
  ) async {
    await preparar(tester);
    await ver(tester, find.byKey(const Key('interruptor_caja')));
    await tester.tap(find.byKey(const Key('interruptor_caja')));
    await tester.pump();

    await guardar(tester);

    expect(find.byKey(const Key('entendido_aviso_gasto')), findsNothing);
    expect(devuelto, 42000);
    expect(await db.select(db.gastos).get(), isEmpty);
  });

  testWidgets('si nada llegó no se guarda y se ofrece anular el pedido', (
    tester,
  ) async {
    final p = await preparar(tester);
    await cantidad(tester, p.coca, 0);
    await cantidad(tester, p.agua, 0);
    await cantidad(tester, p.pony, 0);

    expect(habilitado(tester, 'boton_guardar_recibir'), isFalse);
    await ver(tester, find.byKey(const Key('boton_anular_pedido_recibir')));
    await tester.tap(find.byKey(const Key('boton_anular_pedido_recibir')));
    await tester.pumpAndSettle();
    // Anular no se deshace: pide confirmación.
    expect(find.byType(RecibirMercanciaScreen), findsOneWidget);
    expect(
      (await db.select(db.pedidos).getSingle()).estado,
      EstadoPedido.porLlegar,
    );
    await tester.tap(find.byKey(const Key('confirmar_anular_pedido')));
    await tester.pumpAndSettle();

    expect(find.byType(RecibirMercanciaScreen), findsNothing);
    expect(
      (await db.select(db.pedidos).getSingle()).estado,
      EstadoPedido.anulado,
    );
  });

  testWidgets('una línea sin precio no deja guardar hasta escribirlo', (
    tester,
  ) async {
    final p = await preparar(tester);
    await ver(tester, find.byKey(Key('precio_recibir_${p.agua}')));
    await tester.enterText(find.byKey(Key('precio_recibir_${p.agua}')), '');
    await tester.pump();
    expect(habilitado(tester, 'boton_guardar_recibir'), isFalse);

    // En 0 no hace falta precio.
    await cantidad(tester, p.agua, 0);
    expect(habilitado(tester, 'boton_guardar_recibir'), isTrue);
  });

  testWidgets('sin pedido, al elegir proveedor pregunta si llegó uno', (
    tester,
  ) async {
    final p = await preparar(tester, abrirConPedido: false);

    await tester.tap(find.byKey(Key('opcion_proveedor_recibir_${p.postobon}')));
    await tester.pumpAndSettle();
    expect(find.text('¿Llegó alguno de estos pedidos?'), findsOneWidget);

    await tester.tap(find.byKey(Key('elegir_pedido_${p.pedido}')));
    await tester.pumpAndSettle();
    expect(find.text('pedido 24 · llegó 24'), findsOneWidget);

    await guardar(tester);
    await tester.tap(find.byKey(const Key('entendido_aviso_gasto')));
    await tester.pumpAndSettle();
    expect(
      (await db.select(db.pedidos).getSingle()).estado,
      EstadoPedido.recibido,
    );
  });

  testWidgets(
    'con líneas escritas, elegir un pedido pide confirmar y Cancelar las '
    'conserva',
    (tester) async {
      final p = await preparar(tester, abrirConPedido: false);
      final chip = find.byKey(Key('opcion_proveedor_recibir_${p.postobon}'));
      await tester.tap(chip);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('otra_mercancia')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('boton_agregar_producto_recibir')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('opcion_producto_recibir_${p.coca}')));
      await tester.pumpAndSettle();

      await tester.tap(chip);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('elegir_pedido_${p.pedido}')));
      await tester.pumpAndSettle();

      expect(find.text('¿Reemplazar lo que escribiste?'), findsOneWidget);
      expect(find.byKey(const Key('confirmar_reemplazar')), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byKey(Key('cantidad_recibir_${p.coca}')), findsOneWidget);
      expect(texto(tester, 'cantidad_recibir_${p.coca}'), '1');
      expect(find.byKey(Key('cantidad_recibir_${p.agua}')), findsNothing);
      expect(find.byKey(const Key('resumen_recepcion')), findsNothing);
    },
  );

  testWidgets('sin líneas escritas, elegir un pedido lo carga sin preguntar', (
    tester,
  ) async {
    final p = await preparar(tester, abrirConPedido: false);
    await tester.tap(find.byKey(Key('opcion_proveedor_recibir_${p.postobon}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('elegir_pedido_${p.pedido}')));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('pedido 24 · llegó 24'), findsOneWidget);
  });

  testWidgets('si falla cargar el pedido, muestra el error y deja de cargar', (
    tester,
  ) async {
    final p = await preparar(tester, abrirConPedido: false);
    final falla = ProviderContainer(
      parent: container,
      overrides: [
        pedidoRepositoryProvider.overrideWithValue(PedidoRotoAlDetallar(db)),
      ],
    );
    addTearDown(falla.dispose);
    // preparar dejó Recibir abierto sin pedido: se cierra antes de abrirlo.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      appDePrueba(falla, inicio: RecibirMercanciaScreen(pedidoId: p.pedido)),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('No se pudo cargar el pedido, intenta de nuevo'),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('"No, es otra mercancía" sigue sin pedido', (tester) async {
    final p = await preparar(tester, abrirConPedido: false);

    await tester.tap(find.byKey(Key('opcion_proveedor_recibir_${p.postobon}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('otra_mercancia')));
    await tester.pumpAndSettle();

    expect(find.textContaining('pedido 24'), findsNothing);
    expect(find.byKey(const Key('resumen_recepcion')), findsNothing);
  });

  testWidgets('un pedido ya recibido lo dice y no deja guardar', (
    tester,
  ) async {
    final p = await preparar(tester, abrirConPedido: false);
    await (db.update(db.pedidos)..where((x) => x.id.equals(p.pedido))).write(
      const PedidosCompanion(estado: Value(EstadoPedido.recibido)),
    );
    // preparar dejó Recibir abierto sin pedido: se cierra antes de abrirlo.
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      appDePrueba(
        container,
        inicio: RecibirMercanciaScreen(pedidoId: p.pedido),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Este pedido ya se recibió o se anuló'), findsOneWidget);
    expect(habilitado(tester, 'boton_guardar_recibir'), isFalse);
  });

  testWidgets(
    'si el pedido se cierra mientras está abierto, el error lo dice',
    (tester) async {
      final p = await preparar(tester);
      await (db.update(db.pedidos)..where((x) => x.id.equals(p.pedido))).write(
        const PedidosCompanion(estado: Value(EstadoPedido.anulado)),
      );

      await guardar(tester);

      expect(find.text('Este pedido ya se recibió o se anuló'), findsOneWidget);
      expect(find.text('No se pudo guardar, intenta de nuevo'), findsNothing);
      expect(await db.select(db.entradasMercancia).get(), isEmpty);
    },
  );

  testWidgets('con pedido el proveedor queda fijo', (tester) async {
    final p = await preparar(tester);

    expect(
      find.byKey(Key('opcion_proveedor_recibir_${p.postobon}')),
      findsNothing,
    );
    expect(find.byKey(const Key('proveedor_fijo_recibir')), findsOneWidget);
    expect(find.text('Postobón'), findsWidgets);
  });

  testWidgets('con pedido de un proveedor inactivo no deja guardar', (
    tester,
  ) async {
    final p = await preparar(tester, abrirConPedido: false);
    await ProveedorRepository(db).desactivar(p.postobon);
    // preparar dejó Recibir abierto sin pedido: se cierra antes de abrirlo.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      appDePrueba(
        container,
        inicio: RecibirMercanciaScreen(pedidoId: p.pedido),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Proveedor inactivo: actívalo para recibir'),
      findsOneWidget,
    );
    expect(habilitado(tester, 'boton_guardar_recibir'), isFalse);
  });

  testWidgets(
    'si el aviso de una vez falla, lo guardado no se da por fallido',
    (tester) async {
      final p = await preparar(tester, abrirConPedido: false);
      final falla = ProviderContainer(
        parent: container,
        overrides: [
          preferenciasProvider.overrideWithValue(_PreferenciasRotas()),
        ],
      );
      addTearDown(falla.dispose);
      // preparar dejó Recibir abierto sin pedido: se cierra antes de abrirlo.
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        appDePrueba(falla, inicio: RecibirMercanciaScreen(pedidoId: p.pedido)),
      );
      await tester.pumpAndSettle();

      await guardar(tester);

      expect(find.text('No se pudo guardar, intenta de nuevo'), findsNothing);
      expect(await db.select(db.entradasMercancia).get(), hasLength(1));
      expect(await db.select(db.gastos).get(), hasLength(1));
    },
  );
}

/// Preferencias que fallan al escribir, para probar el aviso de una vez.
class _PreferenciasRotas implements SharedPreferences {
  @override
  bool? getBool(String key) => null;

  @override
  Future<bool> setBool(String key, bool value) =>
      Future.error(Exception('disco lleno'));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Pedidos cuyo detalle falla, para probar la recuperación al cargar.
class PedidoRotoAlDetallar extends PedidoRepository {
  PedidoRotoAlDetallar(super.db);

  @override
  Future<({PedidoResumen resumen, List<LineaPedidoDetalle> lineas})>
  detallePedido(int pedidoId) => Future.error(Exception('sin base'));
}
