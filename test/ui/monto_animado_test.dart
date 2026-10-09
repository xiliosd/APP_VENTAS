import 'package:app_ventas/ui/monto_animado.dart';
import 'package:app_ventas/ui/tema_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget hijo, {bool reducir = false}) => MaterialApp(
      theme: temaClaro(),
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reducir),
        child: Scaffold(body: hijo),
      ),
    );

void main() {
  testWidgets('la primera vez muestra el valor sin animar', (tester) async {
    await tester.pumpWidget(_app(const MontoAnimado(5000)));
    expect(find.text(r'$5.000'), findsOneWidget);
  });

  testWidgets('al cambiar cuenta y termina en el valor nuevo', (tester) async {
    await tester.pumpWidget(_app(const MontoAnimado(5000)));
    await tester.pumpWidget(_app(const MontoAnimado(17500)));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(r'$17.500'), findsNothing);
    await tester.pumpAndSettle();
    expect(find.text(r'$17.500'), findsOneWidget);
  });

  testWidgets('dos cambios seguidos terminan en el último', (tester) async {
    await tester.pumpWidget(_app(const MontoAnimado(5000)));
    await tester.pumpWidget(_app(const MontoAnimado(10000)));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpWidget(_app(const MontoAnimado(30000)));
    await tester.pumpAndSettle();
    expect(find.text(r'$30.000'), findsOneWidget);
  });

  testWidgets('con reducir movimiento muestra el valor nuevo de inmediato',
      (tester) async {
    await tester.pumpWidget(_app(const MontoAnimado(5000), reducir: true));
    await tester.pumpWidget(_app(const MontoAnimado(17500), reducir: true));
    await tester.pump();
    expect(find.text(r'$17.500'), findsOneWidget);
  });
}
