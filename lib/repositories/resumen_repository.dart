import '../data/database.dart';
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
