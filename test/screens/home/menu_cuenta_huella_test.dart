import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/huella_provider.dart';
import 'package:app_ventas/providers/sesion_provider.dart';
import 'package:app_ventas/repositories/configuracion_repository.dart';
import 'package:app_ventas/screens/home/home_screen.dart';
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

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    huella = HuellaFalsa();
    await ConfiguracionRepository(db).guardarNombreTienda('La Esquina');
  });
  tearDown(() => db.close());

  Future<ProviderContainer> montar(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final container = await containerConSesion(
      db,
      nombre: 'Beto',
      rol: 'vendedor',
      overrides: [autenticacionHuellaProvider.overrideWithValue(huella)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(appDePrueba(container, inicio: const HomeScreen()));
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> abrirMenu(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('menu_cuenta')));
    await tester.pumpAndSettle();
  }

  int yo(ProviderContainer container) =>
      container.read(sesionProvider).usuarioActivo!.id;

  testWidgets('un vendedor activa su huella desde su cuenta', (tester) async {
    final container = await montar(tester);

    await abrirMenu(tester);
    expect(find.text('Entrar con huella'), findsOneWidget);
    await tester.tap(find.byKey(const Key('menu_huella')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('activar_huella')));
    await tester.pumpAndSettle();

    expect(container.read(usuariosConHuellaProvider), contains(yo(container)));
    expect(huella.motivo, 'Confirma que eres Beto');
    expect(
      find.text('Listo: entras con tu huella en este celular'),
      findsOneWidget,
    );
  });

  testWidgets('con la huella activa el menú ofrece quitarla', (tester) async {
    final container = await montar(tester);
    await container
        .read(usuariosConHuellaProvider.notifier)
        .activar(yo(container));
    await tester.pumpAndSettle();

    await abrirMenu(tester);
    expect(find.text('Quitar la huella'), findsOneWidget);
    await tester.tap(find.byKey(const Key('menu_huella')));
    await tester.pumpAndSettle();

    expect(container.read(usuariosConHuellaProvider), isEmpty);
    expect(
      find.text('Ya no entras con huella en este celular'),
      findsOneWidget,
    );
  });

  testWidgets('sin lector de huella el menú no la ofrece', (tester) async {
    huella.hay = false;
    await montar(tester);

    await abrirMenu(tester);

    expect(find.byKey(const Key('menu_huella')), findsNothing);
  });

  testWidgets('si la huella no confirma, no se activa', (tester) async {
    huella.resultado = ResultadoHuella.cancelada;
    final container = await montar(tester);

    await abrirMenu(tester);
    await tester.tap(find.byKey(const Key('menu_huella')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('activar_huella')));
    await tester.pumpAndSettle();

    expect(container.read(usuariosConHuellaProvider), isEmpty);
  });
}
