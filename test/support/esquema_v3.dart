import 'package:sqlite3/sqlite3.dart';

import 'esquema_v2.dart';

/// Crea en [ruta] una base con el esquema v3 de la app (3A/3B, antes de la
/// 3C): el de v2 más `anulado` y la tabla `correcciones`.
void crearBaseV3(String ruta) {
  crearBaseV2(ruta);
  sqlite3.open(ruta)
    ..execute('''
      ALTER TABLE ventas ADD COLUMN anulado INTEGER NOT NULL DEFAULT 0
        CHECK (anulado IN (0, 1));
      ALTER TABLE pagos_fiado ADD COLUMN anulado INTEGER NOT NULL DEFAULT 0
        CHECK (anulado IN (0, 1));
      ALTER TABLE gastos ADD COLUMN anulado INTEGER NOT NULL DEFAULT 0
        CHECK (anulado IN (0, 1));
      CREATE TABLE correcciones (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        tipo_movimiento TEXT NOT NULL, movimiento_id INTEGER NOT NULL,
        accion TEXT NOT NULL,
        usuario_id INTEGER NOT NULL REFERENCES usuarios (id),
        fecha INTEGER NOT NULL, antes TEXT NOT NULL);
    ''')
    ..userVersion = 3
    ..close();
}
