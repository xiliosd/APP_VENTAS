import 'package:drift/drift.dart';

import '../data/database.dart';

/// Configuración de la tienda (una sola fila, id 1). Por ahora, el QR de cobro.
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
}
