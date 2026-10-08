import 'package:app_ventas/ui/dialogo_cantidad.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<int? Function()> abrir(WidgetTester tester, {int minimo = 0}) async {
    int? resultado;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => resultado =
              await pedirCantidad(context, actual: 3, minimo: minimo),
          child: const Text('abrir'),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    return () => resultado;
  }

  testWidgets('devuelve el número escrito', (tester) async {
    final resultado = await abrir(tester);
    expect(find.text('3'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('campo_cantidad')), '24');
    await tester.tap(find.byKey(const Key('aceptar_cantidad')));
    await tester.pumpAndSettle();
    expect(resultado(), 24);
  });

  for (final texto in ['', 'abc', '0']) {
    testWidgets('con "$texto" y mínimo 1 muestra error y no cierra',
        (tester) async {
      await abrir(tester, minimo: 1);
      await tester.enterText(find.byKey(const Key('campo_cantidad')), texto);
      await tester.tap(find.byKey(const Key('aceptar_cantidad')));
      await tester.pumpAndSettle();
      expect(find.text('Escribe un número desde 1'), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
    });
  }

  testWidgets('cancelar devuelve null', (tester) async {
    final resultado = await abrir(tester);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(resultado(), isNull);
  });
}
