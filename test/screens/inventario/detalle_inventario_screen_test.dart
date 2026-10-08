import 'package:app_ventas/data/database.dart';
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
}
