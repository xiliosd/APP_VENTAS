import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/database_provider.dart';
import 'package:app_ventas/providers/sesion_provider.dart';
import 'package:app_ventas/sincronizacion/supabase_nube_tienda.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/nube_tienda_falsa.dart';

void main() {
  test(
    'iniciarSesion con PIN correcto actualiza el estado y devuelve true',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final usuarioId = await db
          .into(db.usuarios)
          .insert(
            UsuariosCompanion.insert(
              nombre: 'Ana',
              rol: 'admin',
              pinHash: '03ac674216f3e15c761ee1a5e255f067953623c8b388b4459e13f978d7c846f4', // sha256("1234")
            ),
          );

      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);

      final ok = await container
          .read(sesionProvider.notifier)
          .iniciarSesion(usuarioId, '1234');

      expect(ok, ResultadoIngreso.ok);
      expect(container.read(sesionProvider).haySesion, isTrue);
      expect(container.read(sesionProvider).esAdmin, isTrue);
    },
  );

  test(
    'iniciarSesion con PIN incorrecto no cambia el estado y devuelve false',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final usuarioId = await db
          .into(db.usuarios)
          .insert(
            UsuariosCompanion.insert(
              nombre: 'Ana',
              rol: 'admin',
              pinHash: 'otro-hash',
            ),
          );

      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);

      final ok = await container
          .read(sesionProvider.notifier)
          .iniciarSesion(usuarioId, '0000');

      expect(ok, ResultadoIngreso.pinIncorrecto);
      expect(container.read(sesionProvider).haySesion, isFalse);
    },
  );

  test('cerrarSesion limpia el usuario activo', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final usuarioId = await db
        .into(db.usuarios)
        .insert(
          UsuariosCompanion.insert(
            nombre: 'Ana',
            rol: 'vendedor',
            pinHash: '03ac674216f3e15c761ee1a5e255f067953623c8b388b4459e13f978d7c846f4',
          ),
        );

    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    await container
        .read(sesionProvider.notifier)
        .iniciarSesion(usuarioId, '1234');
    container.read(sesionProvider.notifier).cerrarSesion();

    expect(container.read(sesionProvider).haySesion, isFalse);
  });

  group('primer ingreso en un celular de la tienda compartida', () {
    late AppDatabase db;
    late NubeTiendaFalsa nube;
    late ProviderContainer container;
    late int beto;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      nube = NubeTiendaFalsa();
      final tienda = await nube.crearTienda('La Esquina');
      await nube.guardarPin(tienda, 'u-beto', '1234', 0);
      // Llegó de la nube: sin PIN guardado en este celular.
      beto = await db
          .into(db.usuarios)
          .insert(
            UsuariosCompanion.insert(
              idGlobal: const Value('u-beto'),
              nombre: 'Beto',
              rol: 'vendedor',
              pinHash: '',
            ),
          );
      await db
          .into(db.estadoSincronizacion)
          .insert(
            EstadoSincronizacionCompanion.insert(
              id: const Value(1),
              tiendaId: tienda,
            ),
          );
      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          nubeTiendaProvider.overrideWithValue(nube),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    SesionNotifier sesion() => container.read(sesionProvider.notifier);

    test('con internet entra y la próxima vez entra sin internet', () async {
      expect(await sesion().iniciarSesion(beto, '1234'), ResultadoIngreso.ok);
      expect(container.read(sesionProvider).usuarioActivo?.nombre, 'Beto');

      sesion().cerrarSesion();
      nube.sinConexion = true;

      expect(await sesion().iniciarSesion(beto, '1234'), ResultadoIngreso.ok);
    });

    test('sin internet pide conectarse y no cuenta como PIN malo', () async {
      nube.sinConexion = true;

      expect(
        await sesion().iniciarSesion(beto, '1234'),
        ResultadoIngreso.necesitaInternet,
      );
      expect(container.read(sesionProvider).haySesion, isFalse);
    });

    test('un PIN malo revisado en línea es PIN incorrecto', () async {
      expect(
        await sesion().iniciarSesion(beto, '0000'),
        ResultadoIngreso.pinIncorrecto,
      );
      expect(container.read(sesionProvider).haySesion, isFalse);
    });

    test('tras cinco PIN malos en línea queda bloqueado', () async {
      for (var i = 0; i < 5; i++) {
        await sesion().iniciarSesion(beto, '0000');
      }

      expect(
        await sesion().iniciarSesion(beto, '1234'),
        ResultadoIngreso.bloqueado,
      );
    });
  });

  test('un usuario desactivado no entra aunque su PIN sea bueno', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final id = await db
        .into(db.usuarios)
        .insert(
          UsuariosCompanion.insert(
            nombre: 'Beto',
            rol: 'vendedor',
            pinHash: '03ac674216f3e15c761ee1a5e255f067953623c8b388b4459e13f978d7c846f4',
            activo: const Value(false),
          ),
        );
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    expect(
      await container.read(sesionProvider.notifier).iniciarSesion(id, '1234'),
      ResultadoIngreso.inactivo,
    );
  });

  test('en una tienda no compartida un PIN vacío no entra', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final id = await db
        .into(db.usuarios)
        .insert(
          UsuariosCompanion.insert(
            nombre: 'Beto',
            rol: 'vendedor',
            pinHash: '',
          ),
        );
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    expect(
      await container.read(sesionProvider.notifier).iniciarSesion(id, '1234'),
      ResultadoIngreso.pinIncorrecto,
    );
  });
}
