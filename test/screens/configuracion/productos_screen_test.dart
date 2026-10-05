import 'dart:async';

import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/database_provider.dart';
import 'package:app_ventas/providers/repository_providers.dart';
import 'package:app_ventas/repositories/producto_repository.dart';
import 'package:app_ventas/screens/configuracion/productos_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> montar(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: ProductosScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<int> crearArepa() => db.into(db.productos).insert(
        ProductosCompanion.insert(nombre: 'Arepa', precio: 3000),
      );

  testWidgets('sin productos muestra el estado vacío', (tester) async {
    await montar(tester);
    expect(find.text('Aún no tienes productos'), findsOneWidget);
  });

  testWidgets('crear un producto desde el panel lo agrega y lo confirma',
      (tester) async {
    await montar(tester);

    await tester.tap(find.byKey(const Key('boton_agregar_producto')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('campo_nombre_producto')), 'Arepa');
    await tester.enterText(
        find.byKey(const Key('campo_precio_producto')), '3.000');
    await tester.tap(find.byKey(const Key('boton_crear_producto')));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('Arepa'), findsOneWidget);
    expect(find.text(r'$3.000'), findsOneWidget);
    expect(find.text('Producto guardado'), findsOneWidget);
  });

  testWidgets('un precio inválido al crear muestra error y no guarda',
      (tester) async {
    await montar(tester);

    await tester.tap(find.byKey(const Key('boton_agregar_producto')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('campo_nombre_producto')), 'Arepa');
    await tester.enterText(
        find.byKey(const Key('campo_precio_producto')), '2.5');
    await tester.tap(find.byKey(const Key('boton_crear_producto')));
    await tester.pumpAndSettle();

    expect(find.text('Escribe un precio válido'), findsOneWidget);
    expect(await db.select(db.productos).get(), isEmpty);
  });

  testWidgets('editar un producto cambia nombre y precio', (tester) async {
    final id = await crearArepa();
    await montar(tester);

    await tester.tap(find.byKey(Key('producto_item_$id')));
    await tester.pumpAndSettle();
    expect(find.text('Editar producto'), findsOneWidget);

    await tester.enterText(
        find.byKey(const Key('campo_editar_nombre')), 'Arepa rellena');
    await tester.enterText(
        find.byKey(const Key('campo_editar_precio')), '3.500');
    await tester.tap(find.byKey(const Key('boton_guardar_producto')));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Arepa rellena'), findsOneWidget);
    expect(find.text(r'$3.500'), findsOneWidget);
    final producto = await db.select(db.productos).getSingle();
    expect(producto.nombre, 'Arepa rellena');
    expect(producto.precio, 3500);
  });

  testWidgets('precio inválido al editar muestra error y no guarda',
      (tester) async {
    final id = await crearArepa();
    await montar(tester);

    await tester.tap(find.byKey(Key('producto_item_$id')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('campo_editar_precio')), 'abc');
    await tester.tap(find.byKey(const Key('boton_guardar_producto')));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Escribe un precio válido'), findsOneWidget);
    expect((await db.select(db.productos).getSingle()).precio, 3000);
  });

  testWidgets('desactivar lo pasa a Inactivos y reactivar lo devuelve',
      (tester) async {
    final id = await crearArepa();
    await montar(tester);
    expect(find.text('Inactivos'), findsNothing);

    await tester.tap(find.byKey(Key('boton_desactivar_$id')));
    await tester.pumpAndSettle();

    expect(find.byKey(Key('producto_item_$id')), findsNothing);
    expect(find.text('Inactivos'), findsOneWidget);
    expect(find.byKey(Key('producto_inactivo_$id')), findsOneWidget);

    await tester.tap(find.byKey(Key('boton_reactivar_$id')));
    await tester.pumpAndSettle();

    expect(find.byKey(Key('producto_item_$id')), findsOneWidget);
    expect(find.text('Inactivos'), findsNothing);
  });

  testWidgets('un doble toque en Guardar producto cierra solo el diálogo',
      (tester) async {
    final id = await crearArepa();
    final guardado = Completer<void>();
    final navegador = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          productoRepositoryProvider
              .overrideWithValue(_ProductoRepositoryLento(db, guardado.future)),
        ],
        child: MaterialApp(navigatorKey: navegador, home: const Text('Inicio')),
      ),
    );
    navegador.currentState!
        .push(MaterialPageRoute(builder: (_) => const ProductosScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(Key('producto_item_$id')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('boton_guardar_producto')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('boton_guardar_producto')));
    await tester.pump();
    guardado.complete();
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(ProductosScreen), findsOneWidget);
  });
}

/// Espera a [_espera] antes de guardar los cambios, para simular la latencia
/// de la base de datos en segundo plano.
class _ProductoRepositoryLento extends ProductoRepository {
  _ProductoRepositoryLento(super.db, this._espera);

  final Future<void> _espera;

  @override
  Future<void> actualizarProducto(int id, {String? nombre, int? precio}) async {
    await _espera;
    return super.actualizarProducto(id, nombre: nombre, precio: precio);
  }
}
