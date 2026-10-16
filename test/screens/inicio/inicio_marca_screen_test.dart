import 'package:app_ventas/screens/inicio/inicio_marca_screen.dart';
import 'package:app_ventas/ui/marca_app.dart';
import 'package:app_ventas/ui/tema_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late int terminados;

  setUp(() => terminados = 0);

  Future<void> montar(
    WidgetTester tester, {
    required bool completa,
    bool sinAnimaciones = false,
    ThemeData? tema,
    double escala = 1,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: tema ?? temaClaro(),
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations: sinAnimaciones,
              textScaler: TextScaler.linear(escala),
            ),
            child: InicioMarcaScreen(
              completa: completa,
              onTerminar: () => terminados++,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('la versión completa muestra la marca y termina a los 1,5 s', (
    tester,
  ) async {
    await montar(tester, completa: true);

    expect(find.byKey(const Key('toldo_marca')), findsOneWidget);
    expect(find.byKey(const Key('insignia_marca')), findsOneWidget);
    expect(find.text('VeciTienda'), findsOneWidget);
    expect(find.text(MarcaApp.slogan), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1000));
    // El logo ya apareció (mientras es invisible no se anuncia).
    expect(find.bySemanticsLabel('Logo de VeciTienda'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 400));
    expect(terminados, 0);
    await tester.pump(const Duration(milliseconds: 150));
    expect(terminados, 1);
  });

  testWidgets('la versión breve termina a los 0,5 s', (tester) async {
    await montar(tester, completa: false);

    await tester.pump(const Duration(milliseconds: 450));
    expect(terminados, 0);
    await tester.pump(const Duration(milliseconds: 100));
    expect(terminados, 1);
  });

  testWidgets('tocar salta enseguida y una sola vez', (tester) async {
    await montar(tester, completa: true);
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byType(InicioMarcaScreen));
    await tester.tap(find.byType(InicioMarcaScreen));
    await tester.pumpAndSettle();

    expect(terminados, 1);
  });

  testWidgets('con reducir movimiento todo queda quieto y pasa a los 0,3 s', (
    tester,
  ) async {
    await montar(tester, completa: true, sinAnimaciones: true);
    await tester.pump();

    final escala = tester.widget<Transform>(
      find.byKey(const Key('toldo_marca')),
    );
    // storage[5] es la escala vertical: el toldo ya está abierto.
    expect(escala.transform.storage[5], closeTo(1, 0.001));

    await tester.pump(const Duration(milliseconds: 250));
    expect(terminados, 0);
    await tester.pump(const Duration(milliseconds: 100));
    expect(terminados, 1);
  });

  testWidgets('se anuncia con el nombre y el eslogan', (tester) async {
    await montar(tester, completa: false);

    expect(
      find.bySemanticsLabel(
        'VeciTienda, la tranquilidad de tu tienda, en tu bolsillo',
      ),
      findsOneWidget,
    );
  });

  testWidgets('en oscuro con letra 2,0× en un celular pequeño no desborda', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await montar(tester, completa: true, tema: temaOscuro(), escala: 2);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
