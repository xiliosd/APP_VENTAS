import '../data/database.dart';
import 'gasto_repository.dart';
import 'venta_repository.dart';

class ResumenDia {
  const ResumenDia({
    required this.totalVendido,
    required this.totalGastado,
    required this.totalPorCobrar,
  });

  final int totalVendido;
  final int totalGastado;
  final int totalPorCobrar;
}

class ResumenRepository {
  ResumenRepository(this._db, this._ventaRepository, this._gastoRepository);

  final AppDatabase _db;
  final VentaRepository _ventaRepository;
  final GastoRepository _gastoRepository;

  Future<ResumenDia> resumenDelDia(DateTime dia, {int? usuarioId}) async {
    final ventas = await _ventaRepository.ventasDelDia(dia, usuarioId: usuarioId);
    final gastos = await _gastoRepository.gastosDelDia(dia, usuarioId: usuarioId);

    final totalVendido = ventas.fold<int>(0, (suma, v) => suma + v.monto);
    final totalGastado = gastos.fold<int>(0, (suma, g) => suma + g.monto);
    final totalPorCobrar = ventas
        .where((v) => v.esFiado)
        .fold<int>(0, (suma, v) => suma + v.monto);

    return ResumenDia(
      totalVendido: totalVendido,
      totalGastado: totalGastado,
      totalPorCobrar: totalPorCobrar,
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
