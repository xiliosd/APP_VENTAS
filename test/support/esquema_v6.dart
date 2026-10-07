import 'package:sqlite3/sqlite3.dart';

import 'esquema_v5.dart';

/// Crea en [ruta] una base con el esquema v6 de la app (4B, antes de la 4C):
/// el de v5 más control de existencias, conteos y entradas de mercancía.
void crearBaseV6(String ruta) {
  crearBaseV5(ruta);
  sqlite3.open(ruta)
    ..execute('''
      ALTER TABLE productos ADD COLUMN controla_existencias INTEGER NOT NULL
        DEFAULT 0 CHECK (controla_existencias IN (0, 1));
      ALTER TABLE productos ADD COLUMN minimo INTEGER NOT NULL DEFAULT 0;
      CREATE TABLE conteos_inventario (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        producto_id INTEGER NOT NULL REFERENCES productos (id),
        cantidad INTEGER NOT NULL, anterior INTEGER NULL, tipo TEXT NOT NULL,
        nota TEXT NULL, usuario_id INTEGER NOT NULL REFERENCES usuarios (id),
        fecha INTEGER NOT NULL);
      CREATE TABLE entradas_mercancia (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        proveedor_id INTEGER NOT NULL REFERENCES proveedores (id),
        usuario_id INTEGER NOT NULL REFERENCES usuarios (id),
        fecha INTEGER NOT NULL, total INTEGER NOT NULL, nota TEXT NULL,
        anulada INTEGER NOT NULL DEFAULT 0 CHECK (anulada IN (0, 1)),
        anulada_por_id INTEGER NULL REFERENCES usuarios (id));
      CREATE TABLE lineas_entrada (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        entrada_id INTEGER NOT NULL REFERENCES entradas_mercancia (id),
        producto_id INTEGER NOT NULL REFERENCES productos (id),
        cantidad INTEGER NOT NULL, precio_compra INTEGER NOT NULL);
      UPDATE productos SET controla_existencias = 1, minimo = 5;
    ''')
    ..userVersion = 6
    ..close();
}
