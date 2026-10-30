import 'package:app_ventas/screens/escaner/consejos_escaner.dart';
import 'package:app_ventas/ui/recorrido/globos.dart';
import 'package:app_ventas/ui/recorrido/objetivo_recorrido.dart';
import 'package:app_ventas/ui/tema_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('el consejo se muestra sin saltar y Entendido lo cierra', (
    tester,
  ) async {
    late BuildContext contexto;
    var toques = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: temaClaro(),
        home: Scaffold(
          body: Builder(
            builder: (c) {
              contexto = c;
              return ObjetivoRecorrido(
                id: 'boton_escanear_venta',
                child: ElevatedButton(
                  onPressed: () => toques++,
                  child: const Text('Esc'),
                ),
              );
            },
          ),
        ),
      ),
    );
    final ctrl = mostrarConsejo(contexto, consejoEscanearVenta);
    await tester.pumpAndSettle();
    expect(find.text(consejoEscanearVenta.texto), findsOneWidget);
    expect(find.byKey(const Key('boton_entendido_consejo')), findsOneWidget);
    expect(find.byKey(const Key('boton_saltar_recorrido')), findsNothing);
    expect(find.byKey(const Key('boton_siguiente_globo')), findsNothing);

    // El velo deja pasar el toque dentro del hueco.
    await tester.tap(find.text('Esc'));
    expect(toques, 1);

    await tester.tap(find.byKey(const Key('boton_entendido_consejo')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('capa_globos')), findsNothing);
    expect(ctrl.activo, isFalse);
  });
}
