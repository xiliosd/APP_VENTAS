import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/apariencia_provider.dart';
import 'package:app_ventas/repositories/configuracion_repository.dart';
import 'package:app_ventas/respaldo/respaldo_provider.dart';
import 'package:app_ventas/screens/home/home_screen.dart';
import 'package:app_ventas/ui/tema_app.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/montaje.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await ConfiguracionRepository(db).guardarNombreTienda('La Esquina');
  });
  tearDown(() => db.close());

  /// Monta el Inicio con la apariencia conectada como en `AppVentas`.
  Future<ProviderContainer> montar(WidgetTester tester,
      {String rol = 'admin'}) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = await containerConSesion(db,
        rol: rol,
        overrides: [preferenciasProvider.overrideWithValue(prefs)]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: Consumer(
        builder: (context, ref, _) => MaterialApp(
          theme: temaClaro(),
          darkTheme: temaOscuro(),
          themeMode: ref.watch(aparienciaProvider),
          home: const HomeScreen(),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('desde el menú de la cuenta se elige el modo oscuro',
      (tester) async {
    final container = await montar(tester);

    await tester.tap(find.byKey(const Key('menu_cuenta')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('boton_apariencia')));
    await tester.pumpAndSettle();
    expect(find.text('Automático'), findsOneWidget);
    expect(find.text('Claro'), findsOneWidget);
    await tester.tap(find.text('Oscuro'));
    await tester.pumpAndSettle();

    final contexto = tester.element(find.byType(HomeScreen));
    expect(Theme.of(contexto).brightness, Brightness.dark);
    expect(container.read(aparienciaProvider), ThemeMode.dark);
  });

  testWidgets('un vendedor también ve Apariencia', (tester) async {
    await montar(tester, rol: 'vendedor');

    await tester.tap(find.byKey(const Key('menu_cuenta')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('boton_apariencia')), findsOneWidget);
  });
}
