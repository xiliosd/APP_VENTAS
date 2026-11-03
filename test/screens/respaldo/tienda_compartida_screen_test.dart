import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/screens/respaldo/respaldo_screen.dart';
import 'package:app_ventas/screens/respaldo/verificar_correo_screen.dart';
import 'package:app_ventas/sincronizacion/nube_tienda.dart';
import 'package:app_ventas/sincronizacion/sincronizacion_provider.dart';
import 'package:app_ventas/sincronizacion/sincronizador.dart';
import 'package:app_ventas/ui/tema_app.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/respaldo_prueba.dart';
import '../../support/sincronizacion_prueba.dart';

void main() {
  late AppDatabase db;
  final navegador = GlobalKey<NavigatorState>();

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<ProviderContainer> abrirRespaldo(
    WidgetTester tester,
    SincronizacionFalsa sincronizacion,
  ) async {
    final container = await containerRespaldo(
      db,
      NubeRespaldoFalsa(conSesion: true, correo: 'tienda@gmail.com'),
      sincronizacion: () => sincronizacion,
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: temaClaro(), home: const RespaldoScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Future<NubeRespaldoFalsa> verificarCorreo(
    WidgetTester tester,
    SincronizacionFalsa sincronizacion,
    ModoVerificacion modo,
  ) async {
    final nube = NubeRespaldoFalsa();
    final container = await containerRespaldo(
      db,
      nube,
      habilitado: false,
      sincronizacion: () => sincronizacion,
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: temaClaro(),
          navigatorKey: navegador,
          home: const Scaffold(body: Text('Inicio')),
        ),
      ),
    );
    navegador.currentState!.push(
      MaterialPageRoute(builder: (_) => VerificarCorreoScreen(modo: modo)),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('campo_correo')),
      'tienda@gmail.com',
    );
    await tester.tap(find.text('Enviarme el código'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('campo_codigo')), '123456');
    await tester.tap(find.text('Verificar'));
    await tester.pumpAndSettle();
    return nube;
  }

  testWidgets('con respaldo activo ofrece usar la tienda en varios celulares', (
    tester,
  ) async {
    final sincronizacion = SincronizacionFalsa();
    await abrirRespaldo(tester, sincronizacion);

    await tester.ensureVisible(find.byKey(const Key('boton_compartir_tienda')));
    await tester.tap(find.byKey(const Key('boton_compartir_tienda')));
    await tester.pumpAndSettle();
    expect(find.text('¿Usar la tienda en varios celulares?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirmar_compartir')));
    await tester.pumpAndSettle();

    expect(sincronizacion.compartidas, 1);
    expect(find.byKey(const Key('tarjeta_sincronizacion')), findsOneWidget);
    expect(find.byKey(const Key('boton_compartir_tienda')), findsNothing);
  });

  testWidgets('si el correo ya tiene tienda compartida ofrece usarla aquí', (
    tester,
  ) async {
    final sincronizacion = SincronizacionFalsa(
      errorAlCompartir: const TiendaCompartidaExistente('t1'),
    );
    await abrirRespaldo(tester, sincronizacion);

    await tester.ensureVisible(find.byKey(const Key('boton_compartir_tienda')));
    await tester.tap(find.byKey(const Key('boton_compartir_tienda')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmar_compartir')));
    await tester.pumpAndSettle();

    expect(
      find.text('Este correo ya tiene una tienda compartida'),
      findsOneWidget,
    );
    await tester.tap(find.text('Usar la tienda compartida en este celular'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmar_descargar_tienda')));
    await tester.pumpAndSettle();

    expect(sincronizacion.compartidas, 0);
    expect(sincronizacion.descargas.single.tienda, 't1');
    expect(sincronizacion.descargas.single.reemplazarDatos, isTrue);
    expect(find.text('Tienda recuperada. Entra con tu PIN.'), findsOneWidget);
  });

  testWidgets('cancelar no comparte la tienda', (tester) async {
    final sincronizacion = SincronizacionFalsa();
    await abrirRespaldo(tester, sincronizacion);

    await tester.ensureVisible(find.byKey(const Key('boton_compartir_tienda')));
    await tester.tap(find.byKey(const Key('boton_compartir_tienda')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(sincronizacion.compartidas, 0);
  });

  final textos = {
    FaseSincronizacion.alDia: 'Al día',
    FaseSincronizacion.sincronizando: 'Sincronizando…',
    FaseSincronizacion.sinConexion:
        'Sin internet: se sube cuando vuelva la conexión',
    FaseSincronizacion.actualizarApp:
        'Actualiza la app para seguir sincronizando',
    FaseSincronizacion.error:
        'No se pudo sincronizar; se reintenta en un minuto',
  };
  for (final MapEntry(key: fase, value: texto) in textos.entries) {
    testWidgets('la tarjeta de la tienda compartida dice "$texto"', (
      tester,
    ) async {
      await abrirRespaldo(
        tester,
        SincronizacionFalsa(
          inicial: EstadoTiendaCompartida(
            fase: fase,
            ultimaSincronizacion: DateTime.now(),
            pendientes: 3,
          ),
        ),
      );

      expect(find.byKey(const Key('tarjeta_sincronizacion')), findsOneWidget);
      expect(find.text('Tienda compartida'), findsOneWidget);
      expect(find.textContaining(texto), findsOneWidget);
      expect(find.text('3 cambios por subir'), findsOneWidget);
      expect(find.byKey(const Key('boton_respaldar_ahora')), findsNothing);
      expect(find.byKey(const Key('boton_compartir_tienda')), findsNothing);
    });
  }

  testWidgets('Sincronizar ahora pide un ciclo', (tester) async {
    final sincronizacion = SincronizacionFalsa(
      inicial: const EstadoTiendaCompartida(fase: FaseSincronizacion.alDia),
    );
    await abrirRespaldo(tester, sincronizacion);

    await tester.tap(find.byKey(const Key('boton_sincronizar_ahora')));
    await tester.pumpAndSettle();

    expect(sincronizacion.sincronizaciones, greaterThanOrEqualTo(1));
  });

  testWidgets('restaurar con tienda compartida la descarga', (tester) async {
    final sincronizacion = SincronizacionFalsa(tienda: 't1');
    await verificarCorreo(tester, sincronizacion, ModoVerificacion.restaurar);

    expect(
      find.text('Se descargará la tienda compartida en este celular.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('confirmar_descargar_tienda')));
    await tester.pumpAndSettle();

    expect(sincronizacion.descargas.single.tienda, 't1');
    expect(sincronizacion.descargas.single.reemplazarDatos, isFalse);
    expect(find.text('Tienda recuperada. Entra con tu PIN.'), findsOneWidget);
    expect(find.text('Inicio'), findsOneWidget);
  });

  testWidgets('restaurar sin internet al descargar muestra el error', (
    tester,
  ) async {
    final sincronizacion = SincronizacionFalsa(
      tienda: 't1',
      errorAlDescargar: const ErrorSinConexion(),
    );
    await verificarCorreo(tester, sincronizacion, ModoVerificacion.restaurar);
    await tester.tap(find.byKey(const Key('confirmar_descargar_tienda')));
    await tester.pumpAndSettle();

    expect(
      find.text('Sin internet. Inténtalo cuando tengas conexión.'),
      findsOneWidget,
    );
  });

  testWidgets('restaurar sin tienda compartida usa el respaldo por archivo', (
    tester,
  ) async {
    final sincronizacion = SincronizacionFalsa();
    await verificarCorreo(tester, sincronizacion, ModoVerificacion.restaurar);

    expect(sincronizacion.descargas, isEmpty);
    expect(find.text('Respaldo restaurado. Entra con tu PIN.'), findsOneWidget);
  });

  testWidgets('activar con un correo que ya tiene tienda compartida ofrece '
      'usarla en este celular', (tester) async {
    final sincronizacion = SincronizacionFalsa(tienda: 't1');
    await verificarCorreo(tester, sincronizacion, ModoVerificacion.activar);

    expect(
      find.text('Este correo ya tiene una tienda compartida'),
      findsOneWidget,
    );
    await tester.tap(find.text('Usar la tienda compartida en este celular'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmar_descargar_tienda')));
    await tester.pumpAndSettle();

    expect(sincronizacion.descargas.single.reemplazarDatos, isTrue);
    expect(find.text('Tienda recuperada. Entra con tu PIN.'), findsOneWidget);
  });

  testWidgets('activar con tienda compartida y Cancelar desconecta', (
    tester,
  ) async {
    final sincronizacion = SincronizacionFalsa(tienda: 't1');
    final nube = await verificarCorreo(
      tester,
      sincronizacion,
      ModoVerificacion.activar,
    );

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(sincronizacion.descargas, isEmpty);
    expect(nube.haySesion, isFalse);
  });
}
