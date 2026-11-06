import 'dart:io';
import 'dart:typed_data';

import 'package:app_ventas/data/database.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/esquema_v11.dart';
import '../support/esquema_v12.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<List<CambioPendiente>> pendientes() =>
      db.select(db.cambiosPendientes).get();

  Future<void> compartir({bool aplicando = false}) => db
      .into(db.estadoSincronizacion)
      .insert(
        EstadoSincronizacionCompanion.insert(
          id: const Value(1),
          tiendaId: 't',
          aplicando: Value(aplicando),
        ),
      );

  test('sin tienda compartida no se anota ningún cambio', () async {
    await db
        .into(db.clientes)
        .insert(ClientesCompanion.insert(nombre: 'Don Pedro'));

    expect(await pendientes(), isEmpty);
  });

  test('con tienda compartida se anotan altas, ediciones y borrados', () async {
    await compartir();
    final id = await db
        .into(db.clientes)
        .insert(ClientesCompanion.insert(nombre: 'Don Pedro'));
    final idGlobal = (await db.select(db.clientes).getSingle()).idGlobal;

    var cambio = (await pendientes()).single;
    expect(cambio.tabla, 'clientes');
    expect(cambio.idGlobal, idGlobal);
    expect(cambio.borrado, isFalse);
    expect(cambio.cambio, 1);

    await (db.update(db.clientes)..where((c) => c.id.equals(id))).write(
      const ClientesCompanion(telefono: Value('300')),
    );
    cambio = (await pendientes()).single;
    expect(cambio.cambio, 2);

    await db.customStatement('DELETE FROM clientes WHERE id = ?', [id]);
    cambio = (await pendientes()).single;
    expect(cambio.borrado, isTrue);
    expect(cambio.cambio, 3);
  });

  test('mientras se aplican cambios de la nube no se anota nada', () async {
    await compartir(aplicando: true);
    await db
        .into(db.clientes)
        .insert(ClientesCompanion.insert(nombre: 'Don Pedro'));

    expect(await pendientes(), isEmpty);
  });

  test("la configuración de la tienda se anota como 'unica'", () async {
    await compartir();
    await db
        .into(db.configuracionTienda)
        .insert(
          ConfiguracionTiendaCompanion.insert(
            id: const Value(1),
            imagenQr: Value(Uint8List.fromList([1])),
          ),
        );

    final cambio = (await pendientes()).single;
    expect(cambio.tabla, 'configuracion_tienda');
    expect(cambio.idGlobal, idGlobalConfiguracion);
  });

  test('una base v11 abre en v12 con los disparadores', () async {
    final carpeta = await Directory.systemTemp.createTemp('disparadores');
    addTearDown(() => carpeta.delete(recursive: true));
    final archivo = File('${carpeta.path}/v11.sqlite');
    crearBaseV11(archivo.path);
    final migrada = AppDatabase(NativeDatabase(archivo));

    final disparadores = await migrada
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'trigger' "
          "AND name LIKE 'sincronizar_%'",
        )
        .get();
    expect(disparadores, hasLength(47));
    expect(await migrada.select(migrada.cambiosPendientes).get(), isEmpty);
    expect(await migrada.select(migrada.estadoSincronizacion).get(), isEmpty);
    await migrada.close();
  });

  test('una base nueva también trae los disparadores', () async {
    final disparadores = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'trigger' "
          "AND name LIKE 'sincronizar_%'",
        )
        .get();
    expect(disparadores, hasLength(47));
  });

  test('guardar solo el PIN en este celular no se anota para subir', () async {
    await compartir();
    final id = await db
        .into(db.usuarios)
        .insert(
          UsuariosCompanion.insert(
            nombre: 'Beto',
            rol: 'vendedor',
            pinHash: '',
          ),
        );
    await db.delete(db.cambiosPendientes).go();

    await (db.update(db.usuarios)..where((u) => u.id.equals(id))).write(
      const UsuariosCompanion(pinHash: Value('guardado')),
    );
    expect(await pendientes(), isEmpty);

    await (db.update(db.usuarios)..where((u) => u.id.equals(id))).write(
      const UsuariosCompanion(nombre: Value('Beto B')),
    );
    expect((await pendientes()).single.tabla, 'usuarios');
  });

  test('una base v12 migrada tampoco anota el PIN guardado', () async {
    final carpeta = await Directory.systemTemp.createTemp('disp');
    addTearDown(() => carpeta.delete(recursive: true));
    final archivo = File('${carpeta.path}/v12.sqlite');
    crearBaseV12(archivo.path);
    final migrada = AppDatabase(NativeDatabase(archivo));
    addTearDown(migrada.close);
    await migrada
        .into(migrada.estadoSincronizacion)
        .insert(
          EstadoSincronizacionCompanion.insert(
            id: const Value(1),
            tiendaId: 't',
          ),
        );

    await migrada.customStatement("UPDATE usuarios SET pin_hash = 'otro'");

    expect(await migrada.select(migrada.cambiosPendientes).get(), isEmpty);
  });
}
