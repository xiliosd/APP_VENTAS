import 'package:sqlite3/sqlite3.dart';

import 'esquema_v12.dart';

/// Crea en [ruta] una base con el esquema v13 (vendedores con celular): el de
/// v12 más `activo`, `numero_vendedor` y `version_pin` en `usuarios`, con el
/// disparador de edición de usuarios tal como quedó en v13.
void crearBaseV13(String ruta) {
  crearBaseV12(ruta);
  sqlite3.open(ruta)
    ..execute(
      'ALTER TABLE usuarios ADD COLUMN activo INTEGER NOT NULL DEFAULT 1 '
      'CHECK (activo IN (0, 1))',
    )
    ..execute('ALTER TABLE usuarios ADD COLUMN numero_vendedor INTEGER NULL')
    ..execute(
      'ALTER TABLE usuarios ADD COLUMN version_pin INTEGER NOT NULL DEFAULT 0',
    )
    ..execute('DROP TRIGGER IF EXISTS sincronizar_usuarios_edicion')
    ..execute(
      'CREATE TRIGGER sincronizar_usuarios_edicion AFTER UPDATE OF '
      'id_global, nombre, rol, activo, numero_vendedor, version_pin '
      'ON usuarios WHEN EXISTS (SELECT 1 FROM estado_sincronizacion '
      'WHERE id = 1 AND aplicando = 0) '
      'BEGIN INSERT INTO cambios_pendientes (tabla, id_global, borrado, cambio) '
      "VALUES ('usuarios', NEW.id_global, 0, 1) "
      'ON CONFLICT (tabla, id_global) DO UPDATE SET '
      'borrado = excluded.borrado, cambio = cambios_pendientes.cambio + 1; END',
    )
    ..userVersion = 13
    ..close();
}
