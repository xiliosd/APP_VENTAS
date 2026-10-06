import 'package:drift/drift.dart';

import '../data/database.dart';
import '../util/formato_moneda.dart';
import '../util/permisos.dart';

/// El usuario no puede corregir ni anular ese movimiento.
class PermisoDenegado implements Exception {
  const PermisoDenegado();
}

/// La corrección no es válida: monto en 0, venta fiada sin cliente o
/// movimiento ya anulado.
class CorreccionInvalida implements Exception {
  const CorreccionInvalida(this.mensaje);

  final String mensaje;

  @override
  String toString() => mensaje;
}

String _nombreMedio(MedioPago medio) =>
    medio == MedioPago.efectivo ? 'Efectivo' : 'Transferencia';

/// Único lugar que anula o corrige ventas, abonos y gastos. Cada cambio queda
/// en `correcciones` con quién, cuándo y cómo estaba antes, en la misma
/// transacción que el cambio.
class CorreccionRepository {
  CorreccionRepository(this._db, {DateTime Function()? reloj})
      : _reloj = reloj ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _reloj;

  // ---- Ventas ----

  Future<void> anularVenta(int id, {required Usuario por}) async {
    await _db.transaction(() async {
      final venta = await _venta(id);
      _comprobar(por, venta.usuarioId, venta.fecha, venta.anulado);
      final antes = await _antesVenta(venta);
      await (_db.update(_db.ventas)..where((v) => v.id.equals(id)))
          .write(const VentasCompanion(anulado: Value(true)));
      await _registrar(
          TipoMovimiento.venta, id, AccionCorreccion.anulado, por, antes);
    });
  }

  /// Una venta fiada guarda `efectivo` (no cuenta por medio de pago); una de
  /// contado queda sin cliente.
  Future<void> corregirVenta(
    int id, {
    required int monto,
    required bool esFiado,
    int? clienteId,
    MedioPago medioPago = MedioPago.efectivo,
    required Usuario por,
  }) async {
    _validarMonto(monto);
    if (esFiado && clienteId == null) {
      throw const CorreccionInvalida('Una venta fiada necesita cliente');
    }
    await _db.transaction(() async {
      final venta = await _venta(id);
      _comprobar(por, venta.usuarioId, venta.fecha, venta.anulado);
      final antes = await _antesVenta(venta);
      await (_db.update(_db.ventas)..where((v) => v.id.equals(id))).write(
        VentasCompanion(
          monto: Value(monto),
          esFiado: Value(esFiado),
          clienteId: Value(esFiado ? clienteId : null),
          medioPago: Value(esFiado ? MedioPago.efectivo : medioPago),
        ),
      );
      await _registrar(
          TipoMovimiento.venta, id, AccionCorreccion.corregido, por, antes);
    });
  }

  // ---- Abonos ----

  Future<void> anularPago(int id, {required Usuario por}) async {
    await _db.transaction(() async {
      final pago = await _pago(id);
      _comprobar(por, pago.usuarioId, pago.fecha, pago.anulado);
      await (_db.update(_db.pagosFiado)..where((p) => p.id.equals(id)))
          .write(const PagosFiadoCompanion(anulado: Value(true)));
      await _registrar(TipoMovimiento.abono, id, AccionCorreccion.anulado, por,
          _antesPago(pago));
    });
  }

  Future<void> corregirPago(
    int id, {
    required int monto,
    required MedioPago medioPago,
    required Usuario por,
  }) async {
    _validarMonto(monto);
    await _db.transaction(() async {
      final pago = await _pago(id);
      _comprobar(por, pago.usuarioId, pago.fecha, pago.anulado);
      await (_db.update(_db.pagosFiado)..where((p) => p.id.equals(id))).write(
          PagosFiadoCompanion(monto: Value(monto), medioPago: Value(medioPago)));
      await _registrar(TipoMovimiento.abono, id, AccionCorreccion.corregido,
          por, _antesPago(pago));
    });
  }

  // ---- Gastos ----

  Future<void> anularGasto(int id, {required Usuario por}) async {
    await _db.transaction(() async {
      final gasto = await _gasto(id);
      _comprobar(por, gasto.usuarioId, gasto.fecha, gasto.anulado);
      await (_db.update(_db.gastos)..where((g) => g.id.equals(id)))
          .write(const GastosCompanion(anulado: Value(true)));
      await _registrar(TipoMovimiento.gasto, id, AccionCorreccion.anulado, por,
          _antesGasto(gasto));
    });
  }

  Future<void> corregirGasto(
    int id, {
    required int monto,
    String? descripcion,
    required Usuario por,
  }) async {
    _validarMonto(monto);
    await _db.transaction(() async {
      final gasto = await _gasto(id);
      _comprobar(por, gasto.usuarioId, gasto.fecha, gasto.anulado);
      await (_db.update(_db.gastos)..where((g) => g.id.equals(id))).write(
          GastosCompanion(monto: Value(monto), descripcion: Value(descripcion)));
      await _registrar(TipoMovimiento.gasto, id, AccionCorreccion.corregido,
          por, _antesGasto(gasto));
    });
  }

  // ---- Consulta ----

  /// Corrección más reciente de cada movimiento de [ids], por id.
  Future<Map<int, Correccion>> ultimasCorrecciones(
    TipoMovimiento tipo,
    Iterable<int> ids,
  ) async {
    if (ids.isEmpty) return {};
    final filas = await (_db.select(_db.correcciones)
          ..where((c) =>
              c.tipoMovimiento.equalsValue(tipo) & c.movimientoId.isIn(ids))
          ..orderBy([
            (c) => OrderingTerm.asc(c.fecha),
            (c) => OrderingTerm.asc(c.id),
          ]))
        .get();
    // Las más recientes van al final y reemplazan a las anteriores.
    return {for (final c in filas) c.movimientoId: c};
  }

  // ---- Apoyo ----

  Future<Venta> _venta(int id) =>
      (_db.select(_db.ventas)..where((v) => v.id.equals(id))).getSingle();

  Future<PagoFiado> _pago(int id) =>
      (_db.select(_db.pagosFiado)..where((p) => p.id.equals(id))).getSingle();

  Future<Gasto> _gasto(int id) =>
      (_db.select(_db.gastos)..where((g) => g.id.equals(id))).getSingle();

  void _validarMonto(int monto) {
    if (monto <= 0) {
      throw const CorreccionInvalida('El monto debe ser mayor que 0');
    }
  }

  void _comprobar(Usuario por, int duenoId, DateTime fecha, bool anulado) {
    if (anulado) {
      throw const CorreccionInvalida('Este movimiento ya está anulado');
    }
    if (!puedeCorregir(
        usuario: por, duenoId: duenoId, fechaMovimiento: fecha, ahora: _reloj())) {
      throw const PermisoDenegado();
    }
  }

  Future<String> _antesVenta(Venta venta) async {
    final monto = formatoMoneda(venta.monto);
    if (!venta.esFiado) {
      return '$monto · Contado · ${_nombreMedio(venta.medioPago)}';
    }
    final clienteId = venta.clienteId;
    final cliente = clienteId == null
        ? null
        : await (_db.select(_db.clientes)..where((c) => c.id.equals(clienteId)))
            .getSingleOrNull();
    return '$monto · Fiado · ${cliente?.nombre ?? 'Sin cliente'}';
  }

  String _antesPago(PagoFiado pago) =>
      '${formatoMoneda(pago.monto)} · ${_nombreMedio(pago.medioPago)}';

  String _antesGasto(Gasto gasto) {
    final descripcion = gasto.descripcion?.trim() ?? '';
    final monto = formatoMoneda(gasto.monto);
    return descripcion.isEmpty ? monto : '$monto · $descripcion';
  }

  Future<void> _registrar(
    TipoMovimiento tipo,
    int id,
    AccionCorreccion accion,
    Usuario por,
    String antes,
  ) {
    return _db.into(_db.correcciones).insert(CorreccionesCompanion.insert(
          tipoMovimiento: tipo,
          movimientoId: id,
          accion: accion,
          usuarioId: por.id,
          fecha: _reloj(),
          antes: antes,
        ));
  }
}
