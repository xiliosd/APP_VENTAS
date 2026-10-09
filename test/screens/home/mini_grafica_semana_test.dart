import 'package:app_ventas/screens/home/mini_grafica_semana.dart';
import 'package:app_ventas/ui/colores_app.dart';
import 'package:app_ventas/ui/tema_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget hijo) => MaterialApp(
    theme: temaClaro(),
    home: Scaffold(body: Center(child: SizedBox(width: 240, child: hijo))));

Color colorBarra(WidgetTester tester, int i) =>
    (tester.widget<Container>(find.byKey(Key('barra_dia_$i'))).decoration!
            as BoxDecoration)
        .color!;

void main() {
  final jueves = DateTime(2026, 10, 9);

  testWidgets('7 barras con iniciales y el día elegido resaltado', (tester) async {
    await tester.pumpWidget(_app(MiniGraficaSemana(
        valores: const [1, 2, 3, 4, 5, 6, 7], hasta: jueves)));
    await tester.pumpAndSettle();
    for (var i = 0; i < 7; i++) {
      expect(find.byKey(Key('barra_dia_$i')), findsOneWidget);
    }
    // 3 oct (viernes) .. 9 oct (jueves)
    expect(find.text('V'), findsOneWidget);
    expect(find.text('J'), findsOneWidget);
    expect(colorBarra(tester, 6), ColoresApp.claro.marcaVerde);
    expect(colorBarra(tester, 0), isNot(ColoresApp.claro.marcaVerde));
  });

  testWidgets('la barra más alta es la del valor máximo', (tester) async {
    await tester.pumpWidget(_app(MiniGraficaSemana(
        valores: const [10, 50, 0, 0, 0, 0, 20], hasta: jueves)));
    await tester.pumpAndSettle();
    final alto1 = tester.getSize(find.byKey(const Key('barra_dia_1'))).height;
    final alto6 = tester.getSize(find.byKey(const Key('barra_dia_6'))).height;
    final alto2 = tester.getSize(find.byKey(const Key('barra_dia_2'))).height;
    expect(alto1, greaterThan(alto6));
    expect(alto2, 4); // sin ventas: barra mínima
  });

  testWidgets('todo en cero no falla', (tester) async {
    await tester.pumpWidget(_app(MiniGraficaSemana(
        valores: const [0, 0, 0, 0, 0, 0, 0], hasta: jueves)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('tocarla llama onTap y tiene semántica', (tester) async {
    var tocada = false;
    await tester.pumpWidget(_app(MiniGraficaSemana(
        valores: const [1, 2, 3, 4, 5, 6, 7],
        hasta: jueves,
        onTap: () => tocada = true)));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(MiniGraficaSemana));
    expect(tocada, isTrue);
    expect(find.bySemanticsLabel(RegExp('Ventas de los últimos 7 días')),
        findsOneWidget);
  });
}
