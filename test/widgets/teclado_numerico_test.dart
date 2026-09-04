import 'package:app_ventas/widgets/teclado_numerico.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('tapping a digit calls onDigito with that digit', (tester) async {
    String? digitoPresionado;
    await tester.pumpWidget(MaterialApp(
      home: TecladoNumerico(
        onDigito: (d) => digitoPresionado = d,
        onBorrar: () {},
      ),
    ));

    await tester.tap(find.byKey(const Key('tecla_5')));
    expect(digitoPresionado, '5');
  });

  testWidgets('tapping the backspace key calls onBorrar', (tester) async {
    var borrado = false;
    await tester.pumpWidget(MaterialApp(
      home: TecladoNumerico(
        onDigito: (_) {},
        onBorrar: () => borrado = true,
      ),
    ));

    await tester.tap(find.byKey(const Key('tecla_⌫')));
    expect(borrado, isTrue);
  });
}
