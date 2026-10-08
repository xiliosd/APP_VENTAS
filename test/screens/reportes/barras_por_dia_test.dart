import 'package:app_ventas/screens/reportes/barras_por_dia.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> montar(WidgetTester tester, Map<DateTime, int> ventas,
      {DateTime? mejorDia}) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BarrasPorDia(ventasPorDia: ventas, mejorDia: mejorDia),
      ),
    ));
  }

  test('etiquetaDia usa el día de la semana abreviado', () {
    expect(etiquetaDia(DateTime(2026, 10, 5)), 'Lun 5');
    expect(etiquetaDia(DateTime(2026, 10, 7)), 'Mié 7');
    expect(etiquetaDia(DateTime(2026, 10, 10)), 'Sáb 10');
    expect(etiquetaDia(DateTime(2026, 10, 11)), 'Dom 11');
  });

  testWidgets('una fila por día y el mejor día resaltado', (tester) async {
    await montar(tester, {
      DateTime(2026, 10, 5): 2000,
      DateTime(2026, 10, 6): 5000,
      DateTime(2026, 10, 7): 0,
    }, mejorDia: DateTime(2026, 10, 6));

    expect(find.byType(Barra), findsNWidgets(3));
    expect(find.text('Lun 5'), findsOneWidget);
    expect(find.text(r'$5.000'), findsOneWidget);
    expect(find.text(r'Mejor día: martes 6 · $5.000'), findsOneWidget);
    final mejor = tester.widget<Barra>(find.byKey(const Key('barra_6')));
    expect(mejor.resaltada, isTrue);
    expect(mejor.fraccion, 1.0);
    final otra = tester.widget<Barra>(find.byKey(const Key('barra_5')));
    expect(otra.resaltada, isFalse);
    expect(otra.fraccion, 0.4);
  });

  testWidgets('todo en 0 no divide por cero ni muestra mejor día',
      (tester) async {
    await montar(tester, {
      DateTime(2026, 10, 5): 0,
      DateTime(2026, 10, 6): 0,
    });

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('texto_mejor_dia')), findsNothing);
    expect(tester.widget<Barra>(find.byKey(const Key('barra_5'))).fraccion,
        0.0);
  });

  test('etiquetaHora usa a. m., m. y p. m.', () {
    expect(etiquetaHora(0), '12 a. m.');
    expect(etiquetaHora(7), '7 a. m.');
    expect(etiquetaHora(12), '12 m.');
    expect(etiquetaHora(13), '1 p. m.');
    expect(etiquetaHora(18), '6 p. m.');
    expect(etiquetaHora(23), '11 p. m.');
  });

  testWidgets('Barras resalta la fila indicada', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Barras(
          filas: [
            FilaBarra(clave: 'h9', etiqueta: '9 a. m.', valor: 3000),
            FilaBarra(clave: 'h18', etiqueta: '6 p. m.', valor: 1500),
          ],
          resaltada: 'h9',
        ),
      ),
    ));

    expect(tester.widget<Barra>(find.byKey(const Key('barra_h9'))).resaltada,
        isTrue);
    expect(tester.widget<Barra>(find.byKey(const Key('barra_h18'))).fraccion,
        0.5);
  });

  testWidgets('con letra grande la etiqueta y el monto van en una línea',
      (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Barra(
          etiqueta: '10 a. m.',
          valor: 1250000,
          fraccion: 0.5,
          resaltada: false,
        ),
      ),
    ));

    expect(tester.takeException(), isNull);
    final alto = tester.getSize(find.text('10 a. m.')).height;
    expect(tester.getSize(find.text(r'$1.250.000')).height, alto);
    expect(alto, lessThan(50)); // una línea de 14 px al 200 %
  });
}
