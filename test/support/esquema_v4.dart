import 'package:sqlite3/sqlite3.dart';

import 'esquema_v3.dart';

/// Crea en [ruta] una base con el esquema v4 de la app (3C, antes de la 4A):
/// el de v3 más `lineas_venta`, con una línea para la venta existente.
void crearBaseV4(String ruta) {
  crearBaseV3(ruta);
  sqlite3.open(ruta)
    ..execute('''
      CREATE TABLE lineas_venta (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        venta_id INTEGER NOT NULL REFERENCES ventas (id),
        producto_id INTEGER NULL REFERENCES productos (id),
        descripcion TEXT NOT NULL, precio_unitario INTEGER NOT NULL,
        cantidad INTEGER NOT NULL);
      INSERT INTO lineas_venta (venta_id, descripcion, precio_unitario, cantidad)
        VALUES (1, '\$5.000', 5000, 1);
    ''')
    ..userVersion = 4
    ..close();
}
