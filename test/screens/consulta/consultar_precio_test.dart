import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/repository_providers.dart';
import 'package:app_ventas/providers/ticket_provider.dart';
import 'package:app_ventas/screens/consulta/consultar_precio.dart';
import 'package:app_ventas/servicios/lector_codigo.dart';
import 'package:app_ventas/servicios/open_food_facts.dart';
import 'package:app_ventas/ui/tema_app.dart';
import 'package:app_ventas/util/formato_moneda.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/lector_falso.dart';
import '../../support/montaje.dart';

class _SinDatos implements ConsultaProducto {
  @override
  Future<DatosProducto?> buscar(String codigo) async => null;
}

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late LectorFalso lector;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<int> crearProducto({
    String nombre = 'Gaseosa',
    int precio = 2500,
    String? codigo = '7702',
    String? marca = 'Postobón',
    String? tamano = '400 ml',
    bool activo = true,
  }) => db
      .into(db.productos)
      .insert(
        ProductosCompanion.insert(
          nombre: nombre,
          precio: precio,
          codigoBarras: Value(codigo),
          marca: Value(marca),
          tamano: Value(tamano),
          activo: Value(activo),
        ),
      );

  Future<void> abrir(
    WidgetTester tester, {
    required List<String?> codigos,
    String rol = 'admin',
    double escalaTexto = 1.0,
    Size? tamano,
  }) async {
    lector = LectorFalso(codigos);
    container = await containerConSesion(
      db,
      rol: rol,
      overrides: [
        lectorCodigoProvider.overrideWithValue(lector),
        consultaProductoProvider.overrideWithValue(_SinDatos()),
      ],
    );
    tester.view.physicalSize = tamano ?? const Size(1080, 2400);
    tester.view.devicePixelRatio = tamano == null ? 2.625 : 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: temaClaro(),
          builder: (contexto, hijo) => MediaQuery(
            data: MediaQuery.of(contexto)
                .copyWith(textScaler: TextScaler.linear(escalaTexto)),
            child: hijo!,
          ),
          home: Scaffold(
            body: Consumer(
              builder: (contexto, ref, _) => TextButton(
                onPressed: () => consultarPrecio(contexto, ref),
                child: const Text('Consultar precio'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Consultar precio'));
    await tester.pumpAndSettle();
  }

  testWidgets('producto activo: muestra nombre, precio, marca y tamaño', (
    tester,
  ) async {
    await crearProducto();
    await abrir(tester, codigos: ['7702']);
    expect(find.text('Gaseosa'), findsOneWidget);
    expect(find.text(formatoMoneda(2500)), findsOneWidget);
    expect(find.text('Postobón · 400 ml'), findsOneWidget);
    expect(find.text('Consultar otro'), findsOneWidget);
    expect(find.text('Listo'), findsOneWidget);
    expect(lector.usos, [UsoEscaner.consulta]);
  });

  testWidgets('no toca el ticket abierto', (tester) async {
    final id = await crearProducto();
    await abrir(tester, codigos: ['7702']);
    // El ticket ya tenía una línea antes de consultar.
    final suscripcion = container.listen(ticketProvider, (_, _) {});
    addTearDown(suscripcion.close);
    final producto = await container
        .read(productoRepositoryProvider)
        .productoPorCodigo('7702');
    container.read(ticketProvider.notifier).agregarProducto(producto!);
    final antes = container.read(ticketProvider);
    await tester.tap(find.text('Listo'));
    await tester.pumpAndSettle();
    expect(container.read(ticketProvider), same(antes));
    expect(antes.lineas.single.productoId, id);
  });

  testWidgets('Consultar otro vuelve a escanear', (tester) async {
    await crearProducto();
    await abrir(tester, codigos: ['7702', null]);
    await tester.tap(find.text('Consultar otro'));
    await tester.pumpAndSettle();
    expect(lector.usos, [UsoEscaner.consulta, UsoEscaner.consulta]);
    expect(find.text('Gaseosa'), findsNothing);
  });

  testWidgets('cancelar el escáner no muestra nada', (tester) async {
    await abrir(tester, codigos: [null]);
    expect(lector.usos, [UsoEscaner.consulta]);
    expect(find.text('Consultar otro'), findsNothing);
    expect(find.text('Listo'), findsNothing);
  });

  testWidgets('código desconocido: lo dice y deja agregar', (tester) async {
    await abrir(tester, codigos: ['999']);
    expect(
      find.text('Este código aún no está en tus productos'),
      findsOneWidget,
    );
    await tester.tap(find.text('Agregar producto'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('campo_nombre_rapido')), 'Pan');
    await tester.enterText(find.byKey(const Key('campo_precio_rapido')), '500');
    await tester.ensureVisible(
      find.byKey(const Key('boton_guardar_producto_rapido')),
    );
    await tester.tap(find.byKey(const Key('boton_guardar_producto_rapido')));
    await tester.pumpAndSettle();
    expect(find.text('Pan'), findsOneWidget);
    expect(find.text(formatoMoneda(500)), findsOneWidget);
  });

  testWidgets('agregar y cancelar la hoja rápida no crea nada', (tester) async {
    await abrir(tester, codigos: ['999']);
    await tester.tap(find.text('Agregar producto'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(
      find.text('Este código aún no está en tus productos'),
      findsOneWidget,
    );
    expect(await db.select(db.productos).get(), isEmpty);
  });

  testWidgets('producto inactivo: lo dice sin precio', (tester) async {
    await crearProducto(activo: false);
    await abrir(tester, codigos: ['7702']);
    expect(find.text('Este producto está inactivo'), findsOneWidget);
    expect(
      find.text('El administrador lo reactiva en Productos.'),
      findsOneWidget,
    );
    expect(find.text(formatoMoneda(2500)), findsNothing);
  });

  testWidgets('el vendedor no ve Editar producto', (tester) async {
    await crearProducto();
    await abrir(tester, codigos: ['7702'], rol: 'vendedor');
    expect(find.text('Gaseosa'), findsOneWidget);
    expect(find.text('Editar producto'), findsNothing);
  });

  testWidgets('el administrador ve Editar producto', (tester) async {
    await crearProducto();
    await abrir(tester, codigos: ['7702'], rol: 'admin');
    expect(find.text('Editar producto'), findsOneWidget);
  });

  testWidgets('a letra 2,0× en 360 dp la hoja no desborda', (tester) async {
    await crearProducto(
      nombre: 'Gaseosa sabor manzana postobón extra grande',
      marca: 'Postobón Colombia',
    );
    await abrir(
      tester,
      codigos: ['7702'],
      escalaTexto: 2.0,
      tamano: const Size(360, 740),
    );
    expect(find.text(formatoMoneda(2500)), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
