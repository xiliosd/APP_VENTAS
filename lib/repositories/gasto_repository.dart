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

  Future<List<Gasto>> gastosDelDia(DateTime dia, {int? usuarioId}) {
    final inicio = inicioDelDia(dia);
    final fin = finDelDia(dia);
    final query = _db.select(_db.gastos)
      ..where((g) =>
          g.fecha.isBiggerOrEqualValue(inicio) &
          g.fecha.isSmallerOrEqualValue(fin));
    if (usuarioId != null) {
      query.where((g) => g.usuarioId.equals(usuarioId));
    }
    return query.get();
  }
}
