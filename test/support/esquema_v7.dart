import 'package:sqlite3/sqlite3.dart';

import 'esquema_v6.dart';

/// Crea en [ruta] una base con el esquema v7 (4C): el de v6 más "pedir hasta".
void crearBaseV7(String ruta) {
  crearBaseV6(ruta);
  sqlite3.open(ruta)
    ..execute('ALTER TABLE productos ADD COLUMN pedir_hasta INTEGER NULL;')
    ..userVersion = 7
    ..close();
}
