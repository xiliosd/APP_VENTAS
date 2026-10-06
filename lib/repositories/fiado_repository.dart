import 'package:drift/drift.dart';

import '../data/database.dart';
import '../util/fecha_util.dart';

class ClienteConSaldo {
  const ClienteConSaldo({
    required this.cliente,
    required this.saldo,
    required this.fechaDeudaMasAntigua,
  });

  final Cliente cliente;
  final int saldo;
  final DateTime fechaDeudaMasAntigua;
}

enum TipoMovimientoFiado { venta, abono }

class MovimientoFiado {
  const MovimientoFiado({
    required this.tipo,
    required this.monto,
    required this.fecha,
    this.medioPago = MedioPago.efectivo,
  });

  final TipoMovimientoFiado tipo;
  final int monto;
  final DateTime fecha;

  /// Solo aplica a abonos.
  final MedioPago medioPago;
}

class FiadoRepository {
  FiadoRepository(this._db);

  final AppDatabase _db;

  Future<int> saldoCliente(int clienteId) async {
    final ventas = await (_db.select(_db.ventas)
          ..where((v) =>
              v.clienteId.equals(clienteId) &
              v.esFiado.equals(true) &
              v.anulado.equals(false)))
        .get();
    final totalVentas = ventas.fold<int>(0, (suma, v) => suma + v.monto);

    final pagos = await (_db.select(_db.pagosFiado)
          ..where((p) => p.clienteId.equals(clienteId) & p.anulado.equals(false)))
        .get();
    final totalPagos = pagos.fold<int>(0, (suma, p) => suma + p.monto);

    return totalVentas - totalPagos;
  }

  Future<List<ClienteConSaldo>> listaClientesConDeuda() async {
    final clientes = await _db.select(_db.clientes).get();
    final resultado = <ClienteConSaldo>[];

    for (final cliente in clientes) {
      final saldo = await saldoCliente(cliente.id);
      if (saldo <= 0) continue;

      final ventasFiadas = await (_db.select(_db.ventas)
            ..where((v) =>
                v.clienteId.equals(cliente.id) &
                v.esFiado.equals(true) &
                v.anulado.equals(false))
            ..orderBy([(v) => OrderingTerm.asc(v.fecha)]))
          .get();

      resultado.add(ClienteConSaldo(
        cliente: cliente,
        saldo: saldo,
        fechaDeudaMasAntigua: ventasFiadas.first.fecha,
      ));
    }

    resultado.sort(
      (a, b) => a.fechaDeudaMasAntigua.compareTo(b.fechaDeudaMasAntigua),
    );
    return resultado;
  }

  Future<int> registrarPago({
    required int clienteId,
    required int monto,
    required int usuarioId,
    DateTime? fecha,
    MedioPago medioPago = MedioPago.efectivo,
  }) {
    return _db.into(_db.pagosFiado).insert(
          PagosFiadoCompanion.insert(
            clienteId: clienteId,
            monto: monto,
            fecha: fecha ?? DateTime.now(),
            usuarioId: usuarioId,
            medioPago: Value(medioPago),
          ),
        );
  }

  Future<List<PagoFiado>> pagosDelDia(DateTime dia, {int? usuarioId}) {
    final query = _db.select(_db.pagosFiado)
      ..where((p) =>
          p.fecha.isBiggerOrEqualValue(inicioDelDia(dia)) &
          p.fecha.isSmallerOrEqualValue(finDelDia(dia)) &
          p.anulado.equals(false));
    if (usuarioId != null) {
      query.where((p) => p.usuarioId.equals(usuarioId));
    }
    return query.get();
  }

  Future<List<Venta>> ventasFiadasCliente(
    int clienteId, {
    bool incluirAnulados = false,
  }) {
    final query = _db.select(_db.ventas)
      ..where((v) => v.clienteId.equals(clienteId) & v.esFiado.equals(true))
      ..orderBy([(v) => OrderingTerm.desc(v.fecha)]);
    if (!incluirAnulados) query.where((v) => v.anulado.equals(false));
    return query.get();
  }

  Future<List<PagoFiado>> pagosCliente(
    int clienteId, {
    bool incluirAnulados = false,
  }) {
    final query = _db.select(_db.pagosFiado)
      ..where((p) => p.clienteId.equals(clienteId))
      ..orderBy([(p) => OrderingTerm.desc(p.fecha)]);
    if (!incluirAnulados) query.where((p) => p.anulado.equals(false));
    return query.get();
  }

  Future<List<MovimientoFiado>> movimientosCliente(int clienteId) async {
    final ventas = await ventasFiadasCliente(clienteId);
    final pagos = await pagosCliente(clienteId);
    return [
      for (final v in ventas)
        MovimientoFiado(
          tipo: TipoMovimientoFiado.venta,
          monto: v.monto,
          fecha: v.fecha,
        ),
      for (final p in pagos)
        MovimientoFiado(
          tipo: TipoMovimientoFiado.abono,
          monto: p.monto,
          fecha: p.fecha,
          medioPago: p.medioPago,
        ),
    ]..sort((a, b) => b.fecha.compareTo(a.fecha));
  }

  /// Saldo de cada cliente al cierre de [dia]: ventas fiadas menos abonos
  /// hechos hasta ese momento.
  Future<Map<int, int>> _saldosAl(DateTime dia) async {
    final corte = finDelDia(dia);
    final ventas = await (_db.select(_db.ventas)
          ..where((v) =>
              v.esFiado.equals(true) &
              v.clienteId.isNotNull() &
              v.anulado.equals(false) &
              v.fecha.isSmallerOrEqualValue(corte)))
        .get();
    final pagos = await (_db.select(_db.pagosFiado)
          ..where((p) =>
              p.anulado.equals(false) & p.fecha.isSmallerOrEqualValue(corte)))
        .get();

    final saldos = <int, int>{};
    for (final v in ventas) {
      saldos.update(v.clienteId!, (s) => s + v.monto, ifAbsent: () => v.monto);
    }
    for (final p in pagos) {
      saldos.update(p.clienteId, (s) => s - p.monto, ifAbsent: () => -p.monto);
    }
    return saldos;
  }

  /// Lo que deben todos los clientes al cierre de [dia]. Un cliente con saldo
  /// a favor cuenta como 0, para que no reste a la deuda de los demás.
  Future<int> deudaTotalAl(DateTime dia) async {
    final saldos = await _saldosAl(dia);
    return saldos.values
        .where((s) => s > 0)
        .fold<int>(0, (suma, s) => suma + s);
  }

  /// Cuántos clientes deben algo al cierre de [dia].
  Future<int> clientesConDeudaAl(DateTime dia) async {
    final saldos = await _saldosAl(dia);
    return saldos.values.where((s) => s > 0).length;
  }
}
