import 'package:app_ventas/data/database.dart' show tablasConIdGlobal;
import 'package:app_ventas/data/disparadores_sincronizacion.dart';
import 'package:sqlite3/sqlite3.dart';

import 'esquema_v11.dart';

/// Crea en [ruta] una base con el esquema v12 (tienda compartida): el de v11
/// más las tablas de sincronización y sus disparadores.
void crearBaseV12(String ruta) {
  crearBaseV11(ruta);
  final base = sqlite3.open(ruta)
    ..execute(
      'CREATE TABLE cambios_pendientes ('
      'id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
      'tabla TEXT NOT NULL, id_global TEXT NOT NULL, '
      'borrado INTEGER NOT NULL CHECK (borrado IN (0, 1)), '
      'cambio INTEGER NOT NULL DEFAULT 1, UNIQUE (tabla, id_global))',
    )
    ..execute(
      'CREATE TABLE estado_sincronizacion ('
      'id INTEGER NOT NULL, tienda_id TEXT NOT NULL, '
      'cursor INTEGER NOT NULL DEFAULT 0, '
      'aplicando INTEGER NOT NULL DEFAULT 0 CHECK (aplicando IN (0, 1)), '
      'ultima_sincronizacion INTEGER NULL, PRIMARY KEY (id))',
    );
  for (final sentencia in sentenciasDisparadores(tablasConIdGlobal)) {
    base.execute(sentencia);
  }
  base
    ..userVersion = 12
    ..close();
}
