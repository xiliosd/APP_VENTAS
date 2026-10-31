import 'dart:io';

import 'package:app_ventas/ui/error_carga.dart';
import 'package:app_ventas/ui/tema_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _envolver(Widget hijo, {double escala = 1}) => MaterialApp(
  theme: temaClaro(),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(textScaler: TextScaler.linear(escala)),
    child: child!,
  ),
  home: Scaffold(body: hijo),
);

void main() {
  testWidgets('muestra el texto amable en modo normal', (tester) async {
    await tester.pumpWidget(_envolver(const ErrorCarga()));
    expect(find.text('No se pudo cargar'), findsOneWidget);
    expect(find.text('Cierra la app y vuelve a abrirla'), findsOneWidget);
  });

  testWidgets('muestra el texto amable en modo compacto', (tester) async {
    await tester.pumpWidget(_envolver(const ErrorCarga(compacto: true)));
    expect(find.text('No se pudo cargar'), findsOneWidget);
    expect(find.text('Cierra la app y vuelve a abrirla'), findsNothing);
  });

  for (final compacto in [false, true]) {
    testWidgets('a letra 2,0x en 360 dp no desborda (compacto: $compacto)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _envolver(ErrorCarga(compacto: compacto), escala: 2),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('con poco alto se desplaza en vez de desbordar', (tester) async {
    await tester.pumpWidget(
      _envolver(
        const Align(
          alignment: Alignment.topCenter,
          child: SizedBox(height: 120, child: ErrorCarga()),
        ),
        escala: 2,
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('con alto sin límite no falla', (tester) async {
    await tester.pumpWidget(
      _envolver(const SingleChildScrollView(child: ErrorCarga())),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('No se pudo cargar'), findsOneWidget);
  });

  test('ninguna pantalla muestra el texto de una excepción', () {
    final patron = RegExp(r'''Text\(\s*['"]Error: \$''');
    final fuera = <String>[];
    for (final archivo in Directory('lib').listSync(recursive: true)) {
      if (archivo is! File || !archivo.path.endsWith('.dart')) continue;
      if (patron.hasMatch(archivo.readAsStringSync())) {
        fuera.add(archivo.path.replaceAll(r'\', '/'));
      }
    }
    expect(
      fuera,
      isEmpty,
      reason: 'Usar ErrorCarga en vez de mostrar la excepción',
    );
  });
}
