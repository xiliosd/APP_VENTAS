import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/sesion_provider.dart';
import 'package:app_ventas/screens/home/home_screen.dart';
import 'package:drift/native.dart';
import 'package:app_ventas/ui/colores_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/montaje.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<ProviderContainer> montar(WidgetTester tester,
      {String rol = 'admin'}) async {
    final container = await containerConSesion(db, rol: rol);
    addTearDown(container.dispose);
    await tester.pumpWidget(appDePrueba(container, inicio: const HomeScreen()));
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('el admin ve la pestaña Ajustes', (tester) async {
    await montar(tester);
    expect(find.text('Ajustes'), findsOneWidget);
    expect(find.text('Config'), findsNothing);
  });

  testWidgets('el vendedor no ve la pestaña Ajustes', (tester) async {
    await montar(tester, rol: 'vendedor');
    expect(find.text('Ajustes'), findsNothing);
  });

  testWidgets('en Inicio saluda y en otra pestaña muestra su título',
      (tester) async {
    await montar(tester);
    expect(find.descendant(
            of: find.byType(AppBar), matching: find.text('Hola, Ana')),
        findsOneWidget);

    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();
    expect(find.descendant(
            of: find.byType(AppBar), matching: find.text('Ajustes')),
        findsOneWidget);
  });

  testWidgets('cerrar sesión desde el menú de la cuenta', (tester) async {
    final container = await montar(tester);

    await tester.tap(find.byKey(const Key('menu_cuenta')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('boton_cerrar_sesion')));
    await tester.pumpAndSettle();

    expect(container.read(sesionProvider).haySesion, isFalse);
  });

  testWidgets('Ajustes tiene Productos, Usuarios y Cerrar sesión',
      (tester) async {
    final container = await montar(tester);

    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('menu_productos')), findsOneWidget);
    expect(find.byKey(const Key('menu_usuarios')), findsOneWidget);
    expect(find.byKey(const Key('menu_respaldo')), findsOneWidget);

    await tester.tap(find.byKey(const Key('ajustes_cerrar_sesion')));
    await tester.pumpAndSettle();
    expect(container.read(sesionProvider).haySesion, isFalse);
  });

  testWidgets('los íconos de las pestañas se ven oscuros sobre la barra clara',
      (tester) async {
    await montar(tester);

    for (final icono in [
      Icons.people_outline_rounded,
      Icons.receipt_long_outlined,
      Icons.settings_outlined,
    ]) {
      final elemento = tester.element(find.byIcon(icono));
      expect(IconTheme.of(elemento).color!.computeLuminance(), lessThan(0.5),
          reason: 'el ícono $icono debe verse sobre el fondo de la barra');
    }
  });

  testWidgets('tocar Por cobrar en Inicio abre la pestaña Fiado',
      (tester) async {
    await montar(tester);

    await tester.tap(find.byKey(const Key('tarjeta_por_cobrar')));
    await tester.pumpAndSettle();

    expect(find.descendant(
            of: find.byType(AppBar), matching: find.text('Fiado')),
        findsOneWidget);
  });

  testWidgets('el Inicio tiene la barra azul con la insignia; las demás '
      'pestañas, blanca', (tester) async {
    await montar(tester);
    AppBar barra() => tester.widget<AppBar>(find.byType(AppBar).first);

    expect(barra().backgroundColor, ColoresApp.primario);
    expect(barra().foregroundColor, Colors.white);
    expect(find.byKey(const Key('insignia_marca')), findsOneWidget);

    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();
    expect(barra().backgroundColor, isNull);
    expect(find.byKey(const Key('insignia_marca')), findsNothing);
  });

  testWidgets('un nombre largo no desborda la barra azul', (tester) async {
    tester.view.physicalSize = const Size(720, 1560);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final container = await containerConSesion(db,
        nombre: 'María Fernanda de los Ángeles Rodríguez');
    addTearDown(container.dispose);

    await tester.pumpWidget(appDePrueba(container, inicio: const HomeScreen()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
