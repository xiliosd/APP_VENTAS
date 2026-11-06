import 'package:app_ventas/screens/configuracion/celulares_tienda_screen.dart';
import 'package:app_ventas/sincronizacion/nube_tienda.dart';
import 'package:app_ventas/sincronizacion/sincronizacion_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/sincronizacion_prueba.dart';

void main() {
  CelularTienda celular(
    String auth,
    String rol,
    EstadoMiembro estado, {
    String? nombre,
  }) => CelularTienda(
    usuarioAuth: auth,
    rol: rol,
    estado: estado,
    solicitadoEn: DateTime(2026, 11, 6),
    nombreVendedor: nombre,
    nombreCelular: rol == 'admin' ? null : 'Redmi',
  );

  Future<SincronizacionFalsa> montar(WidgetTester tester) async {
    final sincronizacion = SincronizacionFalsa(
      inicial: const EstadoTiendaCompartida(fase: FaseSincronizacion.alDia),
      celularesTienda: [
        celular('admin', 'admin', EstadoMiembro.aprobado),
        celular('c1', 'vendedor', EstadoMiembro.pendiente, nombre: 'Beto'),
        celular('c2', 'vendedor', EstadoMiembro.aprobado, nombre: 'Caro'),
        celular('c3', 'vendedor', EstadoMiembro.rechazado, nombre: 'Dani'),
        celular('c4', 'vendedor', EstadoMiembro.revocado, nombre: 'Eva'),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sincronizacionProvider.overrideWith(() => sincronizacion)],
        child: const MaterialApp(home: CelularesTiendaScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return sincronizacion;
  }

  testWidgets('lista los celulares con su estado y el código', (tester) async {
    await montar(tester);

    expect(find.text('Código de la tienda: ABC234'), findsOneWidget);
    expect(find.text('Tú (administrador)'), findsOneWidget);
    for (final texto in [
      'Esperando',
      'Con acceso',
      'Rechazado',
      'Sin acceso',
    ]) {
      expect(find.text(texto), findsOneWidget, reason: texto);
    }
    expect(find.byKey(const Key('quitar_acceso_c2')), findsOneWidget);
    expect(find.byKey(const Key('quitar_acceso_c3')), findsNothing);
  });

  testWidgets('Quitar acceso pide confirmación y revoca el celular', (
    tester,
  ) async {
    final sincronizacion = await montar(tester);

    await tester.tap(find.byKey(const Key('quitar_acceso_c2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmar_quitar_acceso')));
    await tester.pumpAndSettle();

    expect(sincronizacion.revocaciones, ['c2']);
  });

  testWidgets('aprueba y rechaza desde la lista', (tester) async {
    final sincronizacion = await montar(tester);

    await tester.tap(find.byKey(const Key('aprobar_c1')));
    await tester.pumpAndSettle();

    expect(sincronizacion.respuestas, [('c1', true)]);
  });
}
