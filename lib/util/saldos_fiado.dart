import '../repositories/fiado_repository.dart';

/// Orden de la línea de tiempo del cliente: por fecha y, con la misma fecha,
/// la venta antes que el abono.
int compararMovimientosFiado(MovimientoFiado a, MovimientoFiado b) {
  final porFecha = a.fecha.compareTo(b.fecha);
  if (porFecha != 0) return porFecha;
  return a.tipo.index.compareTo(b.tipo.index); // venta (0) antes que abono
}

/// Saldo del cliente después de cada movimiento no anulado, clave
/// (tipo, id). Recorre del más antiguo al más reciente; con la misma fecha,
/// la venta va antes que el abono. Negativo = saldo a favor.
Map<(TipoMovimientoFiado, int), int> saldosAcumulados(
  List<MovimientoFiado> movimientos,
) {
  final orden = [
    for (final m in movimientos)
      if (!m.anulado) m,
  ]..sort(compararMovimientosFiado);
  var saldo = 0;
  return {
    for (final m in orden)
      (m.tipo, m.id): saldo += m.tipo == TipoMovimientoFiado.venta
          ? m.monto
          : -m.monto,
  };
}

/// Mitad de [saldo] redondeada a la centena; 0 si no tiene sentido
/// ofrecerla (saldo pequeño o la mitad redondeada iguala al saldo).
int mitadAbono(int saldo) {
  if (saldo <= 0) return 0;
  final mitad = ((saldo / 2) / 100).round() * 100;
  return mitad <= 0 || mitad >= saldo ? 0 : mitad;
}
