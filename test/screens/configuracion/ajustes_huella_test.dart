import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/huella_provider.dart';
import 'package:app_ventas/providers/sesion_provider.dart';
import 'package:app_ventas/screens/configuracion/ajustes_screen.dart';
import 'package:app_ventas/servicios/autenticacion_huella.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/huella_falsa.dart';
import '../../support/montaje.dart';

void main() {
  late AppDatabase db;
  late HuellaFalsa huella;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    huella = HuellaFalsa();
  });
  tearDown(() => db.close());

  Future<void> montar(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    container = await containerConSesion(
      db,
      overrides: [autenticacionHuellaProvider.overrideWithValue(huella)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      appDePrueba(container, inicio: const Scaffold(body: AjustesScreen())),
    );
    await tester.pumpAndSettle();
  }

  int yo() => container.read(sesionProvider).usuarioActivo!.id;

  Future<void> tocarInterruptor(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.byKey(const Key('interruptor_huella')),
      200,
    );
    await tester.ensureVisible(find.byKey(const Key('interruptor_huella')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('interruptor_huella')));
    await tester.pumpAndSettle();
  }

  testWidgets('sin biometría en el celular no aparece la fila', (tester) async {
    huella.hay = false;
    await montar(tester);
    expect(find.byKey(const Key('interruptor_huella')), findsNothing);
  });

  testWidgets('aparece en CUENTA, apagada', (tester) async {
    await montar(tester);
    await tester.scrollUntilVisible(
      find.byKey(const Key('interruptor_huella')),
      200,
    );

    expect(find.text('Entrar con huella'), findsOneWidget);
    expect(
      tester
          .widget<SwitchListTile>(find.byKey(const Key('interruptor_huella')))
          .value,
      isFalse,
    );
  });

  testWidgets('encenderla avisa; Cancelar no la activa', (tester) async {
    await montar(tester);
    await tocarInterruptor(tester);

    expect(
      find.text(
        'Cualquier huella registrada en este celular podrá abrir '
        'tu usuario. Actívalo solo si el celular es tuyo.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('cancelar_huella')));
    await tester.pumpAndSettle();

    expect(huella.llamadas, 0);
    expect(container.read(usuariosConHuellaProvider), isEmpty);
  });

  testWidgets('Activar y confirmar la huella la deja activada', (tester) async {
    await montar(tester);
    await tocarInterruptor(tester);
    await tester.tap(find.byKey(const Key('activar_huella')));
    await tester.pumpAndSettle();

    expect(huella.llamadas, 1);
    expect(container.read(usuariosConHuellaProvider), {yo()});
    expect(
      tester
          .widget<SwitchListTile>(find.byKey(const Key('interruptor_huella')))
          .value,
      isTrue,
    );
  });

  testWidgets('si no confirma la huella no queda activada', (tester) async {
    huella.resultado = ResultadoHuella.cancelada;
    await montar(tester);
    await tocarInterruptor(tester);
    await tester.tap(find.byKey(const Key('activar_huella')));
    await tester.pumpAndSettle();

    expect(container.read(usuariosConHuellaProvider), isEmpty);
  });

  testWidgets('apagarla la desactiva sin pedir nada', (tester) async {
    await montar(tester);
    await container.read(usuariosConHuellaProvider.notifier).activar(yo());
    await tester.pumpAndSettle();

    await tocarInterruptor(tester);

    expect(huella.llamadas, 0);
    expect(container.read(usuariosConHuellaProvider), isEmpty);
  });
}
