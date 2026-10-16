import 'dart:async';

import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/ticket_provider.dart';
import 'package:app_ventas/repositories/producto_repository.dart';
import 'package:app_ventas/screens/venta/registrar_venta_screen.dart';
import 'package:app_ventas/servicios/dictado.dart';
import 'package:app_ventas/ui/boton_principal.dart';
import 'package:app_ventas/ui/tema_app.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/dictado_falso.dart';
import '../../support/montaje.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late DictadoFalso dictado;
  final navegador = GlobalKey<NavigatorState>();
  late Map<String, int> ids;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    dictado = DictadoFalso();
    container = await containerConSesion(
      db,
      overrides: [dictadoProvider.overrideWithValue(dictado)],
    );
    final repo = ProductoRepository(db);
    ids = {};
    Future<void> nuevo(String nombre, int precio, {String? tamano}) async =>
        ids['$nombre ${tamano ?? ''}'.trim()] = await repo.guardarProducto(
          nombre: nombre,
          precio: precio,
          detalles: DetallesProducto(tamano: tamano),
        );
    await nuevo('Coca-Cola', 2500, tamano: '400 ml');
    await nuevo('Coca-Cola', 6000, tamano: '1,5 L');
    await nuevo('Pan', 500);
    await nuevo('Leche', 4000);
    await nuevo('Huevos', 600);
    await nuevo('Arroz', 3000);
    await nuevo('Aceite', 9000);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> abrir(
    WidgetTester tester, {
    bool dictarAlAbrir = false,
    bool practica = false,
    ThemeData? tema,
    double escala = 1,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      appDePrueba(container, navegador: navegador, tema: tema),
    );
    navegador.currentState!.push(
      MaterialPageRoute(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(escala)),
          child: RegistrarVentaScreen(
            dictarAlAbrir: dictarAlAbrir,
            practica: practica,
            conGlobos: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> dictar(WidgetTester tester, String texto) async {
    dictado.texto = texto;
    await tester.tap(find.byKey(const Key('boton_dictar')));
    await tester.pumpAndSettle();
  }

  bool habilitado(WidgetTester tester, String clave) =>
      tester.widget<BotonPrincipal>(find.byKey(Key(clave))).onPressed != null;

  Ticket ticket() => container.read(ticketProvider);

  testWidgets('el micrófono tiene su ayuda y no sale en la práctica', (
    tester,
  ) async {
    await abrir(tester);
    expect(find.byTooltip('Dictar venta'), findsOneWidget);

    await abrir(tester, practica: true);
    expect(find.byKey(const Key('boton_dictar')), findsNothing);
  });

  testWidgets('mientras escucha muestra lo que oye y "Listo" termina', (
    tester,
  ) async {
    dictado.pendiente = Completer();
    await abrir(tester);
    await tester.tap(find.byKey(const Key('boton_dictar')));
    await tester.pump();

    dictado.alOir!('dos coca');
    await tester.pump();
    expect(find.byKey(const Key('franja_dictado')), findsOneWidget);
    expect(find.text('dos coca'), findsOneWidget);

    await tester.tap(find.byKey(const Key('boton_listo_dictado')));
    await tester.pumpAndSettle();
    expect(dictado.detenciones, 1);
    expect(find.byKey(const Key('franja_dictado')), findsNothing);
  });

  testWidgets('la hoja muestra lo reconocido, lo dudoso y lo no encontrado', (
    tester,
  ) async {
    await abrir(tester);
    await dictar(tester, 'dos coca colas y un pan y tres tornillos');

    expect(find.text('¿Agrego esto?'), findsOneWidget);
    expect(
      find.text('dos coca colas y un pan y tres tornillos'),
      findsOneWidget,
    );
    expect(find.byKey(Key('parte_reconocida_${ids['Pan']}')), findsOneWidget);
    expect(find.byKey(const Key('parte_dudosa_0')), findsOneWidget);
    expect(find.text('No lo encontré: tornillos'), findsOneWidget);
    // Hasta elegir la Coca-Cola no se puede agregar.
    expect(habilitado(tester, 'boton_agregar_dictado'), isFalse);

    await tester.tap(
      find.byKey(Key('opcion_dictado_0_${ids['Coca-Cola 400 ml']}')),
    );
    await tester.pumpAndSettle();
    expect(habilitado(tester, 'boton_agregar_dictado'), isTrue);
    expect(find.text('Agregar al ticket (3)'), findsOneWidget);
  });

  testWidgets('confirmar suma al ticket que ya tenía algo (venta mixta)', (
    tester,
  ) async {
    await abrir(tester);
    await tester.tap(find.byKey(Key('producto_${ids['Pan']}')));
    await tester.pumpAndSettle();

    await dictar(tester, 'dos panes y una leche');
    await tester.tap(find.byKey(Key('sumar_dictado_${ids['Leche']}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('boton_agregar_dictado')));
    await tester.pumpAndSettle();

    expect(ticket().cantidadDe('p${ids['Pan']}'), 3);
    expect(ticket().cantidadDe('p${ids['Leche']}'), 2);
  });

  testWidgets('quitar una parte la saca de lo que se agrega', (tester) async {
    await abrir(tester);
    await dictar(tester, 'un pan y una leche');

    await tester.tap(find.byKey(Key('quitar_dictado_${ids['Leche']}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('boton_agregar_dictado')));
    await tester.pumpAndSettle();

    expect(ticket().cantidadDe('p${ids['Pan']}'), 1);
    expect(ticket().cantidadDe('p${ids['Leche']}'), 0);
  });

  testWidgets('"Buscar" pone lo no encontrado en el buscador', (tester) async {
    await abrir(tester);
    await dictar(tester, 'un pan y dos tornillos');

    await tester.tap(find.byKey(const Key('buscar_dictado_1')));
    await tester.pumpAndSettle();

    expect(find.text('¿Agrego esto?'), findsNothing);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('buscador_productos')))
          .controller!
          .text,
      'tornillos',
    );
  });

  testWidgets('si no reconoce nada, el texto queda en el buscador', (
    tester,
  ) async {
    await abrir(tester);
    await dictar(tester, 'tornillos');

    expect(find.text('¿Agrego esto?'), findsNothing);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('buscador_productos')))
          .controller!
          .text,
      'tornillos',
    );
  });

  testWidgets('avisa sin permiso, sin dictado disponible y si no oyó', (
    tester,
  ) async {
    await abrir(tester);

    dictado.estado = EstadoDictado.sinPermiso;
    await dictar(tester, 'un pan');
    expect(
      find.text(
        'Para dictar, permite el micrófono en Ajustes del celular → '
        'Apps → VeciTienda → Permisos',
      ),
      findsOneWidget,
    );

    dictado.estado = EstadoDictado.listo;
    dictado.noDisponible = true;
    await dictar(tester, 'un pan');
    expect(
      find.text(
        'El dictado no está disponible. Descarga el español sin '
        'conexión en los ajustes de voz de Google del celular',
      ),
      findsOneWidget,
    );

    dictado.noDisponible = false;
    await dictar(tester, '');
    dictado.texto = null;
    await tester.tap(find.byKey(const Key('boton_dictar')));
    await tester.pumpAndSettle();
    expect(find.text('No te escuché, intenta de nuevo'), findsOneWidget);
  });

  testWidgets('cerrar la pantalla mientras escucha detiene el dictado', (
    tester,
  ) async {
    dictado.pendiente = Completer();
    await abrir(tester);
    await tester.tap(find.byKey(const Key('boton_dictar')));
    await tester.pump();

    navegador.currentState!.pop();
    await tester.pumpAndSettle();

    expect(dictado.detenciones, 1);
  });

  testWidgets('con dictarAlAbrir empieza a escuchar sola', (tester) async {
    dictado.texto = 'un pan';
    await abrir(tester, dictarAlAbrir: true);

    expect(dictado.escuchas, 1);
    expect(find.text('¿Agrego esto?'), findsOneWidget);
  });

  testWidgets('la hoja en oscuro con letra 2,0× no desborda', (tester) async {
    await abrir(tester, tema: temaOscuro(), escala: 2);
    await dictar(tester, 'dos coca colas y un pan y tres tornillos');

    expect(tester.takeException(), isNull);
    expect(find.text('¿Agrego esto?'), findsOneWidget);
  });

  testWidgets('tras "Listo" la franja no vuelve y se puede dictar de nuevo', (
    tester,
  ) async {
    dictado
      ..pendiente = Completer()
      ..oyeDespuesDeDetener = 'un pan';
    await abrir(tester);
    await tester.tap(find.byKey(const Key('boton_dictar')));
    await tester.pump();

    await tester.tap(find.byKey(const Key('boton_listo_dictado')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('franja_dictado')), findsNothing);
    expect(
      tester.widget<IconButton>(find.byKey(const Key('boton_dictar'))).onPressed,
      isNotNull,
    );
  });

  testWidgets('sin reconocimiento local avisa que no dicta sin internet', (
    tester,
  ) async {
    dictado.estado = EstadoDictado.sinDictadoLocal;
    await abrir(tester);
    await dictar(tester, 'un pan');

    expect(
      find.text('Este celular no permite dictar sin internet'),
      findsOneWidget,
    );
    expect(dictado.escuchas, 0);
  });

  testWidgets('dos filas con el mismo producto no rompen la hoja', (
    tester,
  ) async {
    await abrir(tester);
    await dictar(tester, 'una coca cola 400 y dos coca colas');

    await tester.tap(
      find.byKey(Key('opcion_dictado_1_${ids['Coca-Cola 400 ml']}')),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Agregar al ticket (3)'), findsOneWidget);
  });
}
