import 'package:sqlite3/sqlite3.dart';

import 'esquema_v4.dart';

/// Crea en [ruta] una base con el esquema v5 de la app (4A, antes de la 4B):
/// el de v4 más proveedores, costo en líneas y nombre de la tienda, con un
/// producto.
void crearBaseV5(String ruta) {
  crearBaseV4(ruta);
  sqlite3.open(ruta)
    ..execute('''
      CREATE TABLE proveedores (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL, telefono TEXT NULL, notas TEXT NULL,
        activo INTEGER NOT NULL DEFAULT 1 CHECK (activo IN (0, 1)));
      CREATE TABLE productos_proveedores (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        producto_id INTEGER NOT NULL REFERENCES productos (id),
        proveedor_id INTEGER NOT NULL REFERENCES proveedores (id),
        precio_compra INTEGER NOT NULL,
        preferido INTEGER NOT NULL DEFAULT 0 CHECK (preferido IN (0, 1)),
        UNIQUE (producto_id, proveedor_id));
      ALTER TABLE lineas_venta ADD COLUMN costo_unitario INTEGER NULL;
      ALTER TABLE configuracion_tienda ADD COLUMN nombre_tienda TEXT NULL;
      INSERT INTO productos (nombre, precio) VALUES ('Arepa', 3500);
    ''')
    ..userVersion = 5
    ..close();
}
