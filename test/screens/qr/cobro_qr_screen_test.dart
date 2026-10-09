import 'dart:typed_data';

import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/repositories/configuracion_repository.dart';
import 'package:app_ventas/screens/qr/cobro_qr_screen.dart';
import 'package:app_ventas/ui/colores_app.dart';
import 'package:app_ventas/ui/tema_app.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/imagen_prueba.dart';
import '../../support/montaje.dart';

void main() {
  late AppDatabase db;
  final navegador = GlobalKey<NavigatorState>();

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  /// Abre el cobro por $12.000 encima de "Inicio" y guarda lo que devuelve.
  Future<List<bool>> abrir(WidgetTester tester,
      {String rol = 'admin', ThemeData? tema}) async {
    final container = await containerConSesion(db, rol: rol);
    addTearDown(container.dispose);
    await tester.pumpWidget(
        appDePrueba(container, navegador: navegador, tema: tema));
    final resultados = <bool>[];
    abrirCobroQr(navegador.currentContext!, monto: 12000)
        .then(resultados.add);
    await tester.pumpAndSettle();
    return resultados;
  }

  testWidgets('muestra el total, la instrucción y el QR cargado',
      (tester) async {
    await ConfiguracionRepository(db).guardarImagenQr(pngDePrueba);
    await abrir(tester);

    expect(find.text(r'$12.000'), findsOneWidget);
    expect(find.text('Pide al cliente que escanee y digite este valor'),
        findsOneWidget);
    expect(find.byKey(const Key('imagen_qr')), findsOneWidget);
  });

  testWidgets('en modo oscuro el QR sigue sobre fondo blanco y el título se lee',
      (tester) async {
    await ConfiguracionRepository(db).guardarImagenQr(pngDePrueba);
    await abrir(tester, tema: temaOscuro());

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).last);
    expect(scaffold.backgroundColor, ColoresApp.blancoMarca);
    final titulo = tester.widget<Text>(find.text('Cobro por QR'));
    final estilo = DefaultTextStyle.of(tester.element(find.text('Cobro por QR')))
        .style
        .merge(titulo.style);
    expect(estilo.color, ColoresApp.claro.texto);
    final instruccion = tester.widget<Text>(
        find.text('Pide al cliente que escanee y digite este valor'));
    expect(instruccion.style!.color, ColoresApp.claro.textoSecundario);
  });

  testWidgets('Recibido devuelve true y Cancelar devuelve false',
      (tester) async {
    var resultados = await abrir(tester);
    await tester.tap(find.byKey(const Key('boton_qr_recibido')));
    await tester.pumpAndSettle();
    expect(resultados, [true]);

    abrirCobroQr(navegador.currentContext!, monto: 12000)
        .then(resultados.add);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('boton_qr_cancelar')));
    await tester.pumpAndSettle();
    expect(resultados, [true, false]);
  });

  testWidgets('un doble toque en Recibido cierra solo el cobro',
      (tester) async {
    final resultados = await abrir(tester);
    await tester.tap(find.byKey(const Key('boton_qr_recibido')));
    await tester.tap(find.byKey(const Key('boton_qr_recibido')),
        warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(resultados, [true]);
    expect(find.text('Inicio'), findsOneWidget);
  });

  testWidgets('sin QR, el admin ve el aviso y Configurar QR', (tester) async {
    await abrir(tester);
    expect(find.text('Aún no has cargado tu QR'), findsOneWidget);
    expect(find.byKey(const Key('boton_configurar_qr')), findsOneWidget);
    expect(find.byKey(const Key('boton_qr_recibido')), findsOneWidget);
  });

  testWidgets('sin QR, el vendedor no ve Configurar QR', (tester) async {
    await abrir(tester, rol: 'vendedor');
    expect(find.text('Aún no has cargado tu QR'), findsOneWidget);
    expect(find.byKey(const Key('boton_configurar_qr')), findsNothing);
  });

  testWidgets('una imagen dañada muestra un mensaje en vez de fallar',
      (tester) async {
    await ConfiguracionRepository(db)
        .guardarImagenQr(Uint8List.fromList([1, 2, 3]));
    await abrir(tester);
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();

    expect(find.text('No se pudo mostrar el QR'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('en un celular pequeño con letra grande no se desborda',
      (tester) async {
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await ConfiguracionRepository(db).guardarImagenQr(pngDePrueba);

    await abrir(tester);

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('boton_qr_recibido')), findsOneWidget);
  });
}
