import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import '../data/database.dart';

/// Crea y valida copias completas de la base de la app.
abstract final class CopiaBaseDatos {
  /// Tablas que debe tener una copia para considerarse de esta app.
  static const tablas = [
    'usuarios',
    'productos',
    'clientes',
    'ventas',
    'pagos_fiado',
    'gastos',
  ];

  /// Copia consistente de [db] (aunque esté abierta) en [temporal]. Siempre
  /// usa el mismo nombre, así que reemplaza la copia anterior.
  static Future<File> crearCopia(AppDatabase db, Directory temporal) async {
    final destino = File(p.join(temporal.path, 'respaldo_app_ventas.sqlite'));
    if (await destino.exists()) await destino.delete();
    await db.customStatement('VACUUM INTO ?', [destino.path]);
    return destino;
  }

  /// true si [archivo] es una base SQLite de esta app con versión de esquema
  /// no mayor que [versionMaxima].
  static bool esCopiaValida(File archivo, {required int versionMaxima}) {
    if (!archivo.existsSync()) return false;
    Database? bd;
    try {
      bd = sqlite3.open(archivo.path, mode: OpenMode.readOnly);
      final existentes = bd
          .select("SELECT name FROM sqlite_master WHERE type = 'table'")
          .map((fila) => fila['name'] as String)
          .toSet();
      if (!tablas.every(existentes.contains)) return false;
      return bd.userVersion <= versionMaxima;
    } on SqliteException {
      return false;
    } finally {
      bd?.close();
    }
  }
}
