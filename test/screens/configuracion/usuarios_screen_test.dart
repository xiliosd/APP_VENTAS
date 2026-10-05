import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/database_provider.dart';
import 'package:app_ventas/repositories/usuario_repository.dart';
import 'package:app_ventas/screens/configuracion/usuarios_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> montar(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: UsuariosScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('crear un usuario sin tocar el rol crea un vendedor',
      (tester) async {
    await montar(tester);
    expect(find.text('Agregar usuario'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('campo_nombre_usuario')), 'Beto');
    await tester.enterText(find.byKey(const Key('campo_pin_usuario')), '4321');
    await tester.tap(find.byKey(const Key('boton_crear_usuario')));
    await tester.pumpAndSettle();

    final usuarios = await db.select(db.usuarios).get();
    expect(usuarios.single.nombre, 'Beto');
    expect(usuarios.single.rol, 'vendedor');
    expect(find.text('Beto'), findsOneWidget);
  });

  testWidgets('elegir Administrador en el selector crea un admin',
      (tester) async {
    await montar(tester);

    await tester.enterText(find.byKey(const Key('campo_nombre_usuario')), 'Carla');
    await tester.enterText(find.byKey(const Key('campo_pin_usuario')), '1111');
    await tester.tap(find.text('Administrador'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('boton_crear_usuario')));
    await tester.pumpAndSettle();

    final usuarios = await db.select(db.usuarios).get();
    expect(usuarios.single.rol, 'admin');
  });

  testWidgets('PIN inválido al crear muestra error y no crea el usuario',
      (tester) async {
    await montar(tester);

    await tester.enterText(find.byKey(const Key('campo_nombre_usuario')), 'Beto');
    await tester.enterText(find.byKey(const Key('campo_pin_usuario')), '12');
    await tester.tap(find.byKey(const Key('boton_crear_usuario')));
    await tester.pumpAndSettle();

    expect(find.text('El PIN debe tener 4 dígitos'), findsOneWidget);
    expect(await db.select(db.usuarios).get(), isEmpty);
  });

  testWidgets('resetear el PIN de un usuario guarda el nuevo PIN',
      (tester) async {
    final repo = UsuarioRepository(db);
    final id = await repo.crearUsuario(nombre: 'Beto', rol: 'vendedor', pin: '1111');
    await montar(tester);

    await tester.tap(find.byKey(Key('usuario_item_$id')));
    await tester.pumpAndSettle();
    expect(find.text('Resetear PIN de Beto'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('campo_nuevo_pin')), '9999');
    await tester.tap(find.byKey(const Key('boton_guardar_pin')));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('PIN actualizado'), findsOneWidget);
    expect(await repo.verificarPin(id, '9999'), isNotNull);
    expect(await repo.verificarPin(id, '1111'), isNull);
  });

  testWidgets('PIN inválido en el reseteo muestra error y no cierra el diálogo',
      (tester) async {
    final repo = UsuarioRepository(db);
    final id = await repo.crearUsuario(nombre: 'Beto', rol: 'vendedor', pin: '1111');
    await montar(tester);

    await tester.tap(find.byKey(Key('usuario_item_$id')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('campo_nuevo_pin')), '12a4');
    await tester.tap(find.byKey(const Key('boton_guardar_pin')));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('El PIN debe tener 4 dígitos'), findsOneWidget);
    expect(await repo.verificarPin(id, '1111'), isNotNull);
  });
}
