import 'package:app_ventas/ui/avisos.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('avisar con acción muestra la etiqueta y la ejecuta', (
    tester,
  ) async {
    var ejecutada = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => avisar(
                context,
                'Gaseosa agregado',
                etiquetaAccion: 'Editar',
                onAccion: () => ejecutada++,
              ),
              child: const Text('mostrar'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('mostrar'));
    await tester.pumpAndSettle();
    expect(find.text('Gaseosa agregado'), findsOneWidget);
    expect(find.text('Editar'), findsOneWidget);
    await tester.tap(find.text('Editar'));
    expect(ejecutada, 1);
  });
}
