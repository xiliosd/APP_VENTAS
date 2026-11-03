import 'package:sqlite3/sqlite3.dart';

import 'esquema_v9.dart';

/// Crea en [ruta] una base con el esquema v10 (clientes con apellido): el de
/// v9 más `clientes.apellido` (trae el cliente de v1, sin apellido).
void crearBaseV10(String ruta) {
  crearBaseV9(ruta);
  sqlite3.open(ruta)
    ..execute('ALTER TABLE clientes ADD COLUMN apellido TEXT NULL;')
    ..userVersion = 10
    ..close();
}
