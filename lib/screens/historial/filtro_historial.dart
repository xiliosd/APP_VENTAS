import '../../repositories/historial_repository.dart';

/// Qué tipo de movimientos muestra el Historial.
enum FiltroTipo { todo, contado, fiado, gastos }

/// Los movimientos de [movimientos] que corresponden a [filtro].
List<MovimientoHistorial> filtrarPorTipo(
        List<MovimientoHistorial> movimientos, FiltroTipo filtro) =>
    [
      for (final m in movimientos)
        if (switch (filtro) {
          FiltroTipo.todo => true,
          FiltroTipo.contado =>
            m.tipo == TipoMovimientoHistorial.venta && !m.esFiado,
          FiltroTipo.fiado =>
            m.tipo == TipoMovimientoHistorial.venta && m.esFiado,
          FiltroTipo.gastos => m.tipo == TipoMovimientoHistorial.gasto,
        })
          m,
    ];
