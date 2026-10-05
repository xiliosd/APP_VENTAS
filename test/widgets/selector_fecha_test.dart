import 'package:app_ventas/util/fecha_util.dart';
import 'package:app_ventas/widgets/selector_fecha.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DateTime dia;

  Widget harness() {
    return MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => SelectorFecha(
            dia: dia,
            onCambio: (nuevo) => setState(() => dia = nuevo),
          ),
        ),
      ),
    );
  }

  setUp(() => dia = inicioDelDia(DateTime.now()));

  testWidgets('muestra Hoy y deshabilita la flecha siguiente en hoy',
      (tester) async {
    await tester.pumpWidget(harness());

    expect(find.text('Hoy'), findsOneWidget);
    final siguiente =
        tester.widget<IconButton>(find.byKey(const Key('boton_dia_siguiente')));
    expect(siguiente.onPressed, isNull);
  });

  testWidgets('ir al día anterior y volver regresa exactamente a Hoy',
      (tester) async {
    await tester.pumpWidget(harness());
    final hoy = inicioDelDia(DateTime.now());
    final ayer = DateTime(hoy.year, hoy.month, hoy.day - 1);

    await tester.tap(find.byKey(const Key('boton_dia_anterior')));
    await tester.pump();

    expect(dia, ayer);
    expect(find.text(formatoFecha(ayer)), findsOneWidget);

    await tester.tap(find.byKey(const Key('boton_dia_siguiente')));
    await tester.pump();

    expect(dia, hoy);
    expect(find.text('Hoy'), findsOneWidget);
  });
}
