import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/database_provider.dart';
import 'package:app_ventas/providers/sesion_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iniciarSesion con PIN correcto actualiza el estado y devuelve true', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final usuarioId = await db.into(db.usuarios).insert(
          UsuariosCompanion.insert(
            nombre: 'Ana',
            rol: 'admin',
            pinHash:
                '03ac674216f3e15c761ee1a5e255f067953623c8b388b4459e13f978d7c846f4', // sha256("1234")
          ),
        );

    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    final ok = await container
        .read(sesionProvider.notifier)
        .iniciarSesion(usuarioId, '1234');

    expect(ok, isTrue);
    expect(container.read(sesionProvider).haySesion, isTrue);
    expect(container.read(sesionProvider).esAdmin, isTrue);
  });

  test('iniciarSesion con PIN incorrecto no cambia el estado y devuelve false', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final usuarioId = await db.into(db.usuarios).insert(
          UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'otro-hash'),
        );

    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    final ok = await container
        .read(sesionProvider.notifier)
        .iniciarSesion(usuarioId, '0000');

    expect(ok, isFalse);
    expect(container.read(sesionProvider).haySesion, isFalse);
  });

  test('cerrarSesion limpia el usuario activo', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final usuarioId = await db.into(db.usuarios).insert(
          UsuariosCompanion.insert(
            nombre: 'Ana',
            rol: 'vendedor',
            pinHash:
                '03ac674216f3e15c761ee1a5e255f067953623c8b388b4459e13f978d7c846f4',
          ),
        );

    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    await container.read(sesionProvider.notifier).iniciarSesion(usuarioId, '1234');
    container.read(sesionProvider.notifier).cerrarSesion();

    expect(container.read(sesionProvider).haySesion, isFalse);
  });
}
