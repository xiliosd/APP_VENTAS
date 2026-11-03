import 'package:app_ventas/data/database.dart' show tablasConIdGlobal;
import 'package:sqlite3/sqlite3.dart';

import 'esquema_v10.dart';

/// Crea en [ruta] una base con el esquema v11 (identificadores globales): el
/// de v10 más `id_global` con su índice único en cada tabla sincronizable.
void crearBaseV11(String ruta) {
  crearBaseV10(ruta);
  final base = sqlite3.open(ruta);
  var contador = 0;
  for (final tabla in tablasConIdGlobal) {
    base.execute(
      "ALTER TABLE $tabla ADD COLUMN id_global TEXT NOT NULL DEFAULT ''",
    );
    for (final fila in base.select('SELECT id FROM $tabla')) {
      contador++;
      base.execute('UPDATE $tabla SET id_global = ? WHERE id = ?', [
        'v11-$tabla-$contador',
        fila['id'],
      ]);
    }
    base.execute(
      'CREATE UNIQUE INDEX ${tabla}_id_global ON $tabla (id_global)',
    );
  }
  base
    ..userVersion = 11
    ..close();
}
