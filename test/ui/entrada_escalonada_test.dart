import 'package:app_ventas/ui/entrada_escalonada.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('aparece una sola vez aunque se reconstruya', (tester) async {
    Widget arbol(String texto) =>
        MaterialApp(home: EntradaEscalonada(indice: 0, child: Text(texto)));
    await tester.pumpWidget(arbol('a'));
    final opacidad = tester
        .widget<Opacity>(find
            .ancestor(of: find.text('a'), matching: find.byType(Opacity))
            .first)
        .opacity;
    expect(opacidad, lessThan(1));
    await tester.pumpAndSettle();
    expect(find.text('a'), findsOneWidget);

    await tester.pumpWidget(arbol('a')); // reconstrucción por dato nuevo
    await tester.pump();
    expect(find.byType(Opacity), findsNothing); // ya no se anima de nuevo
  });

  testWidgets('con reducir movimiento se ve completo desde el inicio',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: EntradaEscalonada(indice: 3, child: Text('b')))));
    expect(find.byType(Opacity), findsNothing);
    expect(find.text('b'), findsOneWidget);
  });
}
