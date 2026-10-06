import 'package:drift/drift.dart';

import '../data/database.dart';
import '../util/fecha_util.dart';
import 'correccion_repository.dart';

class ClienteConSaldo {
  const ClienteConSaldo({
    required this.cliente,
    required this.saldo,
    this.fechaDeudaMasAntigua,
  });

  final Cliente cliente;
  final int saldo;

  /// Fecha de la venta fiada vigente más antigua; null si el cliente no debe.
  final DateTime? fechaDeudaMasAntigua;
}

enum TipoMovimientoFiado { venta, abono }

class MovimientoFiado {
  const MovimientoFiado({
    required this.tipo,
    required this.id,
    required this.monto,
    required this.fecha,
    required this.usuarioId,
    this.medioPago = MedioPago.efectivo,
    this.anulado = false,
    this.ultimaCorreccion,
  });

  final TipoMovimientoFiado tipo;

  /// Id en su tabla (`ventas` o `pagos_fiado`).
  final int id;
  final int monto;
  final DateTime fecha;

  /// Quién lo registró.
  final int usuarioId;

  /// Solo aplica a abonos.
  final MedioPago medioPago;

  /// Anulado: se muestra tachado y no cuenta en el saldo.
  final bool anulado;

  /// Anulación o corrección más reciente, si la hay.
  final Correccion? ultimaCorreccion;
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

    // Aquí todos deben, así que todos tienen fecha de deuda.
    resultado.sort(
      (a, b) => a.fechaDeudaMasAntigua!.compareTo(b.fechaDeudaMasAntigua!),
    );
    return resultado;
  }

  /// Clientes que no deben nada (o tienen saldo a favor) pero sí tienen
  /// ventas fiadas o abonos, aunque estén anulados, para poder abrir su
  /// detalle y corregir esos movimientos. Ordenados por nombre.
  Future<List<ClienteConSaldo>> clientesAlDia() async {
    final clientes = await _db.select(_db.clientes).get();
    final resultado = <ClienteConSaldo>[];
    for (final cliente in clientes) {
      final saldo = await saldoCliente(cliente.id);
      if (saldo > 0) continue;
      final tieneMovimientos =
          (await ventasFiadasCliente(cliente.id, incluirAnulados: true))
                  .isNotEmpty ||
              (await pagosCliente(cliente.id, incluirAnulados: true)).isNotEmpty;
      if (!tieneMovimientos) continue;
      resultado.add(ClienteConSaldo(cliente: cliente, saldo: saldo));
    }
    resultado.sort((a, b) =>
        a.cliente.nombre.toLowerCase().compareTo(b.cliente.nombre.toLowerCase()));
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

  /// Ventas fiadas y abonos del cliente, incluidos los anulados (para
  /// mostrarlos tachados).
  Future<List<MovimientoFiado>> movimientosCliente(int clienteId) async {
    final ventas = await ventasFiadasCliente(clienteId, incluirAnulados: true);
    final pagos = await pagosCliente(clienteId, incluirAnulados: true);
    final correcciones = CorreccionRepository(_db);
    final correccionesVentas = await correcciones.ultimasCorrecciones(
        TipoMovimiento.venta, ventas.map((v) => v.id));
    final correccionesPagos = await correcciones.ultimasCorrecciones(
        TipoMovimiento.abono, pagos.map((p) => p.id));
    return [
      for (final v in ventas)
        MovimientoFiado(
          tipo: TipoMovimientoFiado.venta,
          id: v.id,
          monto: v.monto,
          fecha: v.fecha,
          usuarioId: v.usuarioId,
          anulado: v.anulado,
          ultimaCorreccion: correccionesVentas[v.id],
        ),
      for (final p in pagos)
        MovimientoFiado(
          tipo: TipoMovimientoFiado.abono,
          id: p.id,
          monto: p.monto,
          fecha: p.fecha,
          usuarioId: p.usuarioId,
          medioPago: p.medioPago,
          anulado: p.anulado,
          ultimaCorreccion: correccionesPagos[p.id],
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
