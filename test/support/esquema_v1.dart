import 'package:sqlite3/sqlite3.dart';

/// Crea en [ruta] una base con el esquema v1 de la app (antes de la 2D), con
/// un usuario, una venta de contado y un abono.
void crearBaseV1(String ruta) {
  sqlite3.open(ruta)
    ..execute('''
      CREATE TABLE usuarios (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL, rol TEXT NOT NULL, pin_hash TEXT NOT NULL);
      CREATE TABLE productos (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL, precio INTEGER NOT NULL,
        activo INTEGER NOT NULL DEFAULT 1 CHECK (activo IN (0, 1)));
      CREATE TABLE clientes (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL, telefono TEXT NULL, notas TEXT NULL);
      CREATE TABLE ventas (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        monto INTEGER NOT NULL, producto_id INTEGER NULL REFERENCES productos (id),
        fecha INTEGER NOT NULL,
        es_fiado INTEGER NOT NULL DEFAULT 0 CHECK (es_fiado IN (0, 1)),
        cliente_id INTEGER NULL REFERENCES clientes (id),
        usuario_id INTEGER NOT NULL REFERENCES usuarios (id));
      CREATE TABLE pagos_fiado (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        cliente_id INTEGER NOT NULL REFERENCES clientes (id),
        monto INTEGER NOT NULL, fecha INTEGER NOT NULL,
        usuario_id INTEGER NOT NULL REFERENCES usuarios (id));
      CREATE TABLE gastos (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        monto INTEGER NOT NULL, descripcion TEXT NULL, fecha INTEGER NOT NULL,
        usuario_id INTEGER NOT NULL REFERENCES usuarios (id));
      INSERT INTO usuarios (nombre, rol, pin_hash) VALUES ('Ana', 'admin', 'x');
      INSERT INTO clientes (nombre) VALUES ('Don Pedro');
      INSERT INTO ventas (monto, fecha, es_fiado, usuario_id)
        VALUES (5000, 1788000000, 0, 1);
      INSERT INTO pagos_fiado (cliente_id, monto, fecha, usuario_id)
        VALUES (1, 2000, 1788000000, 1);
    ''')
    ..userVersion = 1
    ..close();
}
