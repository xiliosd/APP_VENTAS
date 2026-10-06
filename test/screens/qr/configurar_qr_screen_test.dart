import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/repositories/configuracion_repository.dart';
import 'package:app_ventas/screens/configuracion/ajustes_screen.dart';
import 'package:app_ventas/screens/qr/configurar_qr_screen.dart';
import 'package:app_ventas/screens/qr/selector_imagen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/imagen_prueba.dart';
import '../../support/montaje.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> montar(WidgetTester tester, SelectorImagen selector,
      {Widget inicio = const ConfigurarQrScreen()}) async {
    final container = await containerConSesion(db,
        overrides: [selectorImagenProvider.overrideWithValue(selector)]);
    addTearDown(container.dispose);
    await tester.pumpWidget(appDePrueba(container, inicio: inicio));
    await tester.pumpAndSettle();
  }

  testWidgets('sin QR muestra la ayuda y Cargar QR lo guarda',
      (tester) async {
    await montar(tester, SelectorImagenFalso(bytes: pngDePrueba));
    expect(
        find.text('Descarga tu QR desde la app de Nequi, Daviplata o tu '
            'banco y cárgalo aquí.'),
        findsOneWidget);
    expect(find.text('Aún no has cargado tu QR'), findsOneWidget);

    await tester.tap(find.byKey(const Key('boton_cargar_qr')));
    await tester.pumpAndSettle();

    expect(await ConfiguracionRepository(db).imagenQr(), pngDePrueba);
    expect(find.byKey(const Key('vista_qr')), findsOneWidget);
    expect(find.text('Cambiar QR'), findsOneWidget);
  });

  testWidgets('si no se elige imagen no cambia nada', (tester) async {
    await montar(tester, SelectorImagenFalso());
    await tester.tap(find.byKey(const Key('boton_cargar_qr')));
    await tester.pumpAndSettle();
    expect(await ConfiguracionRepository(db).imagenQr(), isNull);
  });

  testWidgets('si falla la lectura avisa y no guarda', (tester) async {
    await montar(tester, SelectorImagenFalso(error: Exception('x')));
    await tester.tap(find.byKey(const Key('boton_cargar_qr')));
    await tester.pumpAndSettle();
    expect(find.text('No se pudo cargar la imagen, prueba con otra'),
        findsOneWidget);
    expect(await ConfiguracionRepository(db).imagenQr(), isNull);
  });

  testWidgets('Quitar QR lo borra', (tester) async {
    await ConfiguracionRepository(db).guardarImagenQr(pngDePrueba);
    await montar(tester, SelectorImagenFalso());
    await tester.tap(find.byKey(const Key('boton_quitar_qr')));
    await tester.pumpAndSettle();
    expect(await ConfiguracionRepository(db).imagenQr(), isNull);
    expect(find.text('Aún no has cargado tu QR'), findsOneWidget);
  });

  testWidgets('Ajustes tiene la entrada Cobro por QR', (tester) async {
    await montar(tester, SelectorImagenFalso(),
        inicio: const Scaffold(body: AjustesScreen()));
    await tester.tap(find.byKey(const Key('menu_cobro_qr')));
    await tester.pumpAndSettle();
    expect(find.byType(ConfigurarQrScreen), findsOneWidget);
  });
}
