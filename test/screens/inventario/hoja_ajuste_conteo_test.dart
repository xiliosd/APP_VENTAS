import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/sesion_provider.dart';
import 'package:app_ventas/repositories/inventario_repository.dart';
import 'package:app_ventas/screens/inventario/hoja_ajuste_conteo.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/montaje.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<Producto> conControl(Usuario ana, int hay) async {
    final id = await db
        .into(db.productos)
        .insert(ProductosCompanion.insert(nombre: 'Arepa', precio: 3500));
    await InventarioRepository(db, reloj: () => DateTime(2026, 10, 7, 8))
        .activarControl(id, cantidad: hay, minimo: 2, por: ana);
    return (db.select(db.productos)..where((p) => p.id.equals(id)))
        .getSingle();
  }

  Future<void> abrir(WidgetTester tester, Producto producto, container) async {
    await tester.pumpWidget(appDePrueba(
      container,
      inicio: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                mostrarHojaAjusteConteo(context, producto: producto),
            child: const Text('abrir'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  testWidgets('muestra lo que dice la app y guarda el conteo',
      (tester) async {
    final container = await containerConSesion(db);
    addTearDown(container.dispose);
    final ana = container.read(sesionProvider).usuarioActivo!;
    final producto = await conControl(ana, 12);
    await abrir(tester, producto, container);

    expect(find.text('Según la app hay 12. ¿Cuántas hay?'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('campo_conteo')), '9');
    await tester.enterText(find.byKey(const Key('campo_nota_conteo')), 'Rotas');
    await tester.tap(find.byKey(const Key('boton_guardar_conteo')));
    await tester.pumpAndSettle();

    expect(find.text('Conteo guardado'), findsOneWidget);
    final ajuste = (await db.select(db.conteosInventario).get()).last;
    expect((ajuste.cantidad, ajuste.anterior, ajuste.nota), (9, 12, 'Rotas'));
  });

  testWidgets('sin cantidad o negativa muestra el error', (tester) async {
    final container = await containerConSesion(db);
    addTearDown(container.dispose);
    final ana = container.read(sesionProvider).usuarioActivo!;
    final producto = await conControl(ana, 12);
    await abrir(tester, producto, container);

    await tester.tap(find.byKey(const Key('boton_guardar_conteo')));
    await tester.pumpAndSettle();
    expect(find.text('Escribe cuántas hay'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('campo_conteo')), '-3');
    await tester.tap(find.byKey(const Key('boton_guardar_conteo')));
    await tester.pumpAndSettle();
    expect(find.text('Escribe cuántas hay'), findsOneWidget);
    expect(await db.select(db.conteosInventario).get(), hasLength(1));
  });

  testWidgets('si el control se desactivó, guardar avisa sin romperse',
      (tester) async {
    final container = await containerConSesion(db);
    addTearDown(container.dispose);
    final ana = container.read(sesionProvider).usuarioActivo!;
    final producto = await conControl(ana, 12);
    await abrir(tester, producto, container);

    await InventarioRepository(db).desactivarControl(producto.id);
    await tester.enterText(find.byKey(const Key('campo_conteo')), '9');
    await tester.tap(find.byKey(const Key('boton_guardar_conteo')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('No se pudo guardar, intenta de nuevo'), findsOneWidget);
  });
}
