import 'package:app_ventas/ui/movimiento.dart';
import 'package:app_ventas/ui/vibracion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/vibraciones.dart';

void main() {
  testWidgets('con reducir movimiento las duraciones son cero', (tester) async {
    late Duration normal, reducida;
    await tester.pumpWidget(Builder(builder: (context) {
      normal = Movimiento.duracion(context, Movimiento.media);
      return MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Builder(builder: (context) {
          reducida = Movimiento.duracion(context, Movimiento.media);
          return const SizedBox();
        }),
      );
    }));
    expect(normal, Movimiento.media);
    expect(reducida, Duration.zero);
  });

  test('el resorte rebota por encima de 1 y termina en 1', () {
    final valores = [for (var t = 0.0; t <= 1.0; t += 0.05) Movimiento.resorte.transform(t)];
    expect(valores.any((v) => v > 1.0), isTrue);
    expect(Movimiento.resorte.transform(1.0), closeTo(1.0, 1e-6));
  });

  testWidgets('cada vibración usa su tipo', (tester) async {
    final registro = registrarVibraciones(tester);
    Vibracion.toque();
    Vibracion.exito();
    Vibracion.error();
    await tester.pump();
    expect(registro, [
      'HapticFeedbackType.selectionClick',
      'HapticFeedbackType.mediumImpact',
      'HapticFeedbackType.heavyImpact',
    ]);
  });
}
