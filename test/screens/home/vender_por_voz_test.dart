import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/screens/home/resumen_screen.dart';
import 'package:app_ventas/screens/venta/registrar_venta_screen.dart';
import 'package:app_ventas/servicios/dictado.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/dictado_falso.dart';
import '../../support/montaje.dart';

void main() {
  late AppDatabase db;
  late DictadoFalso dictado;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    dictado = DictadoFalso();
  });
  tearDown(() => db.close());

  Future<void> montar(
    WidgetTester tester, {
    Size tamano = const Size(1080, 2400),
    double escala = 1,
  }) async {
    tester.view.physicalSize = tamano;
    tester.view.devicePixelRatio = tamano.width > 500 ? 2.625 : 1;
    addTearDown(tester.view.reset);
    final container = await containerConSesion(
      db,
      overrides: [dictadoProvider.overrideWithValue(dictado)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      appDePrueba(
        container,
        inicio: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(escala)),
            child: const Scaffold(body: ResumenScreen()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('"Vender por voz" abre Nueva venta escuchando', (tester) async {
    await montar(tester);

    expect(find.byTooltip('Vender por voz'), findsOneWidget);
    await tester.tap(find.byKey(const Key('boton_vender_por_voz')));
    await tester.pumpAndSettle();

    expect(find.byType(RegistrarVentaScreen), findsOneWidget);
    expect(dictado.escuchas, 1);
  });

  // 1,6× como la prueba de letra grande del Inicio (modo_oscuro_test): con
  // 2,0× su contenido ya se desbordaba antes de este botón (anotado aparte).
  testWidgets('con letra grande la barra con el micrófono no desborda', (
    tester,
  ) async {
    await montar(tester, escala: 1.6);

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('boton_vender_por_voz')), findsOneWidget);
  });
}
