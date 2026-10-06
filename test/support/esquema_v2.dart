import 'package:sqlite3/sqlite3.dart';

import 'esquema_v1.dart';

/// Crea en [ruta] una base con el esquema v2 de la app (2D, antes de la 3A):
/// el de v1 más medio de pago y configuración de la tienda, y además un gasto.
void crearBaseV2(String ruta) {
  crearBaseV1(ruta);
  sqlite3.open(ruta)
    ..execute('''
      ALTER TABLE ventas ADD COLUMN medio_pago TEXT NOT NULL DEFAULT 'efectivo';
      ALTER TABLE pagos_fiado ADD COLUMN medio_pago TEXT NOT NULL DEFAULT 'efectivo';
      CREATE TABLE configuracion_tienda (id INTEGER NOT NULL,
        imagen_qr BLOB NULL, PRIMARY KEY (id));
      INSERT INTO gastos (monto, descripcion, fecha, usuario_id)
        VALUES (1500, 'Hielo', 1788000000, 1);
    ''')
    ..userVersion = 2
    ..close();
}
