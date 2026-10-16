import 'package:sqlite3/sqlite3.dart';

import 'esquema_v7.dart';

/// Crea en [ruta] una base con el esquema v8 (código de barras): el de v7 más
/// código, marca, tamaño, envase y tipo (trae el gasto de v2).
void crearBaseV8(String ruta) {
  crearBaseV7(ruta);
  sqlite3.open(ruta)
    ..execute('ALTER TABLE productos ADD COLUMN codigo_barras TEXT NULL;')
    ..execute('ALTER TABLE productos ADD COLUMN marca TEXT NULL;')
    ..execute('ALTER TABLE productos ADD COLUMN tamano TEXT NULL;')
    ..execute('ALTER TABLE productos ADD COLUMN envase TEXT NULL;')
    ..execute('ALTER TABLE productos ADD COLUMN tipo TEXT NULL;')
    ..userVersion = 8
    ..close();
}
