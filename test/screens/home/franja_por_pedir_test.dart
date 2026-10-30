import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/aviso_por_pedir_provider.dart';
import 'package:app_ventas/repositories/inventario_repository.dart';
import 'package:app_ventas/repositories/producto_repository.dart';
import 'package:app_ventas/screens/home/home_screen.dart';
import 'package:app_ventas/ui/tema_app.dart';
import 'package:app_ventas/util/aviso_existencias.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/montaje.dart';

const _avisoCoca = AvisoExistencias(
  productoId: 1,
  nombre: 'Coca',
  existencias: 2,
  minimo: 6,
);
const _avisoLeche = AvisoExistencias(
  productoId: 2,
  nombre: 'Leche',
  existencias: 0,
  minimo: 3,
);

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  /// Crea [cuantos] productos por debajo de su mínimo.
  Future<void> sembrarPorPedir(int cuantos) async {
    final usuario = await db.select(db.usuarios).getSingle();
    final productos = ProductoRepository(db);
    final inventario = InventarioRepository(db);
    for (var i = 0; i < cuantos; i++) {
      final id = await productos.guardarProducto(
        nombre: 'Producto $i',
        precio: 1000,
      );
      await inventario.activarControl(id, cantidad: 1, minimo: 5, por: usuario);
    }
  }

  Future<void> montar(
    WidgetTester tester, {
    String rol = 'vendedor',
    int porPedir = 0,
    double escala = 1.0,
  }) async {
    container = await containerConSesion(db, rol: rol);
    await sembrarPorPedir(porPedir);
    tester.view.physicalSize = const Size(360 * 3, 780 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: temaClaro(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(escala)),
            child: child!,
          ),
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> avisar(
    WidgetTester tester,
    List<AvisoExistencias> avisos,
  ) async {
    container.read(avisoPorPedirProvider.notifier).mostrar(avisos);
    await tester.pumpAndSettle();
  }

  testWidgets('sin avisos no hay franja; con uno muestra su texto', (
    tester,
  ) async {
    await montar(tester);
    expect(find.byKey(const Key('franja_por_pedir')), findsNothing);
    await avisar(tester, [_avisoCoca]);
    expect(find.byKey(const Key('franja_por_pedir')), findsOneWidget);
    expect(find.text('Quedan 2 Coca: toca pedir'), findsOneWidget);
  });

  testWidgets(
    'con dos avisos muestra "Toca pedir 2 productos" y ambas líneas',
    (tester) async {
      await montar(tester);
      await avisar(tester, [_avisoCoca, _avisoLeche]);
      expect(find.text('Toca pedir 2 productos'), findsOneWidget);
      expect(find.text('Quedan 2 Coca: toca pedir'), findsOneWidget);
      expect(find.text('Se agotó Leche'), findsOneWidget);
    },
  );

  testWidgets('cerrar quita la franja', (tester) async {
    await montar(tester);
    await avisar(tester, [_avisoCoca]);
    await tester.tap(find.byKey(const Key('cerrar_franja_por_pedir')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('franja_por_pedir')), findsNothing);
    expect(container.read(avisoPorPedirProvider), isEmpty);
  });

  testWidgets(
    'Ver por pedir cierra el aviso y abre Inventario en "Por pedir"',
    (tester) async {
      await montar(tester, porPedir: 1);
      await avisar(tester, [_avisoCoca]);
      await tester.tap(find.byKey(const Key('boton_ver_por_pedir_franja')));
      await tester.pumpAndSettle();
      expect(container.read(avisoPorPedirProvider), isEmpty);
      expect(find.byKey(const Key('franja_por_pedir')), findsNothing);
      final vista = find.text('Por pedir (1)');
      expect(vista, findsOneWidget);
      expect(find.byKey(const Key('por_pedir_1')), findsOneWidget);
    },
  );

  testWidgets(
    'indicador muestra "2 por pedir" a un vendedor y se oculta con 0',
    (tester) async {
      await montar(tester, porPedir: 2);
      expect(find.byKey(const Key('indicador_por_pedir')), findsOneWidget);
      expect(find.text('2 por pedir'), findsOneWidget);
      final tamano = tester.getSize(
        find.byKey(const Key('indicador_por_pedir')),
      );
      expect(tamano.height, greaterThanOrEqualTo(48));
      await tester.tap(find.byKey(const Key('indicador_por_pedir')));
      await tester.pumpAndSettle();
      expect(find.text('Por pedir (2)'), findsOneWidget);
    },
  );

  testWidgets('sin productos por pedir no hay indicador', (tester) async {
    await montar(tester);
    expect(find.byKey(const Key('indicador_por_pedir')), findsNothing);
  });

  testWidgets('franja e indicador sin desborde a 2,0× en 360 dp', (
    tester,
  ) async {
    await montar(tester, porPedir: 2, escala: 2.0);
    await avisar(tester, [_avisoCoca, _avisoLeche]);
    expect(find.byKey(const Key('franja_por_pedir')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('indicador_por_pedir')),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('indicador_por_pedir')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('la franja es liveRegion y el cerrar tiene tooltip', (
    tester,
  ) async {
    await montar(tester);
    await avisar(tester, [_avisoCoca]);
    final vivo = find.descendant(
      of: find.byKey(const Key('franja_por_pedir')),
      matching: find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.liveRegion == true,
      ),
    );
    final envolvente = find.ancestor(
      of: find.byKey(const Key('franja_por_pedir')),
      matching: find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.liveRegion == true,
      ),
    );
    expect(
      vivo.evaluate().isNotEmpty || envolvente.evaluate().isNotEmpty,
      isTrue,
    );
    expect(find.byTooltip('Cerrar aviso'), findsOneWidget);
  });
}
