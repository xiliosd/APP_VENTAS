import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/database_provider.dart';
import 'package:app_ventas/screens/login/seleccionar_usuario_screen.dart';
import 'package:app_ventas/ui/tema_app.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  /// Crea los usuarios (el primero admin, el resto vendedores) y abre la
  /// pantalla. Devuelve los ids en el mismo orden.
  Future<List<int>> montar(WidgetTester tester, List<String> nombres) async {
    final ids = <int>[];
    for (var i = 0; i < nombres.length; i++) {
      ids.add(await db.into(db.usuarios).insert(UsuariosCompanion.insert(
          nombre: nombres[i],
          rol: i == 0 ? 'admin' : 'vendedor',
          pinHash: 'x')));
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
            theme: temaClaro(), home: const SeleccionarUsuarioScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return ids;
  }

  testWidgets('muestra la marca, cada usuario con su inicial y su rol',
      (tester) async {
    await montar(tester, ['Ana', 'Beto']);

    expect(find.text('VeciTienda'), findsOneWidget);
    expect(find.byKey(const Key('isotipo_marca')), findsOneWidget);
    expect(find.text('¿Quién eres?'), findsOneWidget);
    expect(find.text('Administrador'), findsOneWidget);
    expect(find.text('Vendedor'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
  });

  testWidgets('dos usuarios van en 2 columnas', (tester) async {
    final ids = await montar(tester, ['Ana', 'Beto']);
    final ana = tester.getRect(find.byKey(Key('usuario_${ids[0]}')));
    final beto = tester.getRect(find.byKey(Key('usuario_${ids[1]}')));
    expect(ana.top, beto.top);
    expect(ana.left, lessThan(beto.left));
  });

  testWidgets('con un solo usuario la tarjeta ocupa el ancho', (tester) async {
    final ids = await montar(tester, ['Ana']);
    final ancho = tester.getSize(find.byKey(Key('usuario_${ids[0]}'))).width;
    final pantalla = tester.getSize(find.byType(Scaffold)).width;
    expect(ancho, greaterThan(pantalla * 0.8));
  });

  testWidgets('con letra grande no se desborda', (tester) async {
    tester.view.physicalSize = const Size(720, 1560);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await montar(tester, ['María Fernanda de los Ángeles', 'Beto']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tocar una tarjeta abre el PIN con el avatar animado',
      (tester) async {
    final ids = await montar(tester, ['Ana']);
    expect(find.byType(Hero), findsOneWidget);
    await tester.tap(find.byKey(Key('usuario_${ids[0]}')));
    await tester.pumpAndSettle();
    expect(find.text('Hola, Ana'), findsOneWidget);
  });
}
