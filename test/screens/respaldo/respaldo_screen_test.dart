import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/respaldo/nube_respaldo.dart';
import 'package:app_ventas/screens/respaldo/respaldo_screen.dart';
import 'package:app_ventas/screens/respaldo/verificar_telefono_screen.dart';
import 'package:app_ventas/ui/tema_app.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/respaldo_prueba.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> abrir(WidgetTester tester, NubeRespaldo? nube) async {
    final container = await containerRespaldo(db, nube);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: temaApp(), home: const RespaldoScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('sin configuración lo dice', (tester) async {
    await abrir(tester, null);
    expect(find.text('Respaldo no configurado'), findsOneWidget);
  });

  testWidgets('desactivado ofrece activarlo', (tester) async {
    await abrir(tester, NubeRespaldoFalsa());

    await tester.tap(find.byKey(const Key('boton_activar_respaldo')));
    await tester.pumpAndSettle();

    expect(find.byType(VerificarTelefonoScreen), findsOneWidget);
  });

  testWidgets('activo muestra el número, el último respaldo y permite '
      'respaldar y desconectar', (tester) async {
    final nube = NubeRespaldoFalsa(conSesion: true, telefono: '+573001234567');
    await abrir(tester, nube);

    expect(find.text('Celular: +57 300 *** 4567'), findsOneWidget);
    expect(find.textContaining('Último respaldo: hoy'), findsOneWidget);

    await tester.tap(find.byKey(const Key('boton_respaldar_ahora')));
    await tester.pumpAndSettle();
    expect(nube.subidas, 2);
    expect(find.text('Respaldo guardado'), findsOneWidget);

    await tester.tap(find.byKey(const Key('boton_desconectar')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('boton_activar_respaldo')), findsOneWidget);
  });

  testWidgets('sesión vencida pide reconectar', (tester) async {
    final nube = NubeRespaldoFalsa(conSesion: true)
      ..errorAlSubir = const ErrorSesionRespaldo();
    await abrir(tester, nube);

    expect(find.text('Reconecta el respaldo'), findsOneWidget);
    expect(find.byKey(const Key('boton_reconectar')), findsOneWidget);
  });
}
