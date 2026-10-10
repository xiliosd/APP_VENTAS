import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/recorrido_provider.dart';
import 'package:app_ventas/repositories/configuracion_repository.dart';
import 'package:app_ventas/screens/home/home_screen.dart';
import 'package:app_ventas/screens/recorrido/paso_productos_screen.dart';
import 'package:app_ventas/screens/recorrido/paso_venta_screen.dart';
import 'package:app_ventas/screens/venta/registrar_venta_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/montaje.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await ConfiguracionRepository(db).guardarNombreTienda('La Esquina');
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> montar(WidgetTester tester,
      {required String? paso, String rol = 'admin'}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(
        paso == null ? {} : {'recorrido_paso': paso});
    final prefs = await SharedPreferences.getInstance();
    container = await containerConSesion(db,
        rol: rol, preferencias: prefs);
    await tester.pumpWidget(appDePrueba(container, inicio: const HomeScreen()));
    await tester.pumpAndSettle();
  }

  testWidgets('con paso productos el Inicio abre el paso 2 una sola vez',
      (tester) async {
    await montar(tester, paso: 'productos');
    expect(find.byType(PasoProductosScreen), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.byType(PasoProductosScreen), findsOneWidget);
  });

  testWidgets('con paso venta el Inicio abre el paso 3', (tester) async {
    await montar(tester, paso: 'venta');
    expect(find.byType(PasoVentaScreen), findsOneWidget);
  });

  testWidgets('globos del Inicio y ¡Listo!', (tester) async {
    await montar(tester, paso: 'inicio');
    expect(find.text('Aquí ves cuánto vendiste hoy y cómo vas frente a ayer.'),
        findsOneWidget);
    // "+ Venta" dentro del hueco no navega en un globo informativo.
    await tester
        .tapAt(tester.getCenter(find.byKey(const Key('boton_nueva_venta'))));
    await tester.pumpAndSettle();
    expect(find.byType(RegistrarVentaScreen), findsNothing);
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byKey(const Key('boton_siguiente_globo')));
      await tester.pumpAndSettle();
    }
    expect(find.byKey(const Key('hoja_listo')), findsOneWidget);
    expect(container.read(recorridoProvider), PasoRecorrido.hecho);
    await tester.tap(find.byKey(const Key('boton_empezar_a_vender')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('hoja_listo')), findsNothing);
  });

  testWidgets('Saltar recorrido en el Inicio lo deja hecho', (tester) async {
    await montar(tester, paso: 'inicio');
    await tester.tap(find.byKey(const Key('boton_saltar_recorrido')));
    await tester.pumpAndSettle();
    expect(container.read(recorridoProvider), PasoRecorrido.hecho);
    expect(find.byKey(const Key('capa_globos')), findsNothing);
    expect(find.byKey(const Key('hoja_listo')), findsNothing);
  });

  testWidgets('un vendedor no ve el recorrido pendiente', (tester) async {
    await montar(tester, paso: 'productos', rol: 'vendedor');
    expect(find.byType(PasoProductosScreen), findsNothing);
    expect(find.byKey(const Key('capa_globos')), findsNothing);
  });

  testWidgets('sin recorrido (instalación previa) no pasa nada',
      (tester) async {
    await montar(tester, paso: null);
    expect(find.byKey(const Key('capa_globos')), findsNothing);
    expect(find.byType(PasoProductosScreen), findsNothing);
  });

  testWidgets('Ver el recorrido otra vez abre la práctica sin recrear nada',
      (tester) async {
    await montar(tester, paso: 'hecho');
    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.byKey(const Key('boton_repetir_recorrido')), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byKey(const Key('boton_repetir_recorrido')));
    await tester.pumpAndSettle();
    expect(find.byType(PasoVentaScreen), findsOneWidget);
    expect(container.read(recorridoProvider), PasoRecorrido.venta);
    expect(await db.select(db.usuarios).get(), hasLength(1));
  });

  testWidgets('tras salir con atrás del paso 3, repetir el recorrido lo abre',
      (tester) async {
    await montar(tester, paso: 'venta');
    expect(find.byType(PasoVentaScreen), findsOneWidget);
    await tester.binding.handlePopRoute(); // botón atrás de Android
    await tester.pumpAndSettle();
    expect(find.byType(PasoVentaScreen), findsNothing);
    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.byKey(const Key('boton_repetir_recorrido')), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byKey(const Key('boton_repetir_recorrido')));
    await tester.pumpAndSettle();
    expect(find.byType(PasoVentaScreen), findsOneWidget);
  });
}
