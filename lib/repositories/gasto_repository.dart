import 'package:drift/drift.dart';

import '../data/database.dart';
import '../util/fecha_util.dart';

class GastoRepository {
  GastoRepository(this._db);

  final AppDatabase _db;

  Future<int> registrarGasto({
    required int monto,
    String? descripcion,
    required int usuarioId,
    DateTime? fecha,
  }) {
    return _db.into(_db.gastos).insert(
          GastosCompanion.insert(
            monto: monto,
            descripcion: Value(descripcion),
            fecha: fecha ?? DateTime.now(),
            usuarioId: usuarioId,
          ),
        );
  }

  /// Gastos de [dia]. Lo anulado solo viene con [incluirAnulados], para
  /// mostrarlo en el Historial; nunca debe sumarse.
  Future<List<Gasto>> gastosDelDia(
    DateTime dia, {
    int? usuarioId,
    bool incluirAnulados = false,
  }) {
    final inicio = inicioDelDia(dia);
    final fin = finDelDia(dia);
    final query = _db.select(_db.gastos)
      ..where((g) =>
          g.fecha.isBiggerOrEqualValue(inicio) &
          g.fecha.isSmallerOrEqualValue(fin));
    if (usuarioId != null) {
      query.where((g) => g.usuarioId.equals(usuarioId));
    }
    if (!incluirAnulados) {
      query.where((g) => g.anulado.equals(false));
    }
    return query.get();
  }
}
