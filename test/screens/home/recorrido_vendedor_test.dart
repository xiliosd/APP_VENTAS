import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/recorrido_provider.dart';
import 'package:app_ventas/repositories/configuracion_repository.dart';
import 'package:app_ventas/screens/home/home_screen.dart';
import 'package:app_ventas/screens/recorrido/globos_vendedor.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/montaje.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late SharedPreferences prefs;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await ConfiguracionRepository(db).guardarNombreTienda('La Esquina');
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> montar(
    WidgetTester tester, {
    required String rol,
    bool pendiente = true,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({
      ...consejosVistos,
      if (pendiente) claveRecorridoVendedor: true,
    });
    prefs = await SharedPreferences.getInstance();
    container = await containerConSesion(db, rol: rol, preferencias: prefs);
    await tester.pumpWidget(appDePrueba(container, inicio: const HomeScreen()));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'el vendedor ve el recorrido corto la primera vez en su celular',
    (tester) async {
      await montar(tester, rol: 'vendedor');

      expect(find.text(globosVendedor.first.texto), findsOneWidget);
      for (var i = 0; i < globosVendedor.length; i++) {
        await tester.tap(find.byKey(const Key('boton_siguiente_globo')));
        await tester.pumpAndSettle();
      }

      expect(find.byKey(const Key('burbuja_globo')), findsNothing);
      expect(prefs.getBool(claveRecorridoVendedor), isNot(true));
      expect(container.read(recorridoVendedorProvider), isFalse);
    },
  );

  testWidgets('saltarlo también lo da por visto', (tester) async {
    await montar(tester, rol: 'vendedor');

    await tester.tap(find.byKey(const Key('boton_saltar_recorrido')));
    await tester.pumpAndSettle();

    expect(container.read(recorridoVendedorProvider), isFalse);
  });

  testWidgets('el admin no ve ni gasta el recorrido del vendedor', (
    tester,
  ) async {
    await montar(tester, rol: 'admin');

    expect(find.text(globosVendedor.first.texto), findsNothing);
    expect(prefs.getBool(claveRecorridoVendedor), isTrue);
  });

  testWidgets('sin la marca el vendedor no ve recorrido', (tester) async {
    await montar(tester, rol: 'vendedor', pendiente: false);

    expect(find.byKey(const Key('burbuja_globo')), findsNothing);
  });
}
