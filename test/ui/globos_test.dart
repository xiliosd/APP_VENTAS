import 'package:app_ventas/ui/recorrido/globos.dart';
import 'package:app_ventas/ui/recorrido/objetivo_recorrido.dart';
import 'package:app_ventas/ui/tema_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late int toquesA;
  late BuildContext contexto;

  Future<void> montar(WidgetTester tester, {ThemeData? tema, double letra = 1}) async {
    toquesA = 0;
    await tester.pumpWidget(MaterialApp(
      theme: tema ?? temaClaro(),
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(letra)),
        child: Scaffold(
          body: Builder(builder: (c) {
            contexto = c;
            return Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ObjetivoRecorrido(
                  id: 'a',
                  child: ElevatedButton(
                      onPressed: () => toquesA++, child: const Text('A')),
                ),
                const ObjetivoRecorrido(id: 'b', child: Text('B')),
              ],
            );
          }),
        ),
      ),
    ));
  }

  testWidgets('informativos: Siguiente avanza y Terminar cierra', (tester) async {
    await montar(tester);
    var terminado = false;
    final ctrl = mostrarGlobos(contexto, const [
      PasoGlobo(objetivos: ['a'], texto: 'Este es A'),
      PasoGlobo(objetivos: ['b'], texto: 'Este es B'),
    ], onTerminar: () => terminado = true);
    await tester.pumpAndSettle();
    expect(find.text('Este es A'), findsOneWidget);
    await tester.tap(find.byKey(const Key('boton_siguiente_globo')));
    await tester.pumpAndSettle();
    expect(find.text('Este es B'), findsOneWidget);
    expect(find.text('Terminar'), findsOneWidget);
    await tester.tap(find.byKey(const Key('boton_siguiente_globo')));
    await tester.pumpAndSettle();
    expect(terminado, isTrue);
    expect(ctrl.activo, isFalse);
    expect(find.byKey(const Key('capa_globos')), findsNothing);
  });

  testWidgets('informativo: tocar dentro del hueco no llega al objetivo',
      (tester) async {
    await montar(tester);
    mostrarGlobos(contexto, const [PasoGlobo(objetivos: ['a'], texto: 'A')]);
    await tester.pumpAndSettle();
    await tester.tapAt(tester.getCenter(find.text('A').first));
    await tester.pumpAndSettle();
    expect(toquesA, 0);
  });

  testWidgets('de acción: el toque en el hueco llega; fuera no hace nada',
      (tester) async {
    await montar(tester);
    final ctrl = mostrarGlobos(contexto, const [
      PasoGlobo(objetivos: ['a'], texto: 'Toca A', deAccion: true),
      PasoGlobo(objetivos: ['b'], texto: 'Mira B'),
    ]);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('boton_siguiente_globo')), findsNothing);
    await tester.tapAt(const Offset(780, 300)); // fuera del hueco y de la burbuja
    await tester.pumpAndSettle();
    expect(toquesA, 0);
    await tester.tapAt(tester.getCenter(find.widgetWithText(ElevatedButton, 'A')));
    await tester.pumpAndSettle();
    expect(toquesA, 1);
    ctrl.avanzar(); // la pantalla avisa que se hizo la acción
    await tester.pumpAndSettle();
    expect(find.text('Mira B'), findsOneWidget);
  });

  testWidgets('usa la alternativa y salta pasos sin objetivo', (tester) async {
    await montar(tester);
    var terminado = false;
    mostrarGlobos(contexto, const [
      PasoGlobo(objetivos: ['x', 'b'], texto: 'Alternativa B'),
      PasoGlobo(objetivos: ['z'], texto: 'Nunca'),
    ], onTerminar: () => terminado = true);
    await tester.pumpAndSettle();
    expect(find.text('Alternativa B'), findsOneWidget);
    await tester.tap(find.byKey(const Key('boton_siguiente_globo')));
    await tester.pumpAndSettle();
    expect(find.text('Nunca'), findsNothing);
    expect(terminado, isTrue);
  });

  testWidgets('Saltar recorrido llama onSaltar y quita la capa', (tester) async {
    await montar(tester);
    var saltado = false;
    mostrarGlobos(contexto, const [PasoGlobo(objetivos: ['a'], texto: 'A')],
        onSaltar: () => saltado = true);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('boton_saltar_recorrido')));
    await tester.pumpAndSettle();
    expect(saltado, isTrue);
    expect(find.byKey(const Key('capa_globos')), findsNothing);
  });

  testWidgets('irA vuelve a un paso anterior', (tester) async {
    await montar(tester);
    final ctrl = mostrarGlobos(contexto, const [
      PasoGlobo(objetivos: ['a'], texto: 'Uno'),
      PasoGlobo(objetivos: ['b'], texto: 'Dos'),
    ]);
    await tester.pumpAndSettle();
    ctrl.avanzar();
    await tester.pumpAndSettle();
    ctrl.irA(0);
    await tester.pumpAndSettle();
    expect(find.text('Uno'), findsOneWidget);
    expect(ctrl.indice, 0);
  });

  testWidgets('oscuro y letra grande sin excepciones', (tester) async {
    await montar(tester, tema: temaOscuro(), letra: 1.6);
    mostrarGlobos(contexto, const [
      PasoGlobo(objetivos: ['b'], texto: 'Un texto largo para ver cómo se acomoda la burbuja con letra grande'),
    ]);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
