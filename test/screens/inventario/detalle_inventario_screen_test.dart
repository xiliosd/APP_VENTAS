import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/sesion_provider.dart';
import 'package:app_ventas/repositories/inventario_repository.dart';
import 'package:app_ventas/repositories/proveedor_repository.dart';
import 'package:app_ventas/ui/nivel_existencias.dart';
import 'package:app_ventas/screens/inventario/detalle_inventario_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/montaje.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  testWidgets('un producto sin control lo dice en vez de quedarse cargando',
      (tester) async {
    final arepa = await db
        .into(db.productos)
        .insert(ProductosCompanion.insert(nombre: 'Arepa', precio: 3000));
    final container = await containerConSesion(db);
    addTearDown(container.dispose);
    await tester.pumpWidget(appDePrueba(container,
        inicio: DetalleInventarioScreen(productoId: arepa)));
    await tester.pumpAndSettle();

    expect(
        find.text('Este producto ya no controla existencias'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('la tarjeta de existencias lleva su etiqueta y los movimientos '
      'su ícono', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final container = await containerConSesion(db);
    addTearDown(container.dispose);
    final ana = container.read(sesionProvider).usuarioActivo!;
    final coca = await db
        .into(db.productos)
        .insert(ProductosCompanion.insert(nombre: 'Coca', precio: 3000));
    final postobon = await ProveedorRepository(db).crear(nombre: 'Postobón');
    final inv = InventarioRepository(db);
    await inv.activarControl(coca, cantidad: 2, minimo: 6, por: ana);
    await inv.ajustarConteo(coca, cantidad: 9, por: ana);
    await inv.recibirMercancia(
      proveedorId: postobon,
      lineas: [LineaRecibida(productoId: coca, cantidad: 3, precioCompra: 900)],
      por: ana,
    );
    await tester.pumpWidget(appDePrueba(container,
        inicio: DetalleInventarioScreen(productoId: coca)));
    await tester.pumpAndSettle();

    final tarjeta = find.byKey(const Key('tarjeta_existencias'));
    expect(tarjeta, findsOneWidget);
    expect(find.descendant(of: tarjeta, matching: find.byType(EtiquetaNivel)),
        findsOneWidget);
    expect(find.descendant(of: tarjeta, matching: find.text('OK')),
        findsOneWidget);
    expect(find.byIcon(Icons.call_received_rounded), findsOneWidget);
    expect(find.byIcon(Icons.edit_rounded), findsNWidgets(2));
  });
}
