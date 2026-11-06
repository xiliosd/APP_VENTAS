import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/main.dart';
import 'package:app_ventas/providers/database_provider.dart';
import 'package:app_ventas/providers/preferencias_provider.dart';
import 'package:app_ventas/screens/login/bienvenida_screen.dart';
import 'package:app_ventas/screens/login/seleccionar_usuario_screen.dart';
import 'package:app_ventas/screens/vendedor/esperando_aprobacion_screen.dart';
import 'package:app_ventas/sincronizacion/nube_tienda.dart';
import 'package:app_ventas/sincronizacion/sincronizacion_provider.dart';
import 'package:app_ventas/sincronizacion/sincronizador.dart';
import 'package:app_ventas/sincronizacion/supabase_nube_tienda.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/nube_tienda_falsa.dart';

void main() {
  late AppDatabase db;
  late NubeTiendaFalsa admin;
  late NubeTiendaFalsa celular;
  late String tienda;
  late String codigo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    admin = NubeTiendaFalsa();
    tienda = await admin.crearTienda('La Esquina');
    await admin.subir(tienda, [
      for (final (id, nombre, rol, numero) in [
        ('u-ana', 'Ana', 'admin', null),
        ('u-beto', 'Beto', 'vendedor', 1),
      ])
        CambioSubida(
          tabla: 'usuarios',
          idGlobal: id,
          datos: {
            'id_global': id,
            'nombre': nombre,
            'rol': rol,
            'activo': 1,
            'numero_vendedor': numero,
            'version_pin': 0,
          },
          borrado: false,
        ),
    ]);
    await admin.guardarPin(tienda, 'u-beto', '1234', 0);
    codigo = await admin.codigoTienda(tienda);
    celular = admin.otroCelular();
  });

  tearDown(() => db.close());

  Future<SharedPreferences> abrir(
    WidgetTester tester, {
    Map<String, Object> valores = const {},
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({
      'inicio_completo_visto': true,
      ...valores,
    });
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          preferenciasProvider.overrideWithValue(prefs),
          nubeTiendaProvider.overrideWithValue(celular),
          nombreCelularProvider.overrideWithValue('Redmi Note 13'),
        ],
        child: const AppVentas(),
      ),
    );
    await tester.pumpAndSettle();
    return prefs;
  }

  Future<void> pedirEntrada(
    WidgetTester tester, {
    String codigoEscrito = '',
    String numero = '1',
    String pin = '1234',
  }) async {
    await tester.tap(find.byKey(const Key('boton_unirse_tienda')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('campo_codigo_tienda')),
      codigoEscrito,
    );
    await tester.enterText(
      find.byKey(const Key('campo_numero_vendedor')),
      numero,
    );
    await tester.enterText(find.byKey(const Key('campo_pin_vendedor')), pin);
    await tester.tap(find.byKey(const Key('boton_pedir_entrada')));
    await tester.pumpAndSettle();
  }

  /// Deja pasar un sondeo del estado de la solicitud.
  Future<void> esperarSondeo(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  }

  testWidgets('el formulario revisa los campos antes de pedir entrada', (
    tester,
  ) async {
    await abrir(tester);

    await pedirEntrada(tester, numero: '', pin: '12');

    expect(
      find.text('Escribe el código de 6 letras y números'),
      findsOneWidget,
    );
    expect(find.text('Escribe tu número de vendedor'), findsOneWidget);
    expect(find.text('El PIN debe tener 4 dígitos'), findsOneWidget);
    expect(await celular.miMembresia(), isNull);
  });

  testWidgets('datos buenos llevan a esperar la aprobación', (tester) async {
    final prefs = await abrir(tester);

    await pedirEntrada(tester, codigoEscrito: codigo.toLowerCase());

    expect(find.byType(EsperandoAprobacionScreen), findsOneWidget);
    expect(
      find.text('Pídele al administrador que apruebe este celular en su app.'),
      findsOneWidget,
    );
    expect(prefs.getString(claveSolicitudPendiente), tienda);
    expect(
      (await admin.solicitudes(tienda)).single.nombreCelular,
      'Redmi Note 13',
    );
  });

  testWidgets('datos malos no dicen cuál falló', (tester) async {
    await abrir(tester);

    await pedirEntrada(tester, codigoEscrito: codigo, pin: '0000');

    expect(find.text('Código, número o PIN incorrectos.'), findsOneWidget);
    expect(find.byType(EsperandoAprobacionScreen), findsNothing);
  });

  testWidgets('sin internet lo dice y no espera', (tester) async {
    await abrir(tester);
    celular.sinConexion = true;

    await pedirEntrada(tester, codigoEscrito: codigo);

    expect(
      find.text('Sin internet. Inténtalo cuando tengas conexión.'),
      findsOneWidget,
    );
  });

  testWidgets('al aprobarlo baja la tienda y ya puede vender', (tester) async {
    final prefs = await abrir(tester);
    await pedirEntrada(tester, codigoEscrito: codigo);
    final solicitud = (await admin.solicitudes(tienda)).single;

    await admin.responderSolicitud(
      tienda,
      solicitud.usuarioAuth,
      aprobar: true,
    );
    await esperarSondeo(tester);

    expect(find.byType(SeleccionarUsuarioScreen), findsOneWidget);
    expect(
      find.text('¡Listo! Ya puedes vender en este celular.'),
      findsOneWidget,
    );
    expect(prefs.getString(claveSolicitudPendiente), isNull);
    final beto = await (db.select(
      db.usuarios,
    )..where((u) => u.idGlobal.equals('u-beto'))).getSingle();
    // El PIN escrito al pedir entrada queda guardado: entra sin internet.
    expect(beto.pinHash, isNotEmpty);
  });

  testWidgets('al rechazarlo vuelve a la bienvenida con el aviso', (
    tester,
  ) async {
    final prefs = await abrir(tester);
    await pedirEntrada(tester, codigoEscrito: codigo);
    final solicitud = (await admin.solicitudes(tienda)).single;

    await admin.responderSolicitud(
      tienda,
      solicitud.usuarioAuth,
      aprobar: false,
    );
    await esperarSondeo(tester);

    expect(find.byType(BienvenidaScreen), findsOneWidget);
    expect(
      find.text('El administrador no aprobó este celular.'),
      findsOneWidget,
    );
    expect(prefs.getString(claveSolicitudPendiente), isNull);
    expect(celular.sesion, isNull);
  });

  testWidgets('cancelar deja de esperar y cierra la sesión del celular', (
    tester,
  ) async {
    final prefs = await abrir(tester);
    await pedirEntrada(tester, codigoEscrito: codigo);

    await tester.tap(find.byKey(const Key('boton_cancelar_solicitud')));
    await tester.pumpAndSettle();

    expect(find.byType(BienvenidaScreen), findsOneWidget);
    expect(prefs.getString(claveSolicitudPendiente), isNull);
    expect(celular.sesion, isNull);
  });

  testWidgets('si la app se cerró mientras esperaba, sigue esperando', (
    tester,
  ) async {
    await celular.iniciarSesionCelular();
    await celular.solicitarIngreso(codigo, 1, '1234', 'Redmi');

    await abrir(tester, valores: {claveSolicitudPendiente: tienda});

    expect(find.byType(EsperandoAprobacionScreen), findsOneWidget);
  });

  testWidgets('si lo aprobaron con la app cerrada, al abrir baja la tienda', (
    tester,
  ) async {
    await celular.iniciarSesionCelular();
    await celular.solicitarIngreso(codigo, 1, '1234', 'Redmi');
    final solicitud = (await admin.solicitudes(tienda)).single;
    await admin.responderSolicitud(
      tienda,
      solicitud.usuarioAuth,
      aprobar: true,
    );

    await abrir(tester, valores: {claveSolicitudPendiente: tienda});
    await tester.pumpAndSettle();

    expect(find.byType(SeleccionarUsuarioScreen), findsOneWidget);
    final beto = await (db.select(
      db.usuarios,
    )..where((u) => u.idGlobal.equals('u-beto'))).getSingle();
    // Sin el PIN en memoria, su primer ingreso se revisa en línea.
    expect(beto.pinHash, isEmpty);
  });

  testWidgets('si se cerró tras bajar la tienda, no se queda esperando', (
    tester,
  ) async {
    await celular.iniciarSesionCelular();
    await celular.solicitarIngreso(codigo, 1, '1234', 'Redmi');
    final solicitud = (await admin.solicitudes(tienda)).single;
    await admin.responderSolicitud(
      tienda,
      solicitud.usuarioAuth,
      aprobar: true,
    );
    // La tienda alcanzó a bajar, pero la app se cerró antes de olvidar la
    // solicitud.
    await Sincronizador(db, celular).descargarTienda(tienda);

    final prefs = await abrir(
      tester,
      valores: {claveSolicitudPendiente: tienda},
    );
    await tester.pumpAndSettle();

    expect(find.byType(SeleccionarUsuarioScreen), findsOneWidget);
    expect(prefs.getString(claveSolicitudPendiente), isNull);
  });

  testWidgets('cancelar a mitad de una descarga no deja la tienda a medias', (
    tester,
  ) async {
    await celular.iniciarSesionCelular();
    await celular.solicitarIngreso(codigo, 1, '1234', 'Redmi');
    final solicitud = (await admin.solicitudes(tienda)).single;
    await admin.responderSolicitud(
      tienda,
      solicitud.usuarioAuth,
      aprobar: true,
    );
    // Una descarga que se cortó (sin internet): quedó el estado sin datos.
    celular.sinConexion = true;
    await db
        .into(db.estadoSincronizacion)
        .insert(
          EstadoSincronizacionCompanion.insert(
            id: const Value(1),
            tiendaId: tienda,
          ),
        );
    await abrir(tester, valores: {claveSolicitudPendiente: tienda});

    await tester.tap(find.byKey(const Key('boton_cancelar_solicitud')));
    await tester.pumpAndSettle();

    expect(await db.select(db.estadoSincronizacion).get(), isEmpty);
  });
}
