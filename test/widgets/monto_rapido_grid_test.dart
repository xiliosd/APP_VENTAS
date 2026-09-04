import 'package:app_ventas/widgets/monto_rapido_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('tapping a quick amount calls onSeleccionar with that amount',
      (tester) async {
    int? montoElegido;
    await tester.pumpWidget(MaterialApp(
      home: MontoRapidoGrid(onSeleccionar: (m) => montoElegido = m),
    ));

    await tester.tap(find.byKey(const Key('monto_rapido_5000')));
    expect(montoElegido, 5000);
  });
}
