import 'package:app_ventas/ui/teclado_monto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/vibraciones.dart';

void main() {
  test('aplicarTecla agrega dígitos y ceros', () {
    expect(aplicarTecla(5, '3'), 53);
    expect(aplicarTecla(12, '000'), 12000);
    expect(aplicarTecla(0, '7'), 7);
  });

  test('aplicarTecla no deja ceros a la izquierda', () {
    expect(aplicarTecla(0, '0'), 0);
    expect(aplicarTecla(0, '000'), 0);
  });

  test('aplicarTecla borra el último dígito', () {
    expect(aplicarTecla(53, 'borrar'), 5);
    expect(aplicarTecla(5, 'borrar'), 0);
    expect(aplicarTecla(0, 'borrar'), 0);
  });

  test('aplicarTecla no pasa de 9 dígitos', () {
    expect(aplicarTecla(montoMaximo, '1'), montoMaximo);
    expect(aplicarTecla(1000000, '000'), 1000000);
  });

  testWidgets('TecladoMonto avisa cada tecla tocada', (tester) async {
    final teclas = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: TecladoMonto(onTecla: teclas.add)),
    ));

    await tester.tap(find.byKey(const Key('tecla_monto_2')));
    await tester.tap(find.byKey(const Key('tecla_monto_000')));
    await tester.tap(find.byKey(const Key('tecla_monto_borrar')));

    expect(teclas, ['2', '000', 'borrar']);
  });

  testWidgets('cada tecla del TecladoMonto vibra suave', (tester) async {
    final registro = registrarVibraciones(tester);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: TecladoMonto(onTecla: (_) {})),
    ));

    await tester.tap(find.byKey(const Key('tecla_monto_5')));
    expect(registro, ['HapticFeedbackType.selectionClick']);
  });
}
