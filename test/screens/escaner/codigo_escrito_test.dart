import 'package:app_ventas/screens/escaner/escaner_screen.dart';
import 'package:app_ventas/ui/tema_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<String?> abrir(WidgetTester tester, String escrito) async {
    String? resultado;
    await tester.pumpWidget(MaterialApp(
      theme: temaClaro(),
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => resultado = await pedirCodigoEscrito(context),
          child: const Text('abrir'),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('campo_codigo_escrito')), escrito);
    await tester.tap(find.byKey(const Key('boton_usar_codigo')));
    await tester.pumpAndSettle();
    return resultado;
  }

  testWidgets('escribir un código lo devuelve recortado', (tester) async {
    expect(await abrir(tester, ' 7702004003508 '), '7702004003508');
  });

  testWidgets('vacío no devuelve nada', (tester) async {
    expect(await abrir(tester, '   '), isNull);
  });
}
