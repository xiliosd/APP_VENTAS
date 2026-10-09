import 'package:app_ventas/ui/aplastable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Aplastable se encoge al presionar y vuelve al soltar',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Center(
            child: Aplastable(
                child: SizedBox(width: 80, height: 80, child: Text('x'))))));
    double escala() =>
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;
    final g = await tester.startGesture(tester.getCenter(find.text('x')));
    await tester.pump();
    expect(escala(), 0.94);
    await g.up();
    await tester.pumpAndSettle();
    expect(escala(), 1.0);
  });
}
