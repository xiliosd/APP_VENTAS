import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/repository_providers.dart';
import 'package:app_ventas/providers/ticket_provider.dart';
import 'package:app_ventas/ui/tema_app.dart';
import 'package:app_ventas/widgets/formulario_cliente.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/montaje.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  ClienteTicket? resultado;
  var respondio = false;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    resultado = null;
    respondio = false;
  });
  tearDown(() => db.close());

  Future<void> montar(
    WidgetTester tester,
    Future<void> Function(BuildContext) alTocar,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    container = await containerConSesion(db);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      appDePrueba(
        container,
        inicio: Scaffold(
          body: Builder(
            builder: (contexto) => TextButton(
              key: const Key('abrir'),
              onPressed: () => alTocar(contexto),
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('abrir')));
    await tester.pumpAndSettle();
  }

  Future<void> abrirNuevo(WidgetTester tester, {String texto = ''}) =>
      montar(tester, (contexto) async {
        resultado = await pedirClienteNuevo(contexto, textoInicial: texto);
        respondio = true;
      });

  Future<void> escribir(WidgetTester tester, String clave, String texto) =>
      tester.enterText(find.byKey(Key(clave)), texto);

  Future<void> continuar(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('boton_continuar_cliente')));
    await tester.pumpAndSettle();
  }

  Future<int> sembrar(String nombre, String apellido, {String? telefono}) => db
      .into(db.clientes)
      .insert(
        ClientesCompanion.insert(
          nombre: nombre,
          apellido: Value(apellido),
          telefono: Value(telefono),
        ),
      );

  testWidgets('exige nombre y apellido', (tester) async {
    await abrirNuevo(tester);
    await escribir(tester, 'campo_nombre_cliente', 'Juan');
    await continuar(tester);
    expect(find.text('Escribe el apellido'), findsOneWidget);
    expect(respondio, isFalse);
  });

  testWidgets('reparte el texto inicial en nombre y apellido', (tester) async {
    await abrirNuevo(tester, texto: 'juan carlos pérez');
    expect(find.widgetWithText(TextField, 'juan'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'carlos pérez'), findsOneWidget);
  });

  testWidgets('sin parecidos devuelve un cliente nuevo sin guardarlo', (
    tester,
  ) async {
    await abrirNuevo(tester, texto: 'Ana Gómez');
    await continuar(tester);
    expect(resultado?.id, isNull);
    expect(resultado?.nombreCompleto, 'Ana Gómez');
    expect(
      await container.read(clienteRepositoryProvider).listarClientes(),
      isEmpty,
    );
  });

  testWidgets('con un parecido avisa y "Usar este cliente" devuelve su id', (
    tester,
  ) async {
    final id = await sembrar('Ana', 'Gómez');
    await abrirNuevo(tester, texto: 'ana gomez');
    await continuar(tester);
    expect(find.text('Ya existe un cliente parecido'), findsOneWidget);
    expect(find.text('Sin teléfono'), findsOneWidget);
    expect(find.text('Al día'), findsOneWidget);
    await tester.tap(find.byKey(Key('usar_cliente_$id')));
    await tester.pumpAndSettle();
    expect(resultado?.id, id);
  });

  testWidgets('"Crear otro de todas formas" devuelve un cliente nuevo', (
    tester,
  ) async {
    await sembrar('Ana', 'Gómez');
    await abrirNuevo(tester, texto: 'Ana Gómez');
    await continuar(tester);
    await tester.tap(find.byKey(const Key('crear_otro_cliente')));
    await tester.pumpAndSettle();
    expect(respondio, isTrue);
    expect(resultado?.id, isNull);
    expect(resultado?.nombreCompleto, 'Ana Gómez');
  });

  testWidgets('teléfono repetido avisa aunque el nombre sea distinto', (
    tester,
  ) async {
    await sembrar('Pedro', 'Ruiz', telefono: '3001234567');
    await abrirNuevo(tester, texto: 'Luis Mora');
    await escribir(tester, 'campo_telefono_cliente', '300 123 4567');
    await continuar(tester);
    expect(find.text('Ya existe un cliente parecido'), findsOneWidget);
    expect(find.text('Pedro Ruiz'), findsOneWidget);
    expect(find.text('3001234567'), findsOneWidget);
  });

  testWidgets('teléfono inválido muestra el error', (tester) async {
    await abrirNuevo(tester, texto: 'Luis Mora');
    await escribir(tester, 'campo_telefono_cliente', '12345');
    await continuar(tester);
    expect(find.text('Escribe un celular de 10 dígitos'), findsOneWidget);
    expect(respondio, isFalse);
  });

  testWidgets('editarCliente guarda el apellido de un cliente antiguo', (
    tester,
  ) async {
    final id = await db
        .into(db.clientes)
        .insert(ClientesCompanion.insert(nombre: 'Marta'));
    final cliente = await (db.select(
      db.clientes,
    )..where((c) => c.id.equals(id))).getSingle();
    bool? guardo;
    await montar(tester, (contexto) async {
      guardo = await editarCliente(contexto, cliente);
    });
    await escribir(tester, 'campo_apellido_cliente', 'Rojas');
    await continuar(tester);
    expect(guardo, isTrue);
    final guardado = await container
        .read(clienteRepositoryProvider)
        .obtenerCliente(id);
    expect(guardado?.apellido, 'Rojas');
  });

  testWidgets('editar un cliente antiguo sin apellido reparte su nombre', (
    tester,
  ) async {
    final id = await db
        .into(db.clientes)
        .insert(ClientesCompanion.insert(nombre: 'Pedro Pablo Ruiz'));
    final cliente = await (db.select(
      db.clientes,
    )..where((c) => c.id.equals(id))).getSingle();
    bool? guardo;
    await montar(tester, (contexto) async {
      guardo = await editarCliente(contexto, cliente);
    });
    final nombre = tester.widget<TextField>(
      find.byKey(const Key('campo_nombre_cliente')),
    );
    final apellido = tester.widget<TextField>(
      find.byKey(const Key('campo_apellido_cliente')),
    );
    expect(nombre.controller!.text, 'Pedro');
    expect(apellido.controller!.text, 'Pablo Ruiz');
    await continuar(tester);
    expect(guardo, isTrue);
    final guardado = await container
        .read(clienteRepositoryProvider)
        .obtenerCliente(id);
    expect(guardado?.nombre, 'Pedro');
    expect(guardado?.apellido, 'Pablo Ruiz');
  });

  testWidgets('editar con un parecido ofrece volver sin guardar', (
    tester,
  ) async {
    await sembrar('Ana', 'Gómez');
    final id = await sembrar('Ana', 'Lopez');
    final cliente = (await db.select(db.clientes).get()).firstWhere(
      (c) => c.id == id,
    );
    bool? guardo;
    await montar(tester, (contexto) async {
      guardo = await editarCliente(contexto, cliente);
    });
    await escribir(tester, 'campo_apellido_cliente', 'Gomez');
    await continuar(tester);
    expect(find.text('Guardar de todas formas'), findsOneWidget);
    expect(find.text('Usar este cliente'), findsNothing);
    await tester.tap(find.byKey(const Key('volver_cliente')));
    await tester.pumpAndSettle();
    expect(guardo, isNull);
    expect(find.text('Editar cliente'), findsOneWidget);
    final sinCambio = await container
        .read(clienteRepositoryProvider)
        .obtenerCliente(id);
    expect(sinCambio?.apellido, 'Lopez');
  });

  testWidgets('crearClienteDesdeFormulario crea el cliente', (tester) async {
    int? id;
    await montar(tester, (contexto) async {
      id = await crearClienteDesdeFormulario(contexto);
    });
    await escribir(tester, 'campo_nombre_cliente', 'Rosa');
    await escribir(tester, 'campo_apellido_cliente', 'Díaz');
    await continuar(tester);
    final todos = await container
        .read(clienteRepositoryProvider)
        .listarClientes();
    expect(todos.single.id, id);
    expect(todos.single.apellido, 'Díaz');
  });

  testWidgets('formulario de cliente a letra 2,0× no desborda', (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 690 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    container = await containerConSesion(db);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: temaClaro(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2.0)),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (contexto) => TextButton(
                key: const Key('abrir'),
                onPressed: () => pedirClienteNuevo(contexto),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('abrir')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('campo_nombre_cliente')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
