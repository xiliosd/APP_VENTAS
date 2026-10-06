import 'package:drift/drift.dart';

import '../data/database.dart';
import '../util/fecha_util.dart';

class VentaRepository {
  VentaRepository(this._db);

  final AppDatabase _db;

  Future<int> registrarVenta({
    required int monto,
    int? productoId,
    required bool esFiado,
    int? clienteId,
    required int usuarioId,
    DateTime? fecha,
    MedioPago medioPago = MedioPago.efectivo,
  }) {
    return _db.into(_db.ventas).insert(
          VentasCompanion.insert(
            monto: monto,
            productoId: Value(productoId),
            fecha: fecha ?? DateTime.now(),
            esFiado: Value(esFiado),
            clienteId: Value(clienteId),
            usuarioId: usuarioId,
            medioPago: Value(medioPago),
          ),
        );
  }

  Future<List<Venta>> ventasDelDia(DateTime dia, {int? usuarioId}) {
    final inicio = inicioDelDia(dia);
    final fin = finDelDia(dia);
    final query = _db.select(_db.ventas)
      ..where((v) =>
          v.fecha.isBiggerOrEqualValue(inicio) &
          v.fecha.isSmallerOrEqualValue(fin));
    if (usuarioId != null) {
      query.where((v) => v.usuarioId.equals(usuarioId));
    }
    return query.get();
  }

  /// Solo para "Deshacer" justo después de cobrar; no es una función de
  /// anular ventas pasadas.
  Future<void> eliminarVenta(int id) {
    return (_db.delete(_db.ventas)..where((v) => v.id.equals(id))).go();
  }
}
