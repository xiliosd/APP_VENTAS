import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/repositories/configuracion_repository.dart';
import 'package:app_ventas/screens/configuracion/ajustes_screen.dart';
import 'package:app_ventas/screens/home/home_screen.dart';
import 'package:app_ventas/screens/login/ingresar_pin_screen.dart';
import 'package:app_ventas/screens/login/seleccionar_usuario_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/montaje.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> conNombre() =>
      ConfiguracionRepository(db).guardarNombreTienda('La Esquina');

  Future<void> montar(WidgetTester tester, Widget inicio,
      {String rol = 'admin'}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final container = await containerConSesion(db, rol: rol);
    addTearDown(container.dispose);
    await tester.pumpWidget(appDePrueba(container, inicio: inicio));
    await tester.pumpAndSettle();
  }

  testWidgets('el nombre se ve al elegir usuario', (tester) async {
    await conNombre();
    await montar(tester, const SeleccionarUsuarioScreen());
    expect(find.text('La Esquina'), findsOneWidget);
  });

  testWidgets('el nombre se ve al ingresar el PIN', (tester) async {
    await conNombre();
    const usuario = Usuario(id: 99, nombre: 'Beto', rol: 'vendedor', pinHash: 'x');
    await montar(tester, const IngresarPinScreen(usuario: usuario));
    expect(find.text('La Esquina'), findsOneWidget);
  });

  testWidgets('el nombre se ve en el encabezado de Inicio', (tester) async {
    await conNombre();
    await montar(tester, const HomeScreen());
    expect(
        find.descendant(
            of: find.byType(AppBar), matching: find.text('La Esquina')),
        findsOneWidget);
  });

  testWidgets('en Ajustes el administrador cambia el nombre', (tester) async {
    await conNombre();
    await montar(tester, const Scaffold(body: AjustesScreen()));

    await tester.tap(find.byKey(const Key('menu_nombre_tienda')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('campo_nombre_tienda_hoja')), 'Donde Rosa');
    await tester.tap(find.byKey(const Key('boton_guardar_nombre_tienda')));
    await tester.pumpAndSettle();

    expect(await ConfiguracionRepository(db).nombreTienda(), 'Donde Rosa');
    expect(find.text('Nombre guardado'), findsOneWidget);
    expect(find.text('Donde Rosa'), findsOneWidget);
  });

  testWidgets('un nombre vacío en la hoja muestra el error', (tester) async {
    await conNombre();
    await montar(tester, const Scaffold(body: AjustesScreen()));

    await tester.tap(find.byKey(const Key('menu_nombre_tienda')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('campo_nombre_tienda_hoja')), '  ');
    await tester.tap(find.byKey(const Key('boton_guardar_nombre_tienda')));
    await tester.pumpAndSettle();

    expect(find.text('Escribe el nombre de tu tienda'), findsOneWidget);
    expect(await ConfiguracionRepository(db).nombreTienda(), 'La Esquina');
  });

  testWidgets(
      'al administrador sin nombre se le pide y no puede cerrar la hoja',
      (tester) async {
    await montar(tester, const HomeScreen());

    expect(find.text('¿Cómo se llama tu tienda?'), findsOneWidget);
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    expect(find.text('¿Cómo se llama tu tienda?'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('¿Cómo se llama tu tienda?'), findsOneWidget);

    await tester.enterText(
        find.byKey(const Key('campo_nombre_tienda_hoja')), 'La Esquina');
    await tester.tap(find.byKey(const Key('boton_guardar_nombre_tienda')));
    await tester.pumpAndSettle();

    expect(find.text('¿Cómo se llama tu tienda?'), findsNothing);
    expect(await ConfiguracionRepository(db).nombreTienda(), 'La Esquina');
  });

  testWidgets('al vendedor sin nombre no se le pide', (tester) async {
    await montar(tester, const HomeScreen(), rol: 'vendedor');
    expect(find.text('¿Cómo se llama tu tienda?'), findsNothing);
  });
}
