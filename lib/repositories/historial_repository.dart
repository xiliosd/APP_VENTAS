import '../data/database.dart';
import 'correccion_repository.dart';
import 'gasto_repository.dart';
import 'venta_repository.dart';

enum TipoMovimientoHistorial { venta, gasto }

class MovimientoHistorial {
  const MovimientoHistorial({
    required this.tipo,
    required this.id,
    required this.monto,
    required this.fecha,
    required this.usuarioId,
    this.esFiado = false,
    this.clienteId,
    this.descripcion,
    this.medioPago = MedioPago.efectivo,
    this.anulado = false,
    this.ultimaCorreccion,
  });

  final TipoMovimientoHistorial tipo;

  /// Id en su tabla (`ventas` o `gastos`).
  final int id;
  final int monto;
  final DateTime fecha;
  final int usuarioId;

  /// Solo aplica a ventas; siempre false para gastos.
  final bool esFiado;

  /// Solo aplica a ventas fiadas.
  final int? clienteId;

  /// Solo aplica a gastos; null para ventas o gastos sin descripción.
  final String? descripcion;

  /// Solo aplica a ventas.
  final MedioPago medioPago;

  /// Anulado: se muestra tachado y no suma en ningún total.
  final bool anulado;

  /// Anulación o corrección más reciente, si la hay.
  final Correccion? ultimaCorreccion;
}

class HistorialRepository {
  HistorialRepository(
    this._ventaRepository,
    this._gastoRepository,
    this._correccionRepository,
  );

  final VentaRepository _ventaRepository;
  final GastoRepository _gastoRepository;
  final CorreccionRepository _correccionRepository;

  /// Movimientos de [dia], incluidos los anulados (para mostrarlos tachados).
  Future<List<MovimientoHistorial>> movimientosDelDia(
    DateTime dia, {
    int? usuarioId,
  }) async {
    final ventas = await _ventaRepository.ventasDelDia(dia,
        usuarioId: usuarioId, incluirAnulados: true);
    final gastos = await _gastoRepository.gastosDelDia(dia,
        usuarioId: usuarioId, incluirAnulados: true);
    final correccionesVentas = await _correccionRepository
        .ultimasCorrecciones(TipoMovimiento.venta, ventas.map((v) => v.id));
    final correccionesGastos = await _correccionRepository
        .ultimasCorrecciones(TipoMovimiento.gasto, gastos.map((g) => g.id));
    return [
      for (final v in ventas)
        MovimientoHistorial(
          tipo: TipoMovimientoHistorial.venta,
          id: v.id,
          monto: v.monto,
          fecha: v.fecha,
          usuarioId: v.usuarioId,
          esFiado: v.esFiado,
          clienteId: v.clienteId,
          medioPago: v.medioPago,
          anulado: v.anulado,
          ultimaCorreccion: correccionesVentas[v.id],
        ),
      for (final g in gastos)
        MovimientoHistorial(
          tipo: TipoMovimientoHistorial.gasto,
          id: g.id,
          monto: g.monto,
          fecha: g.fecha,
          usuarioId: g.usuarioId,
          descripcion: g.descripcion,
          anulado: g.anulado,
          ultimaCorreccion: correccionesGastos[g.id],
        ),
    ]..sort((a, b) => b.fecha.compareTo(a.fecha));
  }
}
