import 'package:drift/drift.dart';

import '../data/database.dart';
import '../util/fecha_util.dart';

/// Una línea de un ticket por guardar con su venta.
class LineaNueva {
  const LineaNueva({
    this.productoId,
    required this.descripcion,
    required this.precioUnitario,
    required this.cantidad,
  });

  /// null = monto suelto.
  final int? productoId;
  final String descripcion;
  final int precioUnitario;
  final int cantidad;

  int get subtotal => precioUnitario * cantidad;
}

class VentaRepository {
  VentaRepository(this._db);

  final AppDatabase _db;

  /// Guarda la venta y sus [lineas] en una transacción. Con líneas, [monto]
  /// debe ser su suma.
  Future<int> registrarVenta({
    required int monto,
    int? productoId,
    required bool esFiado,
    int? clienteId,
    required int usuarioId,
    DateTime? fecha,
    MedioPago medioPago = MedioPago.efectivo,
    List<LineaNueva> lineas = const [],
  }) async {
    if (lineas.isNotEmpty) {
      final suma = lineas.fold<int>(0, (s, l) => s + l.subtotal);
      if (suma != monto) {
        throw ArgumentError(
            'El monto ($monto) no es la suma de las líneas ($suma)');
      }
    }
    return _db.transaction(() async {
      final id = await _db.into(_db.ventas).insert(
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
      for (final linea in lineas) {
        await _db.into(_db.lineasVenta).insert(LineasVentaCompanion.insert(
              ventaId: id,
              productoId: Value(linea.productoId),
              descripcion: linea.descripcion,
              precioUnitario: linea.precioUnitario,
              cantidad: linea.cantidad,
            ));
      }
      return id;
    });
  }

  /// Líneas de la venta [ventaId], en el orden en que se registraron.
  Future<List<LineaVenta>> lineasDeVenta(int ventaId) {
    return (_db.select(_db.lineasVenta)
          ..where((l) => l.ventaId.equals(ventaId))
          ..orderBy([(l) => OrderingTerm.asc(l.id)]))
        .get();
  }

  /// Ventas de [dia]. Lo anulado solo viene con [incluirAnulados], para
  /// mostrarlo en el Historial; nunca debe sumarse.
  Future<List<Venta>> ventasDelDia(
    DateTime dia, {
    int? usuarioId,
    bool incluirAnulados = false,
  }) {
    final inicio = inicioDelDia(dia);
    final fin = finDelDia(dia);
    final query = _db.select(_db.ventas)
      ..where((v) =>
          v.fecha.isBiggerOrEqualValue(inicio) &
          v.fecha.isSmallerOrEqualValue(fin));
    if (usuarioId != null) {
      query.where((v) => v.usuarioId.equals(usuarioId));
    }
    if (!incluirAnulados) {
      query.where((v) => v.anulado.equals(false));
    }
    return query.get();
  }

  /// Solo para "Deshacer" justo después de cobrar; no es una función de
  /// anular ventas pasadas. Borra también las líneas.
  Future<void> eliminarVenta(int id) {
    return _db.transaction(() async {
      await (_db.delete(_db.lineasVenta)..where((l) => l.ventaId.equals(id)))
          .go();
      await (_db.delete(_db.ventas)..where((v) => v.id.equals(id))).go();
    });
  }
}
