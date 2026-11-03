import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/respaldo/restaurador.dart';
import 'package:app_ventas/screens/respaldo/verificar_correo_screen.dart';
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
      MaterialPageRoute(builder: (_) => VerificarCorreoScreen(modo: modo)),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> enviarCodigo(
    WidgetTester tester, {
    String correo = ' Tienda@Gmail.com ',
  }) async {
    await tester.enterText(find.byKey(const Key('campo_correo')), correo);
    await tester.tap(find.byKey(const Key('boton_enviar_codigo')));
    await tester.pumpAndSettle();
  }

  Future<void> enviarYVerificar(
    WidgetTester tester, {
    String codigo = '123456',
  }) async {
    await enviarCodigo(tester);
    await tester.enterText(find.byKey(const Key('campo_codigo')), codigo);
    await tester.tap(find.byKey(const Key('boton_verificar')));
    await tester.pumpAndSettle();
  }

  testWidgets('el campo de correo usa el teclado y el autollenado de correo', (
    tester,
  ) async {
    await abrir(tester, NubeRespaldoFalsa());

    final campo = tester.widget<TextField>(
      find.byKey(const Key('campo_correo')),
    );
    expect(campo.keyboardType, TextInputType.emailAddress);
    expect(campo.autofillHints, contains(AutofillHints.email));
    expect(campo.decoration?.labelText, 'Correo');
  });

  testWidgets('un correo inválido muestra error y no envía código', (
    tester,
  ) async {
    final nube = NubeRespaldoFalsa();
    await abrir(tester, nube);

    await enviarCodigo(tester, correo: 'tiendagmail.com');

    expect(
      find.text('Escribe un correo válido, como tienda@gmail.com'),
      findsOneWidget,
    );
    expect(nube.enviados, isEmpty);
    expect(find.byKey(const Key('campo_codigo')), findsNothing);
  });

  testWidgets('tras enviar muestra el correo enmascarado y el aviso de spam', (
    tester,
  ) async {
    await abrir(tester, NubeRespaldoFalsa());

    await enviarCodigo(tester);

    expect(find.textContaining('ti***@gmail.com'), findsOneWidget);
    expect(
      find.textContaining('Revisa tu correo (también la carpeta de spam)'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('campo_codigo')), findsOneWidget);
  });

  testWidgets('un código de menos de 6 o más de 8 dígitos no se verifica', (
    tester,
  ) async {
    final nube = NubeRespaldoFalsa();
    await abrir(tester, nube);
    await enviarCodigo(tester);

    for (final codigo in ['12345', '12a456']) {
      await tester.enterText(find.byKey(const Key('campo_codigo')), codigo);
      await tester.tap(find.byKey(const Key('boton_verificar')));
      await tester.pumpAndSettle();
      expect(find.text('El código tiene de 6 a 8 dígitos'), findsOneWidget);
    }
    final campo = tester.widget<TextField>(
      find.byKey(const Key('campo_codigo')),
    );
    expect(campo.maxLength, 8);
    expect(nube.haySesion, isFalse);
  });

  testWidgets('acepta un código de 8 dígitos', (tester) async {
    final nube = NubeRespaldoFalsa(codigoValido: '12345678');
    await abrir(tester, nube);

    await enviarYVerificar(tester, codigo: '12345678');

    expect(nube.subidas, 1);
    expect(find.text('Respaldo activado'), findsOneWidget);
  });

  testWidgets(
    'código incorrecto muestra error; el correcto activa y respalda',
    (tester) async {
      final nube = NubeRespaldoFalsa();
      await abrir(tester, nube);

      await enviarYVerificar(tester, codigo: '000000');
      expect(nube.enviados, ['tienda@gmail.com']);
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
    final nube = NubeRespaldoFalsa();
    await abrir(tester, nube);
    await enviarCodigo(tester);

    TextButton reenviar() =>
        tester.widget<TextButton>(find.byKey(const Key('boton_reenviar')));
    expect(reenviar().onPressed, isNull);

    await tester.pump(const Duration(seconds: 61));
    expect(reenviar().onPressed, isNotNull);

    await tester.tap(find.byKey(const Key('boton_reenviar')));
    await tester.pumpAndSettle();
    expect(nube.enviados, ['tienda@gmail.com', 'tienda@gmail.com']);
    expect(reenviar().onPressed, isNull);
    await tester.pump(const Duration(seconds: 61));
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
      find.text('No encontramos un respaldo para este correo'),
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
    expect(find.byType(VerificarCorreoScreen), findsOneWidget);
  });
}
