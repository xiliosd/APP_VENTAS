import 'dart:async';

import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/main.dart';
import 'package:app_ventas/providers/database_provider.dart';
import 'package:app_ventas/providers/sesion_provider.dart';
import 'package:app_ventas/respaldo/respaldo_provider.dart';
import 'package:app_ventas/screens/login/seleccionar_usuario_screen.dart';
import 'package:app_ventas/screens/raiz_app.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<SharedPreferences> abrir(
    WidgetTester tester, {
    Map<String, Object> valores = const {},
    List<Override> overrides = const [],
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(valores);
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          preferenciasProvider.overrideWithValue(prefs),
          ...overrides,
        ],
        child: const AppVentas(),
      ),
    );
    return prefs;
  }

  testWidgets('el primer arranque muestra la versión completa y la recuerda', (
    tester,
  ) async {
    final prefs = await abrir(tester);

    expect(find.byKey(const Key('toldo_marca')), findsOneWidget);
    expect(prefs.getBool('inicio_completo_visto'), isTrue);

    await tester.pumpAndSettle();
    expect(find.byKey(const Key('toldo_marca')), findsNothing);
    expect(find.text('Crear tienda nueva'), findsOneWidget);
  });

  testWidgets('los demás arranques muestran la breve y pasan a ¿Quién eres?', (
    tester,
  ) async {
    await db
        .into(db.usuarios)
        .insert(
          UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'x'),
        );
    await abrir(tester, valores: {'inicio_completo_visto': true});

    await tester.pump(const Duration(milliseconds: 450));
    expect(find.byKey(const Key('insignia_marca')), findsOneWidget);
    expect(find.byType(SeleccionarUsuarioScreen), findsNothing);

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(find.byType(SeleccionarUsuarioScreen), findsOneWidget);
  });

  testWidgets('no vuelve a salir al cambiar la sesión', (tester) async {
    await abrir(tester);
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(RaizApp)),
    );

    container.invalidate(haySesionUsuariosProvider);
    container.read(sesionProvider.notifier).state = const SesionState();
    await tester.pump();

    expect(find.byKey(const Key('toldo_marca')), findsNothing);
  });

  testWidgets('si la consulta tarda, el inicio espera quieto', (tester) async {
    final respuesta = Completer<bool>();
    await abrir(
      tester,
      overrides: [
        haySesionUsuariosProvider.overrideWith((ref) => respuesta.future),
      ],
    );

    await tester.pump(const Duration(seconds: 2));
    expect(find.byKey(const Key('toldo_marca')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    respuesta.complete(false);
    await tester.pumpAndSettle();
    expect(find.text('Crear tienda nueva'), findsOneWidget);
  });
}
