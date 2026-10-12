import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/sesion_provider.dart';
import 'package:app_ventas/repositories/configuracion_repository.dart';
import 'package:app_ventas/screens/configuracion/ajustes_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/montaje.dart';
import '../../support/respaldo_prueba.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> montar(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final container = await containerConSesion(db);
    addTearDown(container.dispose);
    await tester.pumpWidget(appDePrueba(container,
        inicio: const Scaffold(body: AjustesScreen())));
    await tester.pumpAndSettle();
  }

  testWidgets('la cabecera muestra la tienda y quién usa la app',
      (tester) async {
    await ConfiguracionRepository(db).guardarNombreTienda('La Esquina');
    await montar(tester);
    final cabecera = find.byKey(const Key('cabecera_ajustes'));
    expect(cabecera, findsOneWidget);
    expect(find.descendant(of: cabecera, matching: find.text('La Esquina')),
        findsOneWidget);
    expect(
        find.descendant(
            of: cabecera, matching: find.text('Ana · Administrador')),
        findsOneWidget);
  });

  testWidgets('sin nombre guardado dice "Sin nombre"', (tester) async {
    await montar(tester);
    expect(
        find.descendant(
            of: find.byKey(const Key('cabecera_ajustes')),
            matching: find.text('Sin nombre')),
        findsOneWidget);
  });

  testWidgets('el menú va en grupos con su ícono', (tester) async {
    await montar(tester);
    expect(find.text('TIENDA'), findsOneWidget);
    expect(find.text('COBROS Y DATOS'), findsOneWidget);
    expect(find.text('AYUDA'), findsOneWidget);
    expect(find.text('CUENTA'), findsOneWidget);
    for (final clave in [
      'menu_productos',
      'menu_proveedores',
      'menu_usuarios',
      'menu_cobro_qr',
      'menu_respaldo',
    ]) {
      await tester.scrollUntilVisible(find.byKey(Key(clave)), 100);
      expect(find.byKey(Key(clave)), findsOneWidget);
    }
    expect(find.byKey(const Key('estado_respaldo_menu')), findsNothing);
  });

  testWidgets('con el respaldo activo la fila dice "Activo"', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final container = await containerRespaldo(
        db, NubeRespaldoFalsa(conSesion: true, telefono: '+573001234567'));
    addTearDown(container.dispose);
    final ana = await db.into(db.usuarios).insert(
        UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'x'));
    container.read(sesionProvider.notifier).state = SesionState(
        usuarioActivo: await (db.select(db.usuarios)
              ..where((u) => u.id.equals(ana)))
            .getSingle());
    await tester.pumpWidget(appDePrueba(container,
        inicio: const Scaffold(body: AjustesScreen())));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.byKey(const Key('menu_respaldo')), 100);
    expect(find.byKey(const Key('estado_respaldo_menu')), findsOneWidget);
    expect(find.text('Activo'), findsOneWidget);
  });
}
