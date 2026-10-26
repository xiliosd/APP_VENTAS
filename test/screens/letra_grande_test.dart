import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/screens/fiado/lista_fiado_screen.dart';
import 'package:app_ventas/screens/home/home_screen.dart';
import 'package:app_ventas/screens/venta/registrar_venta_screen.dart';
import 'package:app_ventas/ui/tema_app.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/montaje.dart';

/// Pantallas principales en un celular de 360 dp con la letra al máximo (2,0×).
void main() {
  late AppDatabase db;
  late ProviderContainer container;
  final navegador = GlobalKey<NavigatorState>();

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    container = await containerConSesion(db);
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> sembrarDatos() async {
    const nombres = [
      'Arroz Diana extra largo de primera calidad libra',
      'Aceite vegetal de girasol botella familiar grande',
    ];
    for (final nombre in nombres) {
      await db
          .into(db.productos)
          .insert(ProductosCompanion.insert(nombre: nombre, precio: 3800));
    }
    final ana = (await db.select(db.usuarios).get()).first.id;
    final clienteId = await db
        .into(db.clientes)
        .insert(
          ClientesCompanion.insert(
            nombre: 'María Fernanda',
            apellido: const Value('Rodríguez de la Hoz'),
          ),
        );
    await db
        .into(db.ventas)
        .insert(
          VentasCompanion.insert(
            monto: 125000,
            fecha: DateTime.now(),
            usuarioId: ana,
          ),
        );
    await db
        .into(db.ventas)
        .insert(
          VentasCompanion.insert(
            monto: 98000,
            fecha: DateTime.now().subtract(const Duration(days: 20)),
            esFiado: const Value(true),
            clienteId: Value(clienteId),
            usuarioId: ana,
          ),
        );
  }

  Future<void> montar(WidgetTester tester, Widget inicio) async {
    tester.view.physicalSize = const Size(360 * 3, 780 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await sembrarDatos();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: temaClaro(),
          navigatorKey: navegador,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2.0)),
            child: child!,
          ),
          home: inicio,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Inicio a 2,0× en 360 dp no desborda', (tester) async {
    await montar(tester, const HomeScreen());
    expect(tester.takeException(), isNull);
  });

  testWidgets('Nueva venta a 2,0× en 360 dp no desborda', (tester) async {
    await montar(tester, const Scaffold(body: Text('Inicio')));
    navegador.currentState!.push(
      MaterialPageRoute(builder: (_) => const RegistrarVentaScreen()),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('monto_rapido_2000')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('¿Cómo paga? abierta, con ¿Quién compra? desplegado, a 2,0× '
      'no desborda', (tester) async {
    await montar(tester, const Scaffold(body: Text('Inicio')));
    navegador.currentState!.push(
      MaterialPageRoute(builder: (_) => const RegistrarVentaScreen()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('monto_rapido_2000')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('boton_cobrar')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('hoja_como_paga')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.byKey(const Key('quien_compra')));
    await tester.tap(find.text('Elegir cliente'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('campo_cliente')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Fiado a 2,0× en 360 dp no desborda', (tester) async {
    await montar(tester, const Scaffold(body: ListaFiadoScreen()));
    expect(find.textContaining('Rodríguez'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
