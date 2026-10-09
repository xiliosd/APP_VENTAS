import 'package:drift/drift.dart';

import '../data/database.dart';
import '../util/fecha_util.dart';
import 'fiado_repository.dart';
import 'gasto_repository.dart';
import 'venta_repository.dart';

class ResumenDia {
  const ResumenDia({
    required this.totalVendido,
    required this.totalGastado,
    required this.totalPorCobrar,
    required this.cantidadVentas,
    required this.cantidadFiadas,
    required this.clientesConDeuda,
    this.recibidoEfectivo = 0,
    this.recibidoTransferencia = 0,
  });

  final int totalVendido;
  final int totalGastado;
  final int totalPorCobrar;
  final int cantidadVentas;
  final int cantidadFiadas;
  final int clientesConDeuda;

  /// Ventas de contado y abonos del día recibidos en efectivo.
  final int recibidoEfectivo;

  /// Ventas de contado y abonos del día recibidos por transferencia.
  final int recibidoTransferencia;
}

class ResumenRepository {
  ResumenRepository(
    this._db,
    this._ventaRepository,
    this._gastoRepository,
    this._fiadoRepository,
  );

  final AppDatabase _db;
  final VentaRepository _ventaRepository;
  final GastoRepository _gastoRepository;
  final FiadoRepository _fiadoRepository;

  /// Total vendido (contado + fiado, sin anuladas) de cada uno de los [dias]
  /// días que terminan en [hasta], del más antiguo al más reciente.
  Future<List<int>> ventasDiarias(DateTime hasta, {int dias = 7}) async {
    final primerDia = inicioDelDia(hasta).subtract(Duration(days: dias - 1));
    final ventas = await (_db.select(_db.ventas)
          ..where((v) =>
              v.fecha.isBiggerOrEqualValue(inicioDelDia(primerDia)) &
              v.fecha.isSmallerOrEqualValue(finDelDia(hasta)) &
              v.anulado.equals(false)))
        .get();
    final totales = List<int>.filled(dias, 0);
    final inicio = inicioDelDia(primerDia);
    for (final v in ventas) {
      final indice = inicioDelDia(v.fecha).difference(inicio).inDays;
      if (indice >= 0 && indice < dias) totales[indice] += v.monto;
    }
    return totales;
  }

  Future<ResumenDia> resumenDelDia(DateTime dia, {int? usuarioId}) async {
    final ventas = await _ventaRepository.ventasDelDia(dia, usuarioId: usuarioId);
    final gastos = await _gastoRepository.gastosDelDia(dia, usuarioId: usuarioId);

    final pagos =
        await _fiadoRepository.pagosDelDia(dia, usuarioId: usuarioId);
    int recibido(MedioPago medio) =>
        ventas
            .where((v) => !v.esFiado && v.medioPago == medio)
            .fold<int>(0, (suma, v) => suma + v.monto) +
        pagos
            .where((p) => p.medioPago == medio)
            .fold<int>(0, (suma, p) => suma + p.monto);

    final totalVendido = ventas.fold<int>(0, (suma, v) => suma + v.monto);
    final totalGastado = gastos.fold<int>(0, (suma, g) => suma + g.monto);
    // Deuda de toda la tienda al cierre del día, no solo lo fiado ese día.
    // No depende de usuarioId: la deuda es del cliente, no del vendedor.
    final totalPorCobrar = await _fiadoRepository.deudaTotalAl(dia);

    return ResumenDia(
      totalVendido: totalVendido,
      totalGastado: totalGastado,
      totalPorCobrar: totalPorCobrar,
      cantidadVentas: ventas.length,
      cantidadFiadas: ventas.where((v) => v.esFiado).length,
      clientesConDeuda: await _fiadoRepository.clientesConDeudaAl(dia),
      recibidoEfectivo: recibido(MedioPago.efectivo),
      recibidoTransferencia: recibido(MedioPago.transferencia),
    );
  }

  Future<Map<Usuario, ResumenDia>> resumenPorVendedor(DateTime dia) async {
    final usuarios = await _db.select(_db.usuarios).get();
    final resultado = <Usuario, ResumenDia>{};
    for (final usuario in usuarios) {
      resultado[usuario] = await resumenDelDia(dia, usuarioId: usuario.id);
    }
    return resultado;
  }
}
