import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/screens/recorrido/paso_venta_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/montaje.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({'recorrido_paso': 'venta'});
    final prefs = await SharedPreferences.getInstance();
    container = await containerConSesion(db, preferencias: prefs);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  testWidgets('ofrece Vender escaneando además de Empezar', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      appDePrueba(container, inicio: const PasoVentaScreen()),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('boton_empezar_practica')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('boton_vender_escaneando')),
        matching: find.text('Vender escaneando'),
      ),
      findsOneWidget,
    );
  });
}
