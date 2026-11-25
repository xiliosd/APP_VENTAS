import 'dart:async';

import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/screens/agregar_celular/paso_mostrar.dart';
import 'package:app_ventas/screens/configuracion/atender_solicitudes.dart';
import 'package:app_ventas/sincronizacion/nube_tienda.dart';
import 'package:app_ventas/sincronizacion/sincronizacion_provider.dart';
import 'package:app_ventas/ui/tema_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../support/sincronizacion_prueba.dart';

/// Falla al pedir el código de la tienda, como sin internet.
class _SincronizacionSinCodigo extends SincronizacionFalsa {
  _SincronizacionSinCodigo() : super(inicial: _alDia);

  @override
  Future<String> codigoTienda() async => throw const ErrorSinConexion();
}

/// Responde a la solicitud solo cuando el test lo decide.
class _SincronizacionLenta extends SincronizacionFalsa {
  _SincronizacionLenta({super.celularesTienda = const []})
    : super(inicial: _alDia);

  final respuesta = Completer<void>();

  @override
  Future<void> responderSolicitud(
    CelularTienda solicitud, {
    required bool aprobar,
  }) async {
    await respuesta.future;
    await super.responderSolicitud(solicitud, aprobar: aprobar);
  }
}

const _alDia = EstadoTiendaCompartida(fase: FaseSincronizacion.alDia);

CelularTienda _celular(
  String auth, {
  String idGlobal = 'g-beto',
  EstadoMiembro estado = EstadoMiembro.aprobado,
}) => CelularTienda(
  usuarioAuth: auth,
  rol: 'vendedor',
  estado: estado,
  solicitadoEn: DateTime(2026, 11, 20),
  nombreVendedor: 'Beto',
  nombreCelular: 'Redmi Note 13',
  usuarioIdGlobal: idGlobal,
);

CelularTienda _pendiente(String auth, {String idGlobal = 'g-beto'}) =>
    _celular(auth, idGlobal: idGlobal, estado: EstadoMiembro.pendiente);

void main() {
  const vendedor = Usuario(
    idGlobal: 'g-beto',
    id: 1,
    nombre: 'Beto',
    rol: 'vendedor',
    pinHash: 'hash-del-pin-1234',
    activo: true,
    numeroVendedor: 3,
    versionPin: 1,
    manejaCatalogo: false,
  );

  Future<void> montar(
    WidgetTester tester,
    SincronizacionFalsa sincronizacion, {
    bool cambiaCelular = false,
    double letra = 1.0,
    bool conAviso = false,
  }) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final paso = PasoMostrar(vendedor: vendedor, cambiaCelular: cambiaCelular);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sincronizacionProvider.overrideWith(() => sincronizacion)],
        child: MaterialApp(
          theme: temaClaro(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(letra)),
            child: child!,
          ),
          home: conAviso
              ? AtenderSolicitudes(
                  child: Builder(
                    builder: (context) => Scaffold(
                      body: Center(
                        child: TextButton(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => Scaffold(body: paso),
                            ),
                          ),
                          child: const Text('Abrir'),
                        ),
                      ),
                    ),
                  ),
                )
              : Scaffold(body: paso),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('muestra el QR, el código y el número, nunca el PIN', (
    tester,
  ) async {
    await montar(tester, SincronizacionFalsa(inicial: _alDia));
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('ABC234'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('1234'), findsNothing);
    expect(
      find.text('Su PIN es el que le diste (no se muestra aquí).'),
      findsOneWidget,
    );
    expect(find.text('Esperando que Beto escanee…'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Código QR para unir el celular de Beto',
      ),
      findsOneWidget,
    );
  });

  testWidgets('cuando el vendedor pide entrar se aprueba aquí', (tester) async {
    final sincronizacion = SincronizacionFalsa(inicial: _alDia);
    await montar(tester, sincronizacion);
    sincronizacion.ponerSolicitudes([_pendiente('auth-nuevo')]);
    await tester.pumpAndSettle();
    expect(find.text('Beto pide entrar desde Redmi Note 13'), findsOneWidget);

    await tester.tap(find.byKey(const Key('aprobar_aqui')));
    await tester.pumpAndSettle();

    expect(sincronizacion.respuestas, [('auth-nuevo', true)]);
    expect(
      find.text('¡Listo! Beto ya puede vender desde su celular'),
      findsOneWidget,
    );
    expect(find.text('Terminar'), findsOneWidget);
  });

  testWidgets('si la aprobación falla no revoca el celular anterior', (
    tester,
  ) async {
    final sincronizacion = SincronizacionFalsa(
      inicial: _alDia,
      errorAlResponder: const ErrorSinConexion(),
      celularesTienda: [_celular('auth-viejo')],
    );
    await montar(tester, sincronizacion, cambiaCelular: true);
    sincronizacion.ponerSolicitudes([_pendiente('auth-nuevo')]);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('aprobar_aqui')));
    await tester.pumpAndSettle();

    expect(sincronizacion.revocaciones, isEmpty);
    expect(
      find.text('Sin internet. Inténtalo cuando tengas conexión.'),
      findsOneWidget,
    );
    expect(find.textContaining('¡Listo!'), findsNothing);
  });

  testWidgets('al cambiar de celular revoca solo el anterior', (tester) async {
    final sincronizacion = SincronizacionFalsa(
      inicial: _alDia,
      celularesTienda: [
        _celular('auth-viejo'),
        _celular('auth-nuevo'),
        _celular('auth-de-cata', idGlobal: 'g-cata'),
      ],
    );
    await montar(tester, sincronizacion, cambiaCelular: true);
    sincronizacion.ponerSolicitudes([_pendiente('auth-nuevo')]);
    await tester.pumpAndSettle();
    expect(
      find.text('Su celular anterior dejará de tener los datos de la tienda.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('aprobar_aqui')));
    await tester.pumpAndSettle();

    expect(sincronizacion.revocaciones, ['auth-viejo']);
  });

  testWidgets('la solicitud de otro vendedor no aparece aquí', (tester) async {
    final sincronizacion = SincronizacionFalsa(inicial: _alDia);
    await montar(tester, sincronizacion);
    sincronizacion.ponerSolicitudes([
      _pendiente('auth-cata', idGlobal: 'g-cata'),
    ]);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('aprobar_aqui')), findsNothing);
    expect(find.text('Esperando que Beto escanee…'), findsOneWidget);
  });

  testWidgets('mientras está abierto el aviso global no sale y al cerrar sí', (
    tester,
  ) async {
    final sincronizacion = SincronizacionFalsa(inicial: _alDia);
    await montar(tester, sincronizacion, conAviso: true);
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    sincronizacion.ponerSolicitudes([
      _pendiente('auth-cata', idGlobal: 'g-cata'),
    ]);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);

    Navigator.of(tester.element(find.byType(PasoMostrar))).pop();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('sin internet al pedir el código muestra el mensaje', (
    tester,
  ) async {
    await montar(tester, _SincronizacionSinCodigo());
    expect(
      find.text('Sin internet. Inténtalo cuando tengas conexión.'),
      findsOneWidget,
    );
    expect(find.text('Reintentar'), findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);
  });

  testWidgets('sincroniza cada 5 segundos mientras está abierto', (
    tester,
  ) async {
    final sincronizacion = SincronizacionFalsa(inicial: _alDia);
    await montar(tester, sincronizacion);
    await tester.pump(const Duration(seconds: 11));
    expect(sincronizacion.sincronizaciones, greaterThanOrEqualTo(2));
  });

  testWidgets('a letra 2,0× en 360 dp no desborda', (tester) async {
    final sincronizacion = SincronizacionFalsa(inicial: _alDia);
    await montar(tester, sincronizacion, cambiaCelular: true, letra: 2.0);
    sincronizacion.ponerSolicitudes([_pendiente('auth-nuevo')]);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(const Key('aprobar_aqui')), 200);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no se puede volver mientras se aprueba', (tester) async {
    final sincronizacion = _SincronizacionLenta();
    await montar(tester, sincronizacion, conAviso: true);
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    sincronizacion.ponerSolicitudes([_pendiente('auth-nuevo')]);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('aprobar_aqui')));
    await tester.pump();

    await Navigator.of(tester.element(find.byType(PasoMostrar))).maybePop();
    await tester.pump();
    expect(find.byType(PasoMostrar), findsOneWidget);

    sincronizacion.respuesta.complete();
    await tester.pumpAndSettle();
    expect(find.textContaining('¡Listo!'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('si se cierra a medio aprobar igual revoca el anterior', (
    tester,
  ) async {
    final sincronizacion = _SincronizacionLenta(
      celularesTienda: [_celular('auth-viejo'), _celular('auth-nuevo')],
    );
    await montar(tester, sincronizacion, cambiaCelular: true);
    sincronizacion.ponerSolicitudes([_pendiente('auth-nuevo')]);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('aprobar_aqui')));
    await tester.pump();

    // Se desmonta todo, como si la pantalla se cerrara a la fuerza.
    await tester.pumpWidget(const SizedBox());
    sincronizacion.respuesta.complete();
    await tester.pumpAndSettle();

    expect(sincronizacion.revocaciones, ['auth-viejo']);
    expect(tester.takeException(), isNull);
  });
}
