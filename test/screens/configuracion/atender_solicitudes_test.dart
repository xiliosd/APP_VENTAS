import 'package:app_ventas/screens/configuracion/atender_solicitudes.dart';
import 'package:app_ventas/sincronizacion/nube_tienda.dart';
import 'package:app_ventas/sincronizacion/sincronizacion_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/sincronizacion_prueba.dart';

void main() {
  final solicitud = CelularTienda(
    usuarioAuth: 'celular-1',
    rol: 'vendedor',
    estado: EstadoMiembro.pendiente,
    solicitadoEn: DateTime(2026, 11, 6, 9),
    nombreVendedor: 'Beto',
    nombreCelular: 'Redmi Note 13',
  );

  Future<SincronizacionFalsa> montar(WidgetTester tester) async {
    final sincronizacion = SincronizacionFalsa(
      inicial: EstadoTiendaCompartida(
        fase: FaseSincronizacion.alDia,
        solicitudes: [solicitud],
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sincronizacionProvider.overrideWith(() => sincronizacion)],
        child: const MaterialApp(
          home: AtenderSolicitudes(child: Scaffold(body: Text('Inicio'))),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return sincronizacion;
  }

  testWidgets('una solicitud abre el aviso y aprobarla la aprueba', (
    tester,
  ) async {
    final sincronizacion = await montar(tester);

    expect(
      find.text('Un celular nuevo quiere entrar como Beto'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Celular: Redmi Note 13. Apruébalo solo si es el celular de Beto.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('aprobar_solicitud')));
    await tester.pumpAndSettle();

    expect(sincronizacion.respuestas.single, ('celular-1', true));
    expect(find.text('Celular aprobado'), findsOneWidget);
    expect(find.text('Un celular nuevo quiere entrar como Beto'), findsNothing);
  });

  testWidgets('rechazar la solicitud la rechaza', (tester) async {
    final sincronizacion = await montar(tester);

    await tester.tap(find.byKey(const Key('rechazar_solicitud')));
    await tester.pumpAndSettle();

    expect(sincronizacion.respuestas.single, ('celular-1', false));
    expect(find.text('Celular rechazado'), findsOneWidget);
  });
}
