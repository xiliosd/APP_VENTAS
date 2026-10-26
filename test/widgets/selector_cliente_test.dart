import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/ticket_provider.dart';
import 'package:app_ventas/widgets/selector_cliente.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/montaje.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  ClienteTicket? elegido;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    elegido = null;
  });
  tearDown(() => db.close());

  Future<int> sembrar(String nombre, String apellido, {String? telefono}) => db
      .into(db.clientes)
      .insert(
        ClientesCompanion.insert(
          nombre: nombre,
          apellido: Value(apellido),
          telefono: Value(telefono),
        ),
      );

  Future<void> montar(WidgetTester tester, {bool exigir = false}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    container = await containerConSesion(db);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      appDePrueba(
        container,
        inicio: Scaffold(
          body: StatefulBuilder(
            builder: (contexto, setState) => SelectorCliente(
              elegido: elegido,
              onElegir: (cliente) => setState(() => elegido = cliente),
              exigir: exigir,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> buscar(WidgetTester tester, String texto) async {
    await tester.enterText(find.byKey(const Key('campo_cliente')), texto);
    await tester.pumpAndSettle();
  }

  testWidgets('buscar por apellido sugiere al cliente', (tester) async {
    final id = await sembrar('Pedro', 'Gómez');
    await sembrar('Rosa', 'Díaz');
    await montar(tester);

    await buscar(tester, 'gomez');

    expect(find.byKey(Key('cliente_sugerido_$id')), findsOneWidget);
    expect(find.text('Pedro Gómez'), findsOneWidget);
    expect(find.text('Rosa Díaz'), findsNothing);
  });

  testWidgets('buscar por teléfono sugiere al cliente', (tester) async {
    final id = await sembrar('Pedro', 'Gómez', telefono: '300 123 4567');
    await sembrar('Rosa', 'Díaz', telefono: '3109998888');
    await montar(tester);

    await buscar(tester, '3001234567');

    expect(find.byKey(Key('cliente_sugerido_$id')), findsOneWidget);
    expect(find.text('Rosa Díaz'), findsNothing);
  });

  testWidgets('tocar una sugerencia elige al cliente con su apellido', (
    tester,
  ) async {
    final id = await sembrar('Pedro', 'Gómez', telefono: '3001234567');
    await montar(tester);

    await buscar(tester, 'pedro');
    await tester.tap(find.byKey(Key('cliente_sugerido_$id')));
    await tester.pumpAndSettle();

    expect(elegido!.id, id);
    expect(elegido!.nombreCompleto, 'Pedro Gómez');
    expect(elegido!.telefono, '3001234567');
    expect(find.byKey(const Key('cliente_elegido')), findsOneWidget);
  });

  testWidgets('"Nuevo" abre el formulario con el texto y elige el resultado', (
    tester,
  ) async {
    await montar(tester);

    await buscar(tester, 'Ana');
    await tester.tap(find.byKey(const Key('boton_cliente_nuevo')));
    await tester.pumpAndSettle();
    final nombre = tester.widget<TextField>(
      find.byKey(const Key('campo_nombre_cliente')),
    );
    expect(nombre.controller!.text, 'Ana');
    await tester.enterText(
      find.byKey(const Key('campo_apellido_cliente')),
      'Ruiz',
    );
    await tester.tap(find.byKey(const Key('boton_continuar_cliente')));
    await tester.pumpAndSettle();

    expect(elegido!.id, isNull);
    expect(elegido!.nombreCompleto, 'Ana Ruiz');
    expect(await db.select(db.clientes).get(), isEmpty);
  });

  testWidgets('con coincidencia exacta el chip dice "Nuevo cliente"', (
    tester,
  ) async {
    await sembrar('Pedro', 'Gómez');
    await montar(tester);

    await buscar(tester, 'pedro gomez');

    expect(find.text('Nuevo cliente'), findsOneWidget);
  });

  testWidgets('al exigir cliente pide escribir o elegir con el campo vacío', (
    tester,
  ) async {
    await montar(tester, exigir: true);

    expect(find.text('Escribe o elige el cliente'), findsOneWidget);
  });

  testWidgets('al exigir cliente con texto escrito pide tocar uno o «Nuevo»', (
    tester,
  ) async {
    await montar(tester, exigir: true);

    await buscar(tester, 'Ana');

    expect(find.text('Escribe o elige el cliente'), findsNothing);
    expect(find.text('Toca un cliente o «Nuevo»'), findsOneWidget);
  });

  testWidgets('sin exigir cliente no muestra aviso', (tester) async {
    await montar(tester);

    await buscar(tester, 'Ana');

    expect(find.text('Toca un cliente o «Nuevo»'), findsNothing);
    expect(find.text('Escribe o elige el cliente'), findsNothing);
  });
}
