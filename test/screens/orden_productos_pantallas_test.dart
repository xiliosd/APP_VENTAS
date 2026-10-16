import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/sesion_provider.dart';
import 'package:app_ventas/repositories/producto_repository.dart';
import 'package:app_ventas/repositories/venta_repository.dart';
import 'package:app_ventas/screens/configuracion/productos_screen.dart';
import 'package:app_ventas/screens/venta/registrar_venta_screen.dart';
import 'package:app_ventas/ui/tema_app.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/montaje.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late int pan;
  late int arroz;
  late int name;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    container = await containerConSesion(db);
    final repo = ProductoRepository(db);
    // Creados en este orden: Pan, Ñame, arroz.
    pan = await repo.guardarProducto(nombre: 'Pan', precio: 500);
    name = await repo.guardarProducto(nombre: 'Ñame', precio: 3000);
    arroz = await repo.guardarProducto(nombre: 'arroz', precio: 2500);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> abrir(
    WidgetTester tester,
    Widget pantalla, {
    ThemeData? tema,
    double escala = 1,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      appDePrueba(
        container,
        tema: tema,
        inicio: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(escala)),
            child: pantalla,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Ids en el orden en que se ven (arriba a abajo, izquierda a derecha).
  List<int> enPantalla(WidgetTester tester, String prefijo) {
    final ids = [pan, arroz, name];
    final posiciones = {
      for (final id in ids) id: tester.getTopLeft(find.byKey(Key('$prefijo$id'))),
    };
    return ids..sort((a, b) {
      final dy = posiciones[a]!.dy.compareTo(posiciones[b]!.dy);
      return dy != 0 ? dy : posiciones[a]!.dx.compareTo(posiciones[b]!.dx);
    });
  }

  Future<void> elegir(WidgetTester tester, String boton, String opcion) async {
    await tester.tap(find.byKey(Key(boton)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key(opcion)));
    await tester.pumpAndSettle();
  }

  group('Nueva venta', () {
    testWidgets('arranca en A–Z y cambia a como los creé', (tester) async {
      await abrir(tester, const RegistrarVentaScreen());

      expect(find.byTooltip('Ordenar'), findsOneWidget);
      // La ñ va entre la n y la o: arroz, Ñame, Pan.
      expect(enPantalla(tester, 'producto_'), [arroz, name, pan]);

      await elegir(tester, 'boton_orden_venta', 'orden_creacion');
      expect(enPantalla(tester, 'producto_'), [pan, name, arroz]);
    });

    testWidgets('más vendidos pone primero lo que más sale', (tester) async {
      final ana = container.read(sesionProvider).usuarioActivo!;
      await VentaRepository(db).registrarVenta(
        monto: 6000,
        esFiado: false,
        usuarioId: ana.id,
        fecha: DateTime.now(),
        lineas: [
          LineaNueva(
            productoId: name,
            descripcion: 'Ñame',
            precioUnitario: 3000,
            cantidad: 2,
          ),
        ],
      );
      await abrir(tester, const RegistrarVentaScreen());

      await elegir(tester, 'boton_orden_venta', 'orden_mas_vendidos');

      expect(enPantalla(tester, 'producto_'), [name, arroz, pan]);
    });
  });

  group('Ajustes → Productos', () {
    testWidgets('ordena A–Z o como los creé, sin más vendidos', (
      tester,
    ) async {
      await abrir(tester, const ProductosScreen());
      expect(enPantalla(tester, 'producto_item_'), [arroz, name, pan]);

      await tester.tap(find.byKey(const Key('boton_orden_productos')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('orden_mas_vendidos')), findsNothing);
      await tester.tap(find.byKey(const Key('orden_creacion')));
      await tester.pumpAndSettle();

      expect(enPantalla(tester, 'producto_item_'), [pan, name, arroz]);
    });
  });

  testWidgets('la hoja de orden en oscuro con letra 2,0× no desborda', (
    tester,
  ) async {
    await abrir(
      tester,
      const RegistrarVentaScreen(),
      tema: temaOscuro(),
      escala: 2,
    );
    await tester.tap(find.byKey(const Key('boton_orden_venta')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Más vendidos'), findsOneWidget);
  });
}
