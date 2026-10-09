import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/respaldo/restaurador.dart';
import 'package:app_ventas/screens/respaldo/verificar_telefono_screen.dart';
import 'package:app_ventas/ui/tema_app.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/respaldo_prueba.dart';

void main() {
  late AppDatabase db;
  final navegador = GlobalKey<NavigatorState>();

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<ProviderContainer> abrir(
    WidgetTester tester,
    NubeRespaldoFalsa nube, {
    ModoVerificacion modo = ModoVerificacion.activar,
    RestauradorFalso? restaurador,
  }) async {
    final container = await containerRespaldo(
      db,
      nube,
      restaurador: restaurador,
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
      MaterialPageRoute(builder: (_) => VerificarTelefonoScreen(modo: modo)),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> enviarYVerificar(
    WidgetTester tester, {
    String codigo = '123456',
  }) async {
    await tester.enterText(
      find.byKey(const Key('campo_telefono')),
      '3001234567',
    );
    await tester.tap(find.byKey(const Key('boton_enviar_codigo')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('campo_codigo')), codigo);
    await tester.tap(find.byKey(const Key('boton_verificar')));
    await tester.pumpAndSettle();
  }

  testWidgets('un celular inválido muestra error y no envía código', (
    tester,
  ) async {
    final nube = NubeRespaldoFalsa();
    await abrir(tester, nube);

    await tester.enterText(
      find.byKey(const Key('campo_telefono')),
      '6011234567',
    );
    await tester.tap(find.byKey(const Key('boton_enviar_codigo')));
    await tester.pumpAndSettle();

    expect(
      find.text('Escribe un celular de 10 dígitos que empiece por 3'),
      findsOneWidget,
    );
    expect(nube.enviados, isEmpty);
  });

  testWidgets(
    'código incorrecto muestra error; el correcto activa y respalda',
    (tester) async {
      final nube = NubeRespaldoFalsa();
      await abrir(tester, nube);

      await enviarYVerificar(tester, codigo: '000000');
      expect(nube.enviados, ['+573001234567']);
      expect(find.text('Código incorrecto o vencido'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('campo_codigo')), '123456');
      await tester.tap(find.byKey(const Key('boton_verificar')));
      await tester.pumpAndSettle();

      expect(nube.subidas, 1);
      expect(find.text('Inicio'), findsOneWidget);
      expect(find.text('Respaldo activado'), findsOneWidget);
    },
  );

  testWidgets('Reenviar código se habilita a los 60 segundos', (tester) async {
    await abrir(tester, NubeRespaldoFalsa());
    await tester.enterText(
      find.byKey(const Key('campo_telefono')),
      '3001234567',
    );
    await tester.tap(find.byKey(const Key('boton_enviar_codigo')));
    await tester.pumpAndSettle();

    TextButton reenviar() =>
        tester.widget<TextButton>(find.byKey(const Key('boton_reenviar')));
    expect(reenviar().onPressed, isNull);

    await tester.pump(const Duration(seconds: 61));
    expect(reenviar().onPressed, isNotNull);
  });

  testWidgets('con respaldo existente, Cancelar cierra sesión sin subir nada', (
    tester,
  ) async {
    final nube = NubeRespaldoFalsa(fecha: DateTime(2026, 10, 3, 14, 32));
    await abrir(tester, nube);

    await enviarYVerificar(tester);
    expect(find.textContaining('03/10/2026 14:32'), findsOneWidget);
    await tester.tap(find.byKey(const Key('boton_cancelar_existente')));
    await tester.pumpAndSettle();

    expect(nube.subidas, 0);
    expect(nube.haySesion, isFalse);
    expect(find.text('Inicio'), findsOneWidget);
  });

  testWidgets('con respaldo existente, Reemplazar sube la copia de este '
      'celular', (tester) async {
    final nube = NubeRespaldoFalsa(fecha: DateTime(2026, 10, 3, 14, 32));
    await abrir(tester, nube);

    await enviarYVerificar(tester);
    await tester.tap(find.byKey(const Key('boton_reemplazar_existente')));
    await tester.pumpAndSettle();

    expect(nube.subidas, 1);
    expect(find.text('Respaldo activado'), findsOneWidget);
  });

  testWidgets(
    'con respaldo existente, Restaurar pide confirmación y restaura',
    (tester) async {
      final nube = NubeRespaldoFalsa(fecha: DateTime(2026, 10, 3, 14, 32));
      final restaurador = RestauradorFalso(ResultadoRestauracion.restaurado);
      await abrir(tester, nube, restaurador: restaurador);

      await enviarYVerificar(tester);
      await tester.tap(find.byKey(const Key('boton_restaurar_existente')));
      await tester.pumpAndSettle();
      expect(
        find.text('Se reemplazarán los datos de este celular'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('boton_confirmar_restaurar')));
      await tester.pumpAndSettle();

      expect(restaurador.llamadas, 1);
      expect(
        find.text('Respaldo restaurado. Entra con tu PIN.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('restaurar sin respaldo avisa y vuelve atrás', (tester) async {
    final restaurador = RestauradorFalso(ResultadoRestauracion.sinRespaldo);
    await abrir(
      tester,
      NubeRespaldoFalsa(),
      modo: ModoVerificacion.restaurar,
      restaurador: restaurador,
    );

    await enviarYVerificar(tester);

    expect(
      find.text('No encontramos un respaldo para este número'),
      findsOneWidget,
    );
    expect(find.text('Inicio'), findsOneWidget);
  });

  testWidgets('restaurar un respaldo dañado muestra el error y no sale', (
    tester,
  ) async {
    final restaurador = RestauradorFalso(ResultadoRestauracion.invalido);
    await abrir(
      tester,
      NubeRespaldoFalsa(),
      modo: ModoVerificacion.restaurar,
      restaurador: restaurador,
    );

    await enviarYVerificar(tester);

    expect(
      find.text(
        'El respaldo no se pudo leer; tus datos actuales no se tocaron',
      ),
      findsOneWidget,
    );
    expect(find.byType(VerificarTelefonoScreen), findsOneWidget);
  });
}
