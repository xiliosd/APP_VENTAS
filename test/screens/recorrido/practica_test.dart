import 'dart:async';

import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/recorrido_provider.dart';
import 'package:app_ventas/screens/recorrido/paso_venta_screen.dart';
import 'package:app_ventas/screens/venta/registrar_venta_screen.dart';
import 'package:app_ventas/servicios/lector_codigo.dart';
import 'package:app_ventas/servicios/open_food_facts.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:app_ventas/providers/ticket_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/lector_falso.dart';
import '../../support/montaje.dart';

/// Sin internet en las pruebas: la hoja rápida no autocompleta nada.
class _SinDatos implements ConsultaProducto {
  @override
  Future<DatosProducto?> buscar(String codigo) async => null;
}

/// Lector que se queda "abierto" hasta que la prueba completa [lectura].
class _LectorPendiente implements LectorCodigo {
  final lectura = Completer<String?>();

  @override
  Future<String?> leer(
    BuildContext context, {
    UsoEscaner uso = UsoEscaner.venta,
  }) => lectura.future;
}

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late SharedPreferences prefs;
  final navegador = GlobalKey<NavigatorState>();

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({'recorrido_paso': 'venta'});
    prefs = await SharedPreferences.getInstance();
    container = await containerConSesion(db, preferencias: prefs);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  void vistaCelular(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
  }

  Future<void> abrirPractica(
    WidgetTester tester, {
    bool conProducto = true,
    bool conGlobos = true,
  }) async {
    vistaCelular(tester);
    if (conProducto) {
      await db
          .into(db.productos)
          .insert(ProductosCompanion.insert(nombre: 'Pan', precio: 6000));
    }
    await tester.pumpWidget(appDePrueba(container, navegador: navegador));
    navegador.currentState!.push(
      MaterialPageRoute(
        builder: (_) =>
            RegistrarVentaScreen(practica: true, conGlobos: conGlobos),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> cobrarPractica(WidgetTester tester, String clave) async {
    await tester.tap(find.text('Pan'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('boton_cobrar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key(clave)));
    await tester.pumpAndSettle();
  }

  Future<void> sinNadaGuardado() async {
    expect(await db.select(db.ventas).get(), isEmpty);
    expect(await db.select(db.lineasVenta).get(), isEmpty);
    expect(await db.select(db.clientes).get(), isEmpty);
  }

  testWidgets('muestra la franja de práctica y el primer globo', (
    tester,
  ) async {
    await abrirPractica(tester);
    expect(find.byKey(const Key('franja_practica')), findsOneWidget);
    expect(
      find.text('Toca un producto para sumarlo al ticket.'),
      findsOneWidget,
    );
  });

  testWidgets('efectivo: no guarda nada y muestra ¡Así de fácil!', (
    tester,
  ) async {
    await abrirPractica(tester);
    await cobrarPractica(tester, 'pago_efectivo');
    expect(find.byKey(const Key('hoja_asi_de_facil')), findsOneWidget);
    await sinNadaGuardado();
    await tester.tap(find.byKey(const Key('boton_continuar_practica')));
    await tester.pumpAndSettle();
    expect(find.byType(RegistrarVentaScreen), findsNothing);
    expect(container.read(recorridoProvider), PasoRecorrido.inicio);
    await sinNadaGuardado();
  });

  testWidgets('transferencia: no abre el QR ni guarda', (tester) async {
    // Con la guía solo se puede tocar Efectivo; sin ella, las demás formas.
    await abrirPractica(tester, conGlobos: false);
    await cobrarPractica(tester, 'pago_transferencia');
    expect(find.byKey(const Key('imagen_qr')), findsNothing);
    expect(find.text('Cobro por QR'), findsNothing);
    expect(find.byKey(const Key('hoja_asi_de_facil')), findsOneWidget);
    await sinNadaGuardado();
  });

  testWidgets('fiado con cliente nuevo: no crea cliente ni venta', (
    tester,
  ) async {
    await abrirPractica(tester, conGlobos: false);
    await tester.tap(find.text('Pan'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('boton_cobrar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pago_fiado')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('campo_cliente')), 'Pedro');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('boton_cliente_nuevo')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('campo_nombre_cliente')),
      'Pedro',
    );
    await tester.enterText(
      find.byKey(const Key('campo_apellido_cliente')),
      'Gómez',
    );
    await tester.tap(find.byKey(const Key('boton_continuar_cliente')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('boton_fiar')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('hoja_asi_de_facil')), findsOneWidget);
    await sinNadaGuardado();
  });

  testWidgets('con la guía, Transferencia queda bloqueada', (tester) async {
    await abrirPractica(tester);
    await tester.tap(find.text('Pan'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('boton_cobrar')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('pago_transferencia')),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('hoja_como_paga')), findsOneWidget);
    expect(find.text('Elige cómo paga. Toca Efectivo.'), findsOneWidget);
  });

  testWidgets('los globos guían: producto → Cobrar → Efectivo', (tester) async {
    await abrirPractica(tester);
    await tester.tap(find.text('Pan'));
    await tester.pumpAndSettle();
    expect(find.text('Aquí ves el total. Toca Cobrar.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('boton_cobrar')));
    await tester.pumpAndSettle();
    expect(find.text('Elige cómo paga. Toca Efectivo.'), findsOneWidget);
    // La capa queda encima de la hoja y no tapa Efectivo.
    await tester.tap(find.byKey(const Key('pago_efectivo')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('hoja_asi_de_facil')), findsOneWidget);
    expect(find.byKey(const Key('capa_globos')), findsNothing);
  });

  testWidgets('cerrar la hoja sin elegir vuelve al globo de Cobrar', (
    tester,
  ) async {
    await abrirPractica(tester);
    await tester.tap(find.text('Pan'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('boton_cobrar')));
    await tester.pumpAndSettle();
    navegador.currentState!.pop(); // cierra la hoja
    await tester.pumpAndSettle();
    expect(find.text('Aquí ves el total. Toca Cobrar.'), findsOneWidget);
    await sinNadaGuardado();
  });

  testWidgets('Saltar recorrido en la práctica cierra y marca hecho', (
    tester,
  ) async {
    await abrirPractica(tester);
    await tester.tap(find.byKey(const Key('boton_saltar_recorrido')));
    await tester.pumpAndSettle();
    expect(container.read(recorridoProvider), PasoRecorrido.hecho);
    expect(find.byType(RegistrarVentaScreen), findsNothing);
  });

  testWidgets('sin productos el primer globo señala un monto rápido', (
    tester,
  ) async {
    await abrirPractica(tester, conProducto: false);
    expect(
      find.text('Toca un producto para sumarlo al ticket.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('monto_rapido_1000')));
    await tester.pumpAndSettle();
    expect(find.text('Aquí ves el total. Toca Cobrar.'), findsOneWidget);
  });

  testWidgets('PasoVenta: Empezar abre la práctica', (tester) async {
    vistaCelular(tester);
    await tester.pumpWidget(appDePrueba(container, navegador: navegador));
    navegador.currentState!.push(
      MaterialPageRoute(builder: (_) => const PasoVentaScreen()),
    );
    await tester.pumpAndSettle();
    expect(find.text('Paso 3 de 4'), findsOneWidget);
    await tester.tap(find.byKey(const Key('boton_empezar_practica')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('franja_practica')), findsOneWidget);
    expect(find.byType(PasoVentaScreen), findsNothing);
  });

  testWidgets('PasoVenta: Omitir pasa al Inicio', (tester) async {
    vistaCelular(tester);
    await tester.pumpWidget(appDePrueba(container, navegador: navegador));
    navegador.currentState!.push(
      MaterialPageRoute(builder: (_) => const PasoVentaScreen()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('boton_omitir_practica')));
    await tester.pumpAndSettle();
    expect(find.byType(PasoVentaScreen), findsNothing);
    expect(container.read(recorridoProvider), PasoRecorrido.inicio);
  });

  testWidgets('Saltar con la hoja de pago abierta cierra la práctica', (
    tester,
  ) async {
    await abrirPractica(tester);
    await tester.tap(find.text('Pan'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('boton_cobrar')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('hoja_como_paga')), findsOneWidget);
    await tester.tap(find.byKey(const Key('boton_saltar_recorrido')));
    await tester.pumpAndSettle();
    expect(find.byType(RegistrarVentaScreen), findsNothing);
    expect(find.byKey(const Key('hoja_como_paga')), findsNothing);
    expect(container.read(recorridoProvider), PasoRecorrido.hecho);
    await sinNadaGuardado();
  });

  group('Vender escaneando', () {
    /// Abre la práctica con [lector] y el escáner al abrir.
    Future<void> abrirEscaneando(
      WidgetTester tester,
      LectorCodigo lector, {
      bool settle = true,
    }) async {
      container.dispose();
      container = await containerConSesion(
        db,
        preferencias: prefs,
        overrides: [
          lectorCodigoProvider.overrideWithValue(lector),
          consultaProductoProvider.overrideWithValue(_SinDatos()),
        ],
      );
      vistaCelular(tester);
      await tester.pumpWidget(appDePrueba(container, navegador: navegador));
      navegador.currentState!.push(
        MaterialPageRoute(
          builder: (_) =>
              const RegistrarVentaScreen(practica: true, escanearAlAbrir: true),
        ),
      );
      if (settle) await tester.pumpAndSettle();
    }

    testWidgets('Vender escaneando con código conocido suma y lleva a Cobrar', (
      tester,
    ) async {
      await db
          .into(db.productos)
          .insert(
            ProductosCompanion.insert(
              nombre: 'Pan',
              precio: 6000,
              codigoBarras: const Value('111'),
            ),
          );
      final lector = LectorFalso(['111']);
      await abrirEscaneando(tester, lector);
      expect(container.read(ticketProvider).lineas, hasLength(1));
      expect(find.text('Aquí ves el total. Toca Cobrar.'), findsOneWidget);
      expect(lector.usos, [UsoEscaner.practica]);
    });

    testWidgets('sin cámara sigue la práctica normal', (tester) async {
      await db
          .into(db.productos)
          .insert(ProductosCompanion.insert(nombre: 'Pan', precio: 6000));
      await abrirEscaneando(tester, LectorFalso([null]));
      expect(
        find.text('Toca un producto para sumarlo al ticket.'),
        findsOneWidget,
      );
    });

    testWidgets('los globos no aparecen mientras el escáner está abierto', (
      tester,
    ) async {
      final lector = _LectorPendiente();
      await abrirEscaneando(tester, lector, settle: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(const Key('capa_globos')), findsNothing);
      lector.lectura.complete(null);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('capa_globos')), findsOneWidget);
    });

    testWidgets(
      'código desconocido crea un producto real y la venta sigue de práctica',
      (tester) async {
        await abrirEscaneando(tester, LectorFalso(['999']));
        expect(find.byKey(const Key('hoja_producto_rapido')), findsOneWidget);
        await tester.enterText(
          find.byKey(const Key('campo_nombre_rapido')),
          'Leche',
        );
        await tester.enterText(
          find.byKey(const Key('campo_precio_rapido')),
          '4000',
        );
        await tester.tap(
          find.byKey(const Key('boton_guardar_producto_rapido')),
        );
        await tester.pumpAndSettle();
        final productos = await db.select(db.productos).get();
        expect(productos.single.nombre, 'Leche');
        expect(productos.single.codigoBarras, '999');
        await tester.tap(find.byKey(const Key('boton_cobrar')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('pago_efectivo')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('hoja_asi_de_facil')), findsOneWidget);
        await sinNadaGuardado();
      },
    );
  });
}
