import '../repositories/fiado_repository.dart';

/// Saldo del cliente después de cada movimiento no anulado, clave
/// (tipo, id). Recorre del más antiguo al más reciente; con la misma fecha,
/// la venta va antes que el abono. Negativo = saldo a favor.
Map<(TipoMovimientoFiado, int), int> saldosAcumulados(
    List<MovimientoFiado> movimientos) {
  final orden = [
    for (final m in movimientos)
      if (!m.anulado) m,
  ]..sort((a, b) {
      final porFecha = a.fecha.compareTo(b.fecha);
      if (porFecha != 0) return porFecha;
      return a.tipo.index.compareTo(b.tipo.index); // venta (0) antes que abono
    });
  var saldo = 0;
  return {
    for (final m in orden)
      (m.tipo, m.id): saldo +=
          m.tipo == TipoMovimientoFiado.venta ? m.monto : -m.monto,
  };
}
