import 'package:app_ventas/ui/boton_escanear.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget montar({VoidCallback? onPressed, String? texto}) => MaterialApp(
    home: Scaffold(
      body: texto == null
          ? BotonEscanear(onPressed: onPressed)
          : BotonEscanear(onPressed: onPressed, texto: texto),
    ),
  );

  testWidgets('muestra el texto y el ícono con alto mínimo de 48', (
    tester,
  ) async {
    var toques = 0;
    await tester.pumpWidget(montar(onPressed: () => toques++));
    expect(find.text('Escanear código'), findsOneWidget);
    expect(find.byIcon(Icons.qr_code_scanner_rounded), findsOneWidget);
    expect(
      tester.getSize(find.byType(BotonEscanear)).height,
      greaterThanOrEqualTo(48),
    );
    await tester.tap(find.byType(BotonEscanear));
    expect(toques, 1);
  });

  testWidgets('sin onPressed no llama nada', (tester) async {
    await tester.pumpWidget(montar());
    await tester.tap(find.byType(BotonEscanear), warnIfMissed: false);
    expect(
      tester
          .widget<ButtonStyleButton>(find.bySubtype<ButtonStyleButton>())
          .enabled,
      isFalse,
    );
  });

  testWidgets('acepta otro texto', (tester) async {
    await tester.pumpWidget(
      montar(onPressed: () {}, texto: 'Crear escaneando'),
    );
    expect(find.text('Crear escaneando'), findsOneWidget);
  });
}
