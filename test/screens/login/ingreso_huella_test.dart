import 'dart:async';

import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/huella_provider.dart';
import 'package:app_ventas/providers/sesion_provider.dart';
import 'package:app_ventas/screens/login/ingresar_pin_screen.dart';
import 'package:app_ventas/servicios/autenticacion_huella.dart';
import 'package:app_ventas/ui/tema_app.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/huella_falsa.dart';
import '../../support/montaje.dart';

/// Hash de "1234".
const _pin1234 =
    '03ac674216f3e15c761ee1a5e255f067953623c8b388b4459e13f978d7c846f4';

void main() {
  late AppDatabase db;
  late HuellaFalsa huella;
  late ProviderContainer container;
  late Usuario ana;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    huella = HuellaFalsa();
  });
  tearDown(() => db.close());

  Future<void> abrir(
    WidgetTester tester, {
    bool activada = true,
    ThemeData? tema,
    double escala = 1,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final id = await db
        .into(db.usuarios)
        .insert(
          UsuariosCompanion.insert(
            nombre: 'Ana',
            rol: 'admin',
            pinHash: _pin1234,
          ),
        );
    ana = await (db.select(
      db.usuarios,
    )..where((u) => u.id.equals(id))).getSingle();
    container = await containerConSesion(
      db,
      nombre: 'Otro',
      overrides: [autenticacionHuellaProvider.overrideWithValue(huella)],
    );
    addTearDown(container.dispose);
    container.read(sesionProvider.notifier).cerrarSesion();
    if (activada) {
      await container.read(usuariosConHuellaProvider.notifier).activar(id);
    }
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: tema,
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(escala)),
              child: IngresarPinScreen(usuario: ana),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tocarHuella(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const Key('boton_huella')));
    await tester.tap(find.byKey(const Key('boton_huella')));
    await tester.pumpAndSettle();
  }

  testWidgets('sin activarla no hay botón de huella', (tester) async {
    await abrir(tester, activada: false);
    expect(find.byKey(const Key('boton_huella')), findsNothing);
  });

  testWidgets('sin biometría en el celular no hay botón', (tester) async {
    huella.hay = false;
    await abrir(tester);
    expect(find.byKey(const Key('boton_huella')), findsNothing);
  });

  testWidgets('la huella aprobada abre la sesión', (tester) async {
    await abrir(tester);

    expect(find.text('Entrar con huella'), findsOneWidget);
    expect(find.byTooltip('Entrar con huella'), findsOneWidget);
    await tocarHuella(tester);

    expect(huella.motivo, 'Confirma que eres Ana');
    expect(container.read(sesionProvider).usuarioActivo?.id, ana.id);
  });

  testWidgets('cancelar no cambia nada', (tester) async {
    huella.resultado = ResultadoHuella.cancelada;
    await abrir(tester);
    await tocarHuella(tester);

    expect(container.read(sesionProvider).haySesion, isFalse);
    expect(find.textContaining('usa tu PIN'), findsNothing);
  });

  testWidgets('bloqueo y falta de huellas dicen que use el PIN', (
    tester,
  ) async {
    huella.resultado = ResultadoHuella.bloqueada;
    await abrir(tester);
    await tocarHuella(tester);
    expect(
      find.text('Demasiados intentos con la huella: usa tu PIN'),
      findsOneWidget,
    );

    huella.resultado = ResultadoHuella.sinHuellas;
    await tocarHuella(tester);
    expect(
      find.text('Este celular ya no tiene huellas registradas: usa tu PIN'),
      findsOneWidget,
    );
    expect(container.read(sesionProvider).haySesion, isFalse);
  });

  testWidgets('dos toques seguidos piden la huella una sola vez', (
    tester,
  ) async {
    huella.pendiente = Completer();
    await abrir(tester);
    await tester.ensureVisible(find.byKey(const Key('boton_huella')));

    await tester.tap(find.byKey(const Key('boton_huella')));
    await tester.tap(find.byKey(const Key('boton_huella')));
    huella.pendiente!.complete(ResultadoHuella.aprobada);
    await tester.pumpAndSettle();

    expect(huella.llamadas, 1);
    expect(container.read(sesionProvider).haySesion, isTrue);
  });

  testWidgets('con el botón visible el PIN sigue funcionando', (tester) async {
    await abrir(tester);

    for (final digito in ['1', '2', '3', '4']) {
      await tester.tap(find.byKey(Key('tecla_$digito')));
      await tester.pumpAndSettle();
    }

    expect(container.read(sesionProvider).usuarioActivo?.id, ana.id);
    expect(huella.llamadas, 0);
  });

  testWidgets('en oscuro con letra 2,0× el botón no desborda', (tester) async {
    await abrir(tester, tema: temaOscuro(), escala: 2);

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('boton_huella')), findsOneWidget);
  });

  test(
    'entrar con huella a un usuario que ya no existe falla y lo olvida',
    () async {
      final c = await containerConSesion(db);
      addTearDown(c.dispose);
      await c.read(usuariosConHuellaProvider.notifier).activar(99);

      final ok = await c
          .read(sesionProvider.notifier)
          .iniciarSesionConHuella(99);

      expect(ok, isFalse);
      expect(c.read(usuariosConHuellaProvider), isNot(contains(99)));
    },
  );

  test('la huella no abre a un usuario que no la activó', () async {
    final c = await containerConSesion(db);
    addTearDown(c.dispose);
    final otro = c.read(sesionProvider).usuarioActivo!;
    c.read(sesionProvider.notifier).cerrarSesion();

    final ok = await c
        .read(sesionProvider.notifier)
        .iniciarSesionConHuella(otro.id);

    expect(ok, isFalse);
    expect(c.read(sesionProvider).haySesion, isFalse);
  });
}
