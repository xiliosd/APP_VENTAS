import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/recorrido_provider.dart';
import 'package:app_ventas/respaldo/respaldo_provider.dart';
import 'package:app_ventas/screens/recorrido/paso_venta_screen.dart';
import 'package:app_ventas/screens/venta/registrar_venta_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/montaje.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  final navegador = GlobalKey<NavigatorState>();

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({'recorrido_paso': 'venta'});
    final prefs = await SharedPreferences.getInstance();
    container = await containerConSesion(db,
        overrides: [preferenciasProvider.overrideWithValue(prefs)]);
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

  Future<void> abrirPractica(WidgetTester tester,
      {bool conProducto = true, bool conGlobos = true}) async {
    vistaCelular(tester);
    if (conProducto) {
      await db
          .into(db.productos)
          .insert(ProductosCompanion.insert(nombre: 'Pan', precio: 6000));
    }
    await tester.pumpWidget(appDePrueba(container, navegador: navegador));
    navegador.currentState!.push(MaterialPageRoute(
        builder: (_) =>
            RegistrarVentaScreen(practica: true, conGlobos: conGlobos)));
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

  testWidgets('muestra la franja de práctica y el primer globo',
      (tester) async {
    await abrirPractica(tester);
    expect(find.byKey(const Key('franja_practica')), findsOneWidget);
    expect(find.text('Toca un producto para sumarlo al ticket.'),
        findsOneWidget);
  });

  testWidgets('efectivo: no guarda nada y muestra ¡Así de fácil!',
      (tester) async {
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

  testWidgets('fiado con cliente escrito: no crea cliente ni venta',
      (tester) async {
    await abrirPractica(tester, conGlobos: false);
    await tester.tap(find.text('Pan'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('boton_cobrar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pago_fiado')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('campo_cliente')), 'Don Pedro');
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
    await tester.tap(find.byKey(const Key('pago_transferencia')),
        warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('hoja_como_paga')), findsOneWidget);
    expect(find.text('Elige cómo paga. Toca Efectivo.'), findsOneWidget);
  });

  testWidgets('los globos guían: producto → Cobrar → Efectivo',
      (tester) async {
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

  testWidgets('cerrar la hoja sin elegir vuelve al globo de Cobrar',
      (tester) async {
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

  testWidgets('Saltar recorrido en la práctica cierra y marca hecho',
      (tester) async {
    await abrirPractica(tester);
    await tester.tap(find.byKey(const Key('boton_saltar_recorrido')));
    await tester.pumpAndSettle();
    expect(container.read(recorridoProvider), PasoRecorrido.hecho);
    expect(find.byType(RegistrarVentaScreen), findsNothing);
  });

  testWidgets('sin productos el primer globo señala un monto rápido',
      (tester) async {
    await abrirPractica(tester, conProducto: false);
    expect(find.text('Toca un producto para sumarlo al ticket.'),
        findsOneWidget);
    await tester.tap(find.byKey(const Key('monto_rapido_1000')));
    await tester.pumpAndSettle();
    expect(find.text('Aquí ves el total. Toca Cobrar.'), findsOneWidget);
  });

  testWidgets('PasoVenta: Empezar abre la práctica', (tester) async {
    vistaCelular(tester);
    await tester.pumpWidget(appDePrueba(container, navegador: navegador));
    navegador.currentState!.push(
        MaterialPageRoute(builder: (_) => const PasoVentaScreen()));
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
        MaterialPageRoute(builder: (_) => const PasoVentaScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('boton_omitir_practica')));
    await tester.pumpAndSettle();
    expect(find.byType(PasoVentaScreen), findsNothing);
    expect(container.read(recorridoProvider), PasoRecorrido.inicio);
  });
}
