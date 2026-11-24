import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/screens/agregar_celular/agregar_celular_screen.dart';
import 'package:app_ventas/screens/agregar_celular/paso_mostrar.dart';
import 'package:app_ventas/screens/agregar_celular/paso_soy_yo.dart';
import 'package:app_ventas/sincronizacion/nube_tienda.dart';
import 'package:app_ventas/sincronizacion/sincronizacion_provider.dart';
import 'package:app_ventas/ui/tema_app.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/respaldo_prueba.dart';
import '../../support/sincronizacion_prueba.dart';

/// Falla al listar los celulares la primera vez, como sin internet.
class _SincronizacionSinInternet extends SincronizacionFalsa {
  _SincronizacionSinInternet() : super(inicial: _alDia);

  int intentos = 0;

  @override
  Future<List<CelularTienda>> celulares() async {
    intentos++;
    if (intentos == 1) throw const ErrorSinConexion();
    return const [];
  }
}

const _alDia = EstadoTiendaCompartida(fase: FaseSincronizacion.alDia);

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> crearVendedor(String nombre, {String? idGlobal}) => db
      .into(db.usuarios)
      .insert(
        UsuariosCompanion.insert(
          nombre: nombre,
          rol: 'vendedor',
          pinHash: 'x',
          numeroVendedor: const Value(1),
          idGlobal: idGlobal == null ? const Value.absent() : Value(idGlobal),
        ),
      );

  Future<void> montar(
    WidgetTester tester, {
    bool respaldoActivo = true,
    SincronizacionFalsa? sincronizacion,
    double letra = 1.0,
  }) async {
    final container = await containerRespaldo(
      db,
      NubeRespaldoFalsa(conSesion: respaldoActivo, correo: 'tienda@correo.com'),
      habilitado: respaldoActivo,
      sincronizacion: () =>
          sincronizacion ?? SincronizacionFalsa(inicial: _alDia),
    );
    addTearDown(container.dispose);
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: temaClaro(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(letra)),
            child: child!,
          ),
          home: const AgregarCelularScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('con respaldo inactivo empieza pidiendo el correo', (
    tester,
  ) async {
    await montar(tester, respaldoActivo: false);
    expect(find.text('Confirma tu correo'), findsOneWidget);
    expect(find.byKey(const Key('boton_confirmar_correo')), findsOneWidget);
    expect(find.text('¿Quién va a usar el celular?'), findsNothing);
  });

  testWidgets('con la tienda compartida empieza en Quién', (tester) async {
    await crearVendedor('Beto');
    await montar(tester);
    expect(find.text('¿Quién va a usar el celular?'), findsOneWidget);
    expect(find.text('Beto'), findsOneWidget);
    expect(find.byKey(const Key('quien_otra_persona')), findsOneWidget);
    expect(find.byKey(const Key('quien_soy_yo')), findsOneWidget);
    expect(find.text('Cambiar su celular'), findsNothing);
  });

  testWidgets('un vendedor con celular aprobado dice Cambiar su celular', (
    tester,
  ) async {
    await crearVendedor('Beto', idGlobal: 'g-beto');
    await crearVendedor('Cata', idGlobal: 'g-cata');
    await montar(
      tester,
      sincronizacion: SincronizacionFalsa(
        inicial: _alDia,
        celularesTienda: [
          CelularTienda(
            usuarioAuth: 'a1',
            rol: 'vendedor',
            estado: EstadoMiembro.aprobado,
            solicitadoEn: DateTime(2026, 11, 1),
            usuarioIdGlobal: 'g-beto',
          ),
        ],
      ),
    );
    expect(find.text('Cambiar su celular'), findsOneWidget);
  });

  testWidgets('Otra persona crea un vendedor y pasa al paso 3', (tester) async {
    final sincronizacion = SincronizacionFalsa(inicial: _alDia);
    await montar(tester, sincronizacion: sincronizacion);
    await tester.tap(find.byKey(const Key('quien_otra_persona')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('selector_rol')), findsNothing);
    await tester.enterText(
      find.byKey(const Key('campo_nombre_usuario')),
      'Dora',
    );
    await tester.enterText(find.byKey(const Key('campo_pin_usuario')), '4321');
    await tester.tap(find.byKey(const Key('boton_crear_usuario')));
    await tester.pumpAndSettle();

    expect(find.byType(PasoMostrar), findsOneWidget);
    final usuario = (await db.select(db.usuarios).get()).single;
    expect(usuario.nombre, 'Dora');
    expect(usuario.rol, 'vendedor');
    expect(sincronizacion.sincronizaciones, 1);
    // El respaldo programa una copia 30 s después de un cambio en los datos.
    await tester.pump(const Duration(seconds: 31));
  });

  testWidgets('Soy yo muestra los pasos con el correo de la tienda', (
    tester,
  ) async {
    await montar(tester);
    await tester.tap(find.byKey(const Key('quien_soy_yo')));
    await tester.pumpAndSettle();
    expect(find.byType(PasoSoyYo), findsOneWidget);
    expect(
      find.text('1. Instala VeciTienda en el otro celular.'),
      findsOneWidget,
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('correo_dueno'))).data,
      'tienda@correo.com',
    );
    expect(find.text('Listo'), findsOneWidget);
  });

  testWidgets('Soy yo cabe con la letra al máximo en 360 dp', (tester) async {
    await montar(tester, letra: 2.0);
    await tester.tap(find.byKey(const Key('quien_soy_yo')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Listo'), 200);
    expect(tester.takeException(), isNull);
    expect(find.text('Listo'), findsOneWidget);
  });

  testWidgets('Quién cabe con la letra al máximo en 360 dp', (tester) async {
    await crearVendedor('Beto con un nombre bastante largo de verdad');
    await montar(tester, letra: 2.0);
    await tester.scrollUntilVisible(find.byKey(const Key('quien_soy_yo')), 200);
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('quien_soy_yo')), findsOneWidget);
  });

  testWidgets('sin internet en Quién muestra el mensaje y Reintentar', (
    tester,
  ) async {
    await crearVendedor('Beto');
    await montar(tester, sincronizacion: _SincronizacionSinInternet());
    expect(
      find.text('Sin internet. Inténtalo cuando tengas conexión.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Beto'), findsOneWidget);
    expect(find.text('Reintentar'), findsNothing);
  });
}
