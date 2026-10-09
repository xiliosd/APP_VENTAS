import 'package:app_ventas/ui/colores_app.dart';
import 'package:app_ventas/ui/tema_app.dart';
import 'package:app_ventas/widgets/indicadores_pin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget hijo, {bool reducir = false}) => MaterialApp(
    theme: temaClaro(),
    home: MediaQuery(
        data: MediaQueryData(disableAnimations: reducir),
        child: Scaffold(body: Center(child: hijo))));

Color colorDe(WidgetTester t, int i) =>
    (t.widget<Container>(find.byKey(Key('indicador_pin_$i'))).decoration!
            as BoxDecoration)
        .color!;

double xDe(WidgetTester t) =>
    t.getTopLeft(find.byKey(const Key('indicador_pin_0'))).dx;

void main() {
  testWidgets('los llenos usan el primario', (tester) async {
    await tester.pumpWidget(_app(const IndicadoresPin(llenos: 2)));
    await tester.pumpAndSettle();
    expect(colorDe(tester, 0), ColoresApp.claro.primario);
    expect(colorDe(tester, 3), isNot(ColoresApp.claro.primario));
  });

  testWidgets('los vacíos tienen un aro visible (textoSecundario)',
      (tester) async {
    await tester.pumpWidget(_app(const IndicadoresPin(llenos: 0)));
    await tester.pumpAndSettle();
    final borde = (tester
                .widget<Container>(find.byKey(const Key('indicador_pin_0')))
                .decoration! as BoxDecoration)
        .border! as Border;
    expect(borde.top.color, ColoresApp.claro.textoSecundario);
  });

  testWidgets('un error sacude y pinta de rojo, y se repite con el siguiente',
      (tester) async {
    await tester.pumpWidget(_app(const IndicadoresPin(llenos: 0)));
    final x0 = xDe(tester);
    await tester.pumpWidget(_app(const IndicadoresPin(llenos: 0, errores: 1)));
    await tester.pump(const Duration(milliseconds: 50));
    expect(xDe(tester), isNot(x0));
    expect(colorDe(tester, 0), ColoresApp.claro.sale);
    await tester.pumpAndSettle();
    expect(xDe(tester), x0);
    expect(colorDe(tester, 0), isNot(ColoresApp.claro.sale));

    await tester.pumpWidget(_app(const IndicadoresPin(llenos: 0, errores: 2)));
    await tester.pump(const Duration(milliseconds: 50));
    expect(colorDe(tester, 0), ColoresApp.claro.sale);
    expect(xDe(tester), isNot(x0));
    await tester.pumpAndSettle();
  });

  testWidgets('con reducir movimiento no se sacude pero sí se pinta de rojo',
      (tester) async {
    await tester
        .pumpWidget(_app(const IndicadoresPin(llenos: 0), reducir: true));
    final x0 = xDe(tester);
    await tester.pumpWidget(
        _app(const IndicadoresPin(llenos: 0, errores: 1), reducir: true));
    await tester.pump();
    expect(xDe(tester), x0);
    expect(colorDe(tester, 0), ColoresApp.claro.sale);
    await tester.pump(const Duration(milliseconds: 400));
    expect(colorDe(tester, 0), isNot(ColoresApp.claro.sale));
  });
}
