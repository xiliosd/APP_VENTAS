import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/screens/login/bienvenida_screen.dart';
import 'package:app_ventas/screens/respaldo/verificar_telefono_screen.dart';
import 'package:app_ventas/ui/tema_app.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/respaldo_prueba.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> abrir(WidgetTester tester, NubeRespaldoFalsa? nube) async {
    final container = await containerRespaldo(db, nube);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: temaApp(), home: const BienvenidaScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('sin respaldo configurado solo ofrece crear la tienda', (
    tester,
  ) async {
    await abrir(tester, null);

    expect(find.byKey(const Key('boton_crear_tienda')), findsOneWidget);
    expect(find.byKey(const Key('boton_restaurar_tienda')), findsNothing);
  });

  testWidgets('con respaldo configurado ofrece restaurar', (tester) async {
    await abrir(tester, NubeRespaldoFalsa());

    await tester.tap(find.byKey(const Key('boton_restaurar_tienda')));
    await tester.pumpAndSettle();

    final pantalla = tester.widget<VerificarTelefonoScreen>(
      find.byType(VerificarTelefonoScreen),
    );
    expect(pantalla.modo, ModoVerificacion.restaurar);
  });
}
