import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/repositories/configuracion_repository.dart';
import 'package:app_ventas/screens/ayuda/preguntas_frecuentes.dart';
import 'package:app_ventas/screens/ayuda/preguntas_frecuentes_screen.dart';
import 'package:app_ventas/screens/configuracion/ajustes_screen.dart';
import 'package:app_ventas/screens/home/home_screen.dart';
import 'package:app_ventas/ui/colores_app.dart';
import 'package:app_ventas/ui/tema_app.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/montaje.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await ConfiguracionRepository(db).guardarNombreTienda('La Esquina');
  });
  tearDown(() => db.close());

  test('hay temas de toda la app y ninguno vacío', () {
    expect(temasAyuda.map((t) => t.titulo).toList(), [
      'Ventas',
      'Fiado y clientes',
      'Gastos',
      'Inventario y pedidos',
      'Reportes',
      'Productos y escáner',
      'Cuenta y seguridad',
      'Respaldo',
      'Apariencia',
    ]);
    for (final tema in temasAyuda) {
      expect(
        tema.preguntas.length,
        greaterThanOrEqualTo(2),
        reason: tema.titulo,
      );
      for (final p in tema.preguntas) {
        expect(p.pregunta.trim(), isNotEmpty);
        expect(p.respuesta.trim(), isNotEmpty);
      }
    }
    final preguntas = [
      for (final t in temasAyuda)
        for (final p in t.preguntas) p.pregunta,
    ];
    expect(preguntas.toSet().length, preguntas.length);
  });

  test('Productos y escáner explica Consultar precio', () {
    final tema = temasAyuda.firstWhere(
      (t) => t.titulo == 'Productos y escáner',
    );
    expect(
      tema.preguntas.any((p) => p.respuesta.contains('"Consultar precio"')),
      isTrue,
    );
  });

  Future<void> montarPantalla(
    WidgetTester tester, {
    ThemeData? tema,
    double escala = 1.0,
    Size? tamano,
  }) async {
    if (tamano != null) {
      tester.view.physicalSize = tamano;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }
    await tester.pumpWidget(
      MaterialApp(
        theme: tema ?? temaClaro(),
        builder: (contexto, hijo) => MediaQuery(
          data: MediaQuery.of(contexto)
              .copyWith(textScaler: TextScaler.linear(escala)),
          child: hijo!,
        ),
        home: const PreguntasFrecuentesScreen(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('una pregunta se abre y muestra su respuesta', (tester) async {
    await montarPantalla(tester);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Preguntas frecuentes'),
      ),
      findsOneWidget,
    );
    final primera = temasAyuda.first.preguntas.first;
    expect(find.text(primera.respuesta), findsNothing);

    await tester.tap(find.text(primera.pregunta));
    await tester.pumpAndSettle();
    expect(find.text(primera.respuesta), findsOneWidget);

    await tester.tap(find.text(primera.pregunta));
    await tester.pumpAndSettle();
    expect(find.text(primera.respuesta), findsNothing);
  });

  testWidgets('Ajustes → AYUDA abre Preguntas frecuentes', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final container = await containerConSesion(db);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      appDePrueba(container, inicio: const Scaffold(body: AjustesScreen())),
    );
    await tester.pumpAndSettle();

    final boton = find.byKey(const Key('boton_preguntas_frecuentes'));
    await tester.scrollUntilVisible(boton, 100);
    await tester.ensureVisible(boton);
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: boton, matching: find.text('Preguntas frecuentes')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: boton,
        matching: find.text('Cómo hacer cada cosa en la app'),
      ),
      findsOneWidget,
    );
    // Va debajo de "Ver el recorrido otra vez".
    expect(
      tester.getRect(boton).top,
      greaterThan(
        tester.getRect(find.byKey(const Key('boton_repetir_recorrido'))).top,
      ),
    );

    await tester.tap(boton);
    await tester.pumpAndSettle();
    expect(find.byType(PreguntasFrecuentesScreen), findsOneWidget);
  });

  for (final rol in ['admin', 'vendedor']) {
    testWidgets('el menú de cuenta abre Preguntas frecuentes ($rol)', (
      tester,
    ) async {
      final container = await containerConSesion(db, rol: rol);
      addTearDown(container.dispose);
      await tester.pumpWidget(
        appDePrueba(container, inicio: const HomeScreen()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('menu_cuenta')));
      await tester.pumpAndSettle();
      final item = find.byKey(const Key('menu_preguntas_frecuentes'));
      expect(item, findsOneWidget);
      expect(
        find.descendant(of: item, matching: find.text('Preguntas frecuentes')),
        findsOneWidget,
      );
      // Entre "Apariencia" y "Cerrar sesión".
      final arriba = tester.getRect(find.byKey(const Key('boton_apariencia')));
      final abajo = tester.getRect(
        find.byKey(const Key('boton_cerrar_sesion')),
      );
      expect(tester.getRect(item).top, greaterThanOrEqualTo(arriba.bottom));
      expect(tester.getRect(item).bottom, lessThanOrEqualTo(abajo.top));

      await tester.tap(item);
      await tester.pumpAndSettle();
      expect(find.byType(PreguntasFrecuentesScreen), findsOneWidget);
    });
  }

  testWidgets('a letra 2,0× en 360 dp y en modo oscuro no desborda', (
    tester,
  ) async {
    await montarPantalla(
      tester,
      tema: temaOscuro(),
      escala: 2.0,
      tamano: const Size(360, 640),
    );
    expect(tester.takeException(), isNull);

    // Abre la respuesta más larga y recorre la lista hasta el final.
    final larga = [for (final t in temasAyuda) ...t.preguntas]
        .reduce((a, b) => a.respuesta.length >= b.respuesta.length ? a : b);
    final pregunta = find.text(larga.pregunta);
    await tester.scrollUntilVisible(pregunta, 400, maxScrolls: 100);
    await tester.ensureVisible(pregunta);
    await tester.pumpAndSettle();
    await tester.tap(pregunta);
    await tester.pumpAndSettle();
    expect(find.text(larga.respuesta), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(
      find.text(temasAyuda.last.preguntas.last.pregunta),
      400,
      maxScrolls: 100,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('en modo oscuro la respuesta usa el texto secundario del tema', (
    tester,
  ) async {
    await montarPantalla(tester, tema: temaOscuro());
    final primera = temasAyuda.first.preguntas.first;
    await tester.tap(find.text(primera.pregunta));
    await tester.pumpAndSettle();
    final texto = tester.widget<Text>(find.text(primera.respuesta));
    final contexto = tester.element(find.text(primera.respuesta));
    expect(Theme.of(contexto).brightness, Brightness.dark);
    expect(texto.style?.color, ColoresApp.of(contexto).textoSecundario);
  });
}
