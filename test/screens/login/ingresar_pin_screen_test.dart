import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/database_provider.dart';
import 'package:app_ventas/providers/sesion_provider.dart';
import 'package:app_ventas/screens/login/ingresar_pin_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('PIN correcto abre sesión y PIN incorrecto muestra error',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final usuarioId = await db.into(db.usuarios).insert(
          UsuariosCompanion.insert(
            nombre: 'Ana',
            rol: 'admin',
            pinHash:
                '03ac674216f3e15c761ee1a5e255f067953623c8b388b4459e13f978d7c846f4', // "1234"
          ),
        );
    final usuario = (await db.select(db.usuarios).get()).single;

    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: IngresarPinScreen(usuario: usuario)),
      ),
    );
    expect(tester.widget<Text>(find.text('Hola, Ana')).style?.fontFamily,
        'Nunito');

    for (final digito in ['0', '0', '0', '0']) {
      await tester.tap(find.byKey(Key('tecla_$digito')));
      await tester.pumpAndSettle();
    }
    expect(find.text('PIN incorrecto'), findsOneWidget);
    expect(container.read(sesionProvider).haySesion, isFalse);

    for (final digito in ['1', '2', '3', '4']) {
      await tester.tap(find.byKey(Key('tecla_$digito')));
      await tester.pumpAndSettle();
    }
    expect(container.read(sesionProvider).haySesion, isTrue);
    expect(container.read(sesionProvider).usuarioActivo?.id, usuarioId);
  });

  testWidgets('PIN correcto cierra la pantalla cuando fue empujada al stack',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.into(db.usuarios).insert(
          UsuariosCompanion.insert(
            nombre: 'Ana',
            rol: 'admin',
            pinHash:
                '03ac674216f3e15c761ee1a5e255f067953623c8b388b4459e13f978d7c846f4', // "1234"
          ),
        );
    final usuario = (await db.select(db.usuarios).get()).single;

    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              key: const Key('pantalla_host'),
              body: ElevatedButton(
                key: const Key('boton_abrir_pin'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => IngresarPinScreen(usuario: usuario),
                  ),
                ),
                child: const Text('Abrir PIN'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('boton_abrir_pin')));
    await tester.pumpAndSettle();
    expect(find.byType(IngresarPinScreen), findsOneWidget);

    for (final digito in ['1', '2', '3', '4']) {
      await tester.tap(find.byKey(Key('tecla_$digito')));
      await tester.pumpAndSettle();
    }

    expect(container.read(sesionProvider).haySesion, isTrue);
    expect(find.byType(IngresarPinScreen), findsNothing);
    expect(find.byKey(const Key('pantalla_host')), findsOneWidget);
  });
}
