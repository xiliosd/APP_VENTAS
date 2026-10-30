import '../data/database.dart';
import '../repositories/fiado_repository.dart';
import 'saldos_fiado.dart';

/// Una fila del extracto de fiado de un cliente.
sealed class EntradaExtracto {
  const EntradaExtracto({required this.fecha, required this.monto});

  final DateTime fecha;
  final int monto;
}

class FiadoExtracto extends EntradaExtracto {
  const FiadoExtracto({
    required super.fecha,
    required super.monto,
    required this.ventaId,
    required this.lineas,
    required this.saldoDespues,
  });

  final int ventaId;

  /// Vacías = venta sin detalle (monto suelto).
  final List<LineaVenta> lineas;
  final int saldoDespues;
}

class AbonoExtracto extends EntradaExtracto {
  const AbonoExtracto({
    required super.fecha,
    required super.monto,
    required this.pagoId,
    required this.saldoDespues,
  });

  final int pagoId;
  final int saldoDespues;
}

class ExtractoFiado {
  const ExtractoFiado({
    required this.anteriores,
    required this.ultimoAbono,
    required this.recientes,
    required this.saldoActual,
  });

  /// Todo lo anterior al último abono, del más antiguo al más reciente.
  final List<EntradaExtracto> anteriores;
  final AbonoExtracto? ultimoAbono;

  /// Lo posterior al último abono (todo, si el cliente nunca ha abonado).
  final List<EntradaExtracto> recientes;
  final int saldoActual;
}

/// Arma el extracto con el mismo orden y saldos de [saldosAcumulados] para que
/// coincida con la línea de tiempo del cliente; los anulados no cuentan.
ExtractoFiado armarExtracto(
  List<MovimientoFiado> movimientos,
  Map<int, List<LineaVenta>> lineasPorVenta,
) {
  final saldos = saldosAcumulados(movimientos);
  final vigentes =
      [
        for (final m in movimientos)
          if (!m.anulado) m,
      ]..sort((a, b) {
        final porFecha = a.fecha.compareTo(b.fecha);
        if (porFecha != 0) return porFecha;
        return a.tipo.index.compareTo(b.tipo.index);
      });
  final entradas = <EntradaExtracto>[
    for (final m in vigentes)
      if (m.tipo == TipoMovimientoFiado.venta)
        FiadoExtracto(
          fecha: m.fecha,
          monto: m.monto,
          ventaId: m.id,
          lineas: lineasPorVenta[m.id] ?? const [],
          saldoDespues: saldos[(m.tipo, m.id)]!,
        )
      else
        AbonoExtracto(
          fecha: m.fecha,
          monto: m.monto,
          pagoId: m.id,
          saldoDespues: saldos[(m.tipo, m.id)]!,
        ),
  ];
  final indiceUltimoAbono = entradas.lastIndexWhere((e) => e is AbonoExtracto);
  return ExtractoFiado(
    anteriores: indiceUltimoAbono < 0
        ? const []
        : entradas.sublist(0, indiceUltimoAbono),
    ultimoAbono: indiceUltimoAbono < 0
        ? null
        : entradas[indiceUltimoAbono] as AbonoExtracto,
    recientes: entradas.sublist(indiceUltimoAbono + 1),
    saldoActual: vigentes.isEmpty
        ? 0
        : saldos[(vigentes.last.tipo, vigentes.last.id)]!,
  );
}
