import 'package:sqlite3/sqlite3.dart';

import 'esquema_v8.dart';

/// Crea en [ruta] una base con el esquema v9 (pedido sugerido): el de v8 más
/// pedidos, sus líneas y la entrada de cada gasto (trae el cliente de v1).
void crearBaseV9(String ruta) {
  crearBaseV8(ruta);
  sqlite3.open(ruta)
    ..execute('''
      CREATE TABLE pedidos (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        proveedor_id INTEGER NOT NULL REFERENCES proveedores (id),
        usuario_id INTEGER NOT NULL REFERENCES usuarios (id),
        fecha INTEGER NOT NULL,
        estado TEXT NOT NULL DEFAULT 'porLlegar',
        entrada_id INTEGER NULL REFERENCES entradas_mercancia (id));
      CREATE TABLE lineas_pedido (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        pedido_id INTEGER NOT NULL REFERENCES pedidos (id),
        producto_id INTEGER NOT NULL REFERENCES productos (id),
        cantidad INTEGER NOT NULL, precio_esperado INTEGER NULL);
      ALTER TABLE gastos ADD COLUMN entrada_id INTEGER NULL
        REFERENCES entradas_mercancia (id);
    ''')
    ..userVersion = 9
    ..close();
}
