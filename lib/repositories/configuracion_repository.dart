import 'package:drift/drift.dart';

import '../data/database.dart';

/// Mensaje de error para un nombre de tienda, o null si es válido.
String? errorNombreTienda(String nombre) {
  final limpio = nombre.trim();
  if (limpio.isEmpty) return 'Escribe el nombre de tu tienda';
  if (limpio.length > 40) return 'Máximo 40 caracteres';
  return null;
}

/// Configuración de la tienda (una sola fila, id 1): nombre y QR de cobro.
class ConfiguracionRepository {
  ConfiguracionRepository(this._db);

  final AppDatabase _db;

  static const _id = 1;

  SimpleSelectStatement<$ConfiguracionTiendaTable, ConfiguracionTiendaFila>
      get _fila => _db.select(_db.configuracionTienda)
        ..where((c) => c.id.equals(_id));

  Future<Uint8List?> imagenQr() async =>
      (await _fila.getSingleOrNull())?.imagenQr;

  Stream<Uint8List?> observarImagenQr() =>
      _fila.watchSingleOrNull().map((fila) => fila?.imagenQr);

  Future<void> guardarImagenQr(Uint8List bytes) =>
      _db.into(_db.configuracionTienda).insertOnConflictUpdate(
            ConfiguracionTiendaCompanion.insert(
                id: const Value(_id), imagenQr: Value(bytes)),
          );

  Future<void> quitarImagenQr() =>
      _db.into(_db.configuracionTienda).insertOnConflictUpdate(
            const ConfiguracionTiendaCompanion(
                id: Value(_id), imagenQr: Value(null)),
          );

  Future<String?> nombreTienda() async =>
      (await _fila.getSingleOrNull())?.nombreTienda;

  Stream<String?> observarNombreTienda() =>
      _fila.watchSingleOrNull().map((fila) => fila?.nombreTienda);

  /// Guarda [nombre] sin espacios sobrantes; no toca el QR.
  Future<void> guardarNombreTienda(String nombre) async {
    final error = errorNombreTienda(nombre);
    if (error != null) throw ArgumentError(error);
    await _db.into(_db.configuracionTienda).insertOnConflictUpdate(
          ConfiguracionTiendaCompanion(
              id: const Value(_id), nombreTienda: Value(nombre.trim())),
        );
  }
}
