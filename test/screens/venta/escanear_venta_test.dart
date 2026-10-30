import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/screens/escaner/consejos_escaner.dart';
import 'package:app_ventas/screens/venta/registrar_venta_screen.dart';
import 'package:app_ventas/servicios/lector_codigo.dart';
import 'package:app_ventas/ui/boton_escanear.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/lector_falso.dart';
import '../../support/montaje.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late LectorFalso lector;
  late SharedPreferences preferencias;
  final navegador = GlobalKey<NavigatorState>();

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> abrir(
    WidgetTester tester, {
    String rol = 'admin',
    bool practica = false,
    bool consejoVisto = false,
  }) async {
    SharedPreferences.setMockInitialValues({
      if (consejoVisto) ...consejosVistos,
    });
    preferencias = await SharedPreferences.getInstance();
    lector = LectorFalso([]);
    container = await containerConSesion(
      db,
      rol: rol,
      preferencias: preferencias,
      overrides: [lectorCodigoProvider.overrideWithValue(lector)],
    );
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      appDePrueba(
        container,
        navegador: navegador,
        inicio: Scaffold(
          body: Builder(
            builder: (contexto) => TextButton(
              onPressed: () => Navigator.of(contexto).push(
                MaterialPageRoute(
                  builder: (_) => RegistrarVentaScreen(
                    practica: practica,
                    conGlobos: false,
                  ),
                ),
              ),
              child: const Text('Abrir venta'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir venta'));
    await tester.pumpAndSettle();
  }

  testWidgets('muestra Escanear código con texto, también al vendedor', (
    tester,
  ) async {
    await abrir(tester, rol: 'vendedor', consejoVisto: true);
    expect(
      find.widgetWithText(BotonEscanear, 'Escanear código'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('boton_escanear_venta')), findsOneWidget);
  });

  testWidgets('la primera vez muestra el consejo y lo recuerda', (
    tester,
  ) async {
    await abrir(tester);
    expect(find.text(consejoEscanearVenta.texto), findsOneWidget);
    expect(preferencias.getBool('consejo_visto_escanearVenta'), isTrue);

    await tester.tap(find.byKey(const Key('boton_entendido_consejo')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('capa_globos')), findsNothing);

    navegador.currentState!.pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abrir venta'));
    await tester.pumpAndSettle();
    expect(find.text(consejoEscanearVenta.texto), findsNothing);
  });

  testWidgets('tocar Escanear código cierra el consejo y escanea', (
    tester,
  ) async {
    await abrir(tester);
    expect(find.byKey(const Key('capa_globos')), findsOneWidget);
    await tester.tap(find.byKey(const Key('boton_escanear_venta')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('capa_globos')), findsNothing);
    expect(lector.usos, [UsoEscaner.venta]);
  });

  testWidgets('salir con el consejo abierto lo quita', (tester) async {
    await abrir(tester);
    expect(find.byKey(const Key('capa_globos')), findsOneWidget);
    navegador.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('capa_globos')), findsNothing);
  });

  testWidgets('en la práctica hay botón de escanear, sin consejo, y usa '
      'UsoEscaner.practica', (tester) async {
    await abrir(tester, practica: true);
    expect(find.byKey(const Key('boton_escanear_venta')), findsOneWidget);
    expect(find.byKey(const Key('capa_globos')), findsNothing);
    await tester.tap(find.byKey(const Key('boton_escanear_venta')));
    await tester.pumpAndSettle();
    expect(lector.usos, [UsoEscaner.practica]);
  });
}
