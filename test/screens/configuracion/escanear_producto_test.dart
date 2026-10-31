import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/screens/configuracion/producto_screen.dart';
import 'package:app_ventas/screens/escaner/consejos_escaner.dart';
import 'package:app_ventas/servicios/lector_codigo.dart';
import 'package:app_ventas/servicios/open_food_facts.dart';
import 'package:app_ventas/ui/boton_escanear.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/lector_falso.dart';
import '../../support/montaje.dart';

class _SinDatos implements ConsultaProducto {
  @override
  Future<DatosProducto?> buscar(String codigo) async => null;
}

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late LectorFalso lector;
  late SharedPreferences preferencias;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> abrir(
    WidgetTester tester, {
    Producto? producto,
    bool consejoVisto = false,
    List<String> codigos = const [],
  }) async {
    SharedPreferences.setMockInitialValues({
      if (consejoVisto) ...consejosVistos,
    });
    preferencias = await SharedPreferences.getInstance();
    lector = LectorFalso(codigos);
    container = await containerConSesion(
      db,
      preferencias: preferencias,
      overrides: [
        lectorCodigoProvider.overrideWithValue(lector),
        consultaProductoProvider.overrideWithValue(_SinDatos()),
      ],
    );
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      appDePrueba(container, inicio: ProductoScreen(producto: producto)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'crear producto muestra Escanear código bajo el campo de código',
    (tester) async {
      await abrir(tester, consejoVisto: true);
      expect(
        find.widgetWithText(BotonEscanear, 'Escanear código'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('boton_escanear_producto')), findsOneWidget);
      final campo = tester.getBottomLeft(
        find.byKey(const Key('campo_codigo_producto')),
      );
      final boton = tester.getTopLeft(
        find.byKey(const Key('boton_escanear_producto')),
      );
      expect(boton.dy, greaterThanOrEqualTo(campo.dy));
    },
  );

  testWidgets('al crear, la primera vez muestra el consejo de crear', (
    tester,
  ) async {
    await abrir(tester);
    expect(find.text(consejoEscanearProducto.texto), findsOneWidget);
    expect(preferencias.getBool('consejo_visto_escanearProducto'), isNull);

    await tester.tap(find.byKey(const Key('boton_entendido_consejo')));
    await tester.pumpAndSettle();
    expect(preferencias.getBool('consejo_visto_escanearProducto'), isTrue);
  });

  testWidgets('salir sin cerrar el consejo lo deja pendiente', (tester) async {
    await abrir(tester);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(preferencias.getBool('consejo_visto_escanearProducto'), isNull);
  });

  testWidgets('al editar no muestra el consejo', (tester) async {
    final id = await db
        .into(db.productos)
        .insert(ProductosCompanion.insert(nombre: 'Pan', precio: 500));
    final producto = await (db.select(
      db.productos,
    )..where((t) => t.id.equals(id))).getSingle();
    await abrir(tester, producto: producto);
    expect(find.byKey(const Key('capa_globos')), findsNothing);
  });

  testWidgets('escanear usa UsoEscaner.producto y llena el código', (
    tester,
  ) async {
    await abrir(tester, codigos: ['7702004003508']);
    await tester.tap(find.byKey(const Key('boton_escanear_producto')));
    await tester.pumpAndSettle();
    final campo = tester.widget<TextField>(
      find.byKey(const Key('campo_codigo_producto')),
    );
    expect(campo.controller!.text, '7702004003508');
    expect(lector.usos, [UsoEscaner.producto]);
    expect(find.byKey(const Key('capa_globos')), findsNothing);
  });
}
