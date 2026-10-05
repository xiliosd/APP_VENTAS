import 'gasto_repository.dart';
import 'venta_repository.dart';

enum TipoMovimientoHistorial { venta, gasto }

class MovimientoHistorial {
  const MovimientoHistorial({
    required this.tipo,
    required this.monto,
    required this.fecha,
    required this.usuarioId,
    this.esFiado = false,
    this.descripcion,
  });

  final TipoMovimientoHistorial tipo;
  final int monto;
  final DateTime fecha;
  final int usuarioId;

  /// Solo aplica a ventas; siempre false para gastos.
  final bool esFiado;

  /// Solo aplica a gastos; null para ventas o gastos sin descripción.
  final String? descripcion;
}

class HistorialRepository {
  HistorialRepository(this._ventaRepository, this._gastoRepository);

  final VentaRepository _ventaRepository;
  final GastoRepository _gastoRepository;

  Future<List<MovimientoHistorial>> movimientosDelDia(
    DateTime dia, {
    int? usuarioId,
  }) async {
    final ventas =
        await _ventaRepository.ventasDelDia(dia, usuarioId: usuarioId);
    final gastos =
        await _gastoRepository.gastosDelDia(dia, usuarioId: usuarioId);
    return [
      for (final v in ventas)
        MovimientoHistorial(
          tipo: TipoMovimientoHistorial.venta,
          monto: v.monto,
          fecha: v.fecha,
          usuarioId: v.usuarioId,
          esFiado: v.esFiado,
        ),
      for (final g in gastos)
        MovimientoHistorial(
          tipo: TipoMovimientoHistorial.gasto,
          monto: g.monto,
          fecha: g.fecha,
          usuarioId: g.usuarioId,
          descripcion: g.descripcion,
        ),
    ]..sort((a, b) => b.fecha.compareTo(a.fecha));
  }
}
