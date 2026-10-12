import 'package:app_ventas/ui/barra_accion_fija.dart';
import 'package:app_ventas/ui/boton_cantidad.dart';
import 'package:app_ventas/ui/colores_app.dart';
import 'package:app_ventas/ui/icono_cuadrado.dart';
import 'package:app_ventas/ui/nivel_existencias.dart';
import 'package:app_ventas/ui/pildora.dart';
import 'package:app_ventas/ui/tema_app.dart';
import 'package:app_ventas/ui/titulo_seccion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget hijo, {ThemeData? tema}) =>
    MaterialApp(theme: tema ?? temaClaro(), home: Scaffold(body: hijo));

void main() {
  group('nivelExistencias', () {
    test('0 o menos es agotado', () {
      expect(nivelExistencias(-1, 5), NivelExistencias.agotado);
      expect(nivelExistencias(0, 5), NivelExistencias.agotado);
      expect(nivelExistencias(0, 0), NivelExistencias.agotado);
    });
    test('hasta el mínimo es bajo', () {
      expect(nivelExistencias(5, 5), NivelExistencias.bajo);
      expect(nivelExistencias(1, 5), NivelExistencias.bajo);
    });
    test('por encima del mínimo es ok', () {
      expect(nivelExistencias(6, 5), NivelExistencias.ok);
      expect(nivelExistencias(1, 0), NivelExistencias.ok);
    });
  });

  group('fraccionNivel', () {
    test('usa pedir hasta como tope', () {
      expect(fraccionNivel(6, 4, 24), closeTo(0.25, 1e-9));
    });
    test('sin pedir hasta usa el doble del mínimo', () {
      expect(fraccionNivel(5, 5, null), closeTo(0.5, 1e-9));
      expect(fraccionNivel(5, 5, 0), closeTo(0.5, 1e-9));
    });
    test('sin mínimo ni pedir hasta la barra va llena', () {
      expect(fraccionNivel(3, 0, null), 1);
    });
    test('sin existencias la barra va vacía', () {
      expect(fraccionNivel(0, 0, null), 0);
      expect(fraccionNivel(-2, 5, 10), 0);
    });
    test('nunca pasa de 1', () {
      expect(fraccionNivel(40, 5, 24), 1);
    });
  });

  testWidgets('Pildora escribe en el color de texto sobre el color al 15 %',
      (tester) async {
    await tester.pumpWidget(
        _app(Pildora(texto: 'Bajo', color: ColoresApp.claro.fiado)));
    final texto = tester.widget<Text>(find.text('Bajo'));
    expect(texto.style!.color, ColoresApp.claro.texto);
  });

  testWidgets('EtiquetaNivel dice Agotado, Bajo u OK', (tester) async {
    await tester.pumpWidget(_app(const Column(children: [
      EtiquetaNivel(nivel: NivelExistencias.agotado),
      EtiquetaNivel(nivel: NivelExistencias.bajo),
      EtiquetaNivel(nivel: NivelExistencias.ok),
    ])));
    expect(find.text('Agotado'), findsOneWidget);
    expect(find.text('Bajo'), findsOneWidget);
    expect(find.text('OK'), findsOneWidget);
  });

  testWidgets('BarraNivel pinta la fracción en el color del nivel',
      (tester) async {
    await tester.pumpWidget(_app(const BarraNivel(
        fraccion: 0.25, nivel: NivelExistencias.bajo)));
    final barra = tester
        .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
    expect(barra.value, 0.25);
    expect(barra.color, ColoresApp.claro.fiado);
  });

  testWidgets('BarraAccionFija muestra el total sobre el botón',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: temaClaro(),
      home: Scaffold(
        body: const SizedBox(),
        bottomNavigationBar: BarraAccionFija(
          total: const Text('Total \$5.000'),
          boton: FilledButton(onPressed: () {}, child: const Text('Guardar')),
        ),
      ),
    ));
    final total = tester.getRect(find.text('Total \$5.000'));
    final boton = tester.getRect(find.text('Guardar'));
    expect(total.bottom, lessThan(boton.top));
  });

  testWidgets('TituloSeccion, IconoCuadrado y BotonCantidad se dibujan',
      (tester) async {
    var toques = 0;
    await tester.pumpWidget(_app(Column(children: [
      const TituloSeccion('TIENDA'),
      IconoCuadrado(icono: Icons.store, color: ColoresApp.claro.entra),
      BotonCantidad(
        key: const Key('mas'),
        icono: Icons.add_rounded,
        tooltip: 'Sumar',
        onPressed: () => toques++,
      ),
    ])));
    expect(find.text('TIENDA'), findsOneWidget);
    expect(find.byIcon(Icons.store), findsOneWidget);
    await tester.tap(find.byKey(const Key('mas')));
    await tester.pumpAndSettle();
    expect(toques, 1);
  });
}
