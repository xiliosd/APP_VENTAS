import 'package:drift/drift.dart';

import '../data/database.dart';

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
  });

  final TipoMovimientoFiado tipo;
  final int monto;
  final DateTime fecha;
}

class FiadoRepository {
  FiadoRepository(this._db);

  final AppDatabase _db;

  Future<int> saldoCliente(int clienteId) async {
    final ventas = await (_db.select(_db.ventas)
          ..where((v) => v.clienteId.equals(clienteId) & v.esFiado.equals(true)))
        .get();
    final totalVentas = ventas.fold<int>(0, (suma, v) => suma + v.monto);

    final pagos = await (_db.select(_db.pagosFiado)
          ..where((p) => p.clienteId.equals(clienteId)))
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
                v.clienteId.equals(cliente.id) & v.esFiado.equals(true))
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
  }) {
    return _db.into(_db.pagosFiado).insert(
          PagosFiadoCompanion.insert(
            clienteId: clienteId,
            monto: monto,
            fecha: fecha ?? DateTime.now(),
            usuarioId: usuarioId,
          ),
        );
  }

  Future<List<Venta>> ventasFiadasCliente(int clienteId) {
    return (_db.select(_db.ventas)
          ..where((v) => v.clienteId.equals(clienteId) & v.esFiado.equals(true))
          ..orderBy([(v) => OrderingTerm.desc(v.fecha)]))
        .get();
  }

  Future<List<PagoFiado>> pagosCliente(int clienteId) {
    return (_db.select(_db.pagosFiado)
          ..where((p) => p.clienteId.equals(clienteId))
          ..orderBy([(p) => OrderingTerm.desc(p.fecha)]))
        .get();
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
        ),
    ]..sort((a, b) => b.fecha.compareTo(a.fecha));
  }
}
