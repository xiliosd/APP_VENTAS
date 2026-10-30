import 'package:app_ventas/screens/escaner/escaner_screen.dart';
import 'package:app_ventas/servicios/lector_codigo.dart';
import 'package:app_ventas/ui/colores_app.dart';
import 'package:app_ventas/ui/tema_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _montar(
  WidgetTester tester,
  UsoEscaner uso, {
  VoidCallback? alSeguirSinCamara,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: temaClaro(),
      home: Scaffold(
        body: PieEscaner(
          uso: uso,
          onEscribir: () {},
          onSeguirSinCamara: alSeguirSinCamara ?? () {},
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('venta muestra la ayuda de venta y no Seguir sin cámara', (
    tester,
  ) async {
    await _montar(tester, UsoEscaner.venta);
    expect(
      find.text(
        'Si el código no existe, te ofrezco crearlo; si existe, lo sumo a la venta',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('boton_seguir_sin_camara')), findsNothing);
    expect(find.byKey(const Key('boton_escribir_codigo')), findsOneWidget);
  });

  testWidgets('producto muestra lo lleno por ti', (tester) async {
    await _montar(tester, UsoEscaner.producto);
    expect(find.text('Si conozco el código, lo lleno por ti'), findsOneWidget);
  });

  testWidgets('práctica ofrece Seguir sin cámara y lo avisa al tocar', (
    tester,
  ) async {
    var avisos = 0;
    await _montar(
      tester,
      UsoEscaner.practica,
      alSeguirSinCamara: () => avisos++,
    );
    expect(find.text('Seguir sin cámara'), findsOneWidget);
    await tester.tap(find.byKey(const Key('boton_seguir_sin_camara')));
    expect(avisos, 1);
  });

  testWidgets('el texto de ayuda va sobre un fondo velo para el contraste', (
    tester,
  ) async {
    await _montar(tester, UsoEscaner.practica);
    final fondo = tester.widget<DecoratedBox>(
      find.ancestor(
        of: find.text('Apunta al código de barras'),
        matching: find.byKey(const Key('fondo_pie_escaner')),
      ),
    );
    final contexto = tester.element(find.byType(PieEscaner));
    expect(
      (fondo.decoration as BoxDecoration).color,
      ColoresApp.of(contexto).velo,
    );
  });

  testWidgets('los objetivos táctiles miden al menos 48', (tester) async {
    await _montar(tester, UsoEscaner.practica);
    final tamano = tester.getSize(
      find.byKey(const Key('boton_seguir_sin_camara')),
    );
    expect(tamano.height, greaterThanOrEqualTo(48));
  });
}
