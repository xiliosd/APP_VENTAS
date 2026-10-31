import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/clientes_providers.dart';
import 'package:app_ventas/screens/clientes/clientes_screen.dart';
import 'package:app_ventas/screens/fiado/lista_fiado_screen.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/montaje.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> montar(
    WidgetTester tester, {
    Widget inicio = const ClientesScreen(),
    String rol = 'admin',
    Size tamano = const Size(1080, 2400),
    double letra = 1.0,
  }) async {
    tester.view.physicalSize = tamano;
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    container = await containerConSesion(db, rol: rol);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      appDePrueba(
        container,
        inicio: MediaQuery(
          data: MediaQueryData(
            size: tamano / 2.625,
            textScaler: TextScaler.linear(letra),
          ),
          child: inicio,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<int> cliente(String nombre, {String? apellido, String? telefono}) => db
      .into(db.clientes)
      .insert(
        ClientesCompanion.insert(
          nombre: nombre,
          apellido: Value(apellido),
          telefono: Value(telefono),
        ),
      );

  testWidgets('si falla la carga muestra el aviso amable', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    container = await containerConSesion(
      db,
      overrides: [
        listaClientesProvider.overrideWith(
          (ref) => Future<List<Cliente>>.error(StateError('base dañada')),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      appDePrueba(container, inicio: const ClientesScreen()),
    );
    await tester.pumpAndSettle();
    expect(find.text('No se pudo cargar'), findsOneWidget);
    expect(find.text('Cierra la app y vuelve a abrirla'), findsOneWidget);
    expect(find.textContaining('base dañada'), findsNothing);
  });

  testWidgets('sin clientes muestra el estado vacío', (tester) async {
    await montar(tester);
    expect(find.text('Aún no tienes clientes'), findsOneWidget);
  });

  testWidgets('lista a todos los clientes, también los de solo contado', (
    tester,
  ) async {
    await cliente('Zoila', apellido: 'Pérez');
    await cliente('Ana', apellido: 'Gómez');
    await montar(tester);
    expect(find.text('Ana Gómez'), findsOneWidget);
    expect(find.text('Zoila Pérez'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Ana Gómez')).dy,
      lessThan(tester.getTopLeft(find.text('Zoila Pérez')).dy),
    );
  });

  testWidgets('marca "Falta apellido" en clientes antiguos', (tester) async {
    await cliente('Pedro');
    await cliente('Ana', apellido: 'Gómez');
    await montar(tester);
    expect(find.text('Falta apellido'), findsOneWidget);
  });

  testWidgets('busca por teléfono y por nombre', (tester) async {
    await cliente('Ana', apellido: 'Gómez', telefono: '3001112233');
    await cliente('Luis', apellido: 'Rey', telefono: '3109998877');
    await montar(tester);
    await tester.enterText(
      find.byKey(const Key('buscador_clientes')),
      '310 999',
    );
    await tester.pumpAndSettle();
    expect(find.text('Luis Rey'), findsOneWidget);
    expect(find.text('Ana Gómez'), findsNothing);
    await tester.enterText(find.byKey(const Key('buscador_clientes')), 'gomez');
    await tester.pumpAndSettle();
    expect(find.text('Ana Gómez'), findsOneWidget);
    expect(find.text('Luis Rey'), findsNothing);
  });

  testWidgets('un vendedor entra desde Fiado y edita un cliente', (
    tester,
  ) async {
    final id = await cliente('Pedro');
    await montar(
      tester,
      inicio: const Scaffold(body: ListaFiadoScreen()),
      rol: 'vendedor',
    );
    await tester.tap(find.byKey(const Key('ir_a_clientes')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('cliente_item_$id')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Editar'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('campo_apellido_cliente')),
      'Ruiz',
    );
    await tester.tap(find.byKey(const Key('boton_continuar_cliente')));
    await tester.pumpAndSettle();
    expect(find.text('Pedro Ruiz'), findsWidgets);
  });

  testWidgets('la entrada a Clientes está con la lista de Fiado vacía', (
    tester,
  ) async {
    await montar(tester, inicio: const Scaffold(body: ListaFiadoScreen()));
    expect(find.byKey(const Key('ir_a_clientes')), findsOneWidget);
    expect(find.text('Todos los clientes'), findsOneWidget);
  });

  testWidgets('sin desborde con letra 2,0x en 360 dp', (tester) async {
    await cliente(
      'Maria Fernanda',
      apellido: 'Rodriguez Hernandez',
      telefono: '3001112233',
    );
    await cliente('Pedro');
    await montar(
      tester,
      tamano: const Size(360 * 2.625, 800 * 2.625),
      letra: 2.0,
    );
    expect(tester.takeException(), isNull);
  });
}
