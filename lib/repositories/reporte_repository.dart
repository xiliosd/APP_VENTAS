import 'package:drift/drift.dart';

import '../data/database.dart';
import '../util/fecha_util.dart';
import '../util/periodo.dart';
import 'fiado_repository.dart';

/// Cifras de un rango de días, sin nada anulado.
class Reporte {
  const Reporte({
    required this.ventas,
    required this.cantidadVentas,
    required this.gastos,
    required this.recibidoEfectivo,
    required this.recibidoTransferencia,
    required this.fiado,
    required this.cobrado,
    required this.deudaInicio,
    required this.deudaFin,
    required this.ventasPorDia,
    required this.mejorDia,
  });

  /// Contado + fiado.
  final int ventas;
  final int cantidadVentas;
  final int gastos;

  /// Ventas de contado y abonos en efectivo.
  final int recibidoEfectivo;

  /// Ventas de contado y abonos por transferencia.
  final int recibidoTransferencia;

  /// Ventas fiadas del rango.
  final int fiado;

  /// Abonos del rango.
  final int cobrado;

  /// Deuda de todos los clientes al cierre del día anterior al rango.
  final int deudaInicio;

  /// Deuda de todos los clientes al cierre del último día del rango.
  final int deudaFin;

  /// Cada día del rango, en orden, con lo vendido (0 si nada).
  final Map<DateTime, int> ventasPorDia;

  /// Día de mayores ventas (empate: el primero); null sin ventas.
  final DateTime? mejorDia;

  int get ganancia => ventas - gastos;

  int get ventaPromedio =>
      cantidadVentas == 0 ? 0 : (ventas / cantidadVentas).round();

  /// Sin ventas, gastos ni abonos.
  bool get vacio => cantidadVentas == 0 && gastos == 0 && cobrado == 0;
}

/// Un periodo y el anterior con el que se compara.
class ComparacionReporte {
  const ComparacionReporte({
    required this.actual,
    required this.anterior,
    required this.cambioVentas,
    required this.cambioGanancia,
  });

  final Reporte actual;
  final Reporte anterior;

  /// Porcentaje entero; null si el anterior fue 0.
  final int? cambioVentas;
  final int? cambioGanancia;
}

/// `redondear((actual − anterior) × 100 ÷ |anterior|)`; null si [anterior]
/// es 0.
int? cambioPorcentual(int actual, int anterior) {
  if (anterior == 0) return null;
  return ((actual - anterior) * 100 / anterior.abs()).round();
}

int _suma(Iterable<int> montos) => montos.fold(0, (suma, m) => suma + m);

/// Días calendario de [desde] a [hasta] (ambos a las 00:00).
int _diasEntre(DateTime desde, DateTime hasta) =>
    DateTime.utc(hasta.year, hasta.month, hasta.day)
        .difference(DateTime.utc(desde.year, desde.month, desde.day))
        .inDays;

class ReporteRepository {
  ReporteRepository(this._db, this._fiado);

  final AppDatabase _db;
  final FiadoRepository _fiado;

  /// Reporte de los días [desde] a [hasta], ambos incluidos.
  Future<Reporte> reporte(DateTime desde, DateTime hasta) async {
    final inicio = inicioDelDia(desde);
    final ultimo = inicioDelDia(hasta);
    final fin = finDelDia(ultimo);

    final ventas = await (_db.select(_db.ventas)
          ..where((v) =>
              v.anulado.equals(false) & v.fecha.isBetweenValues(inicio, fin)))
        .get();
    final pagos = await (_db.select(_db.pagosFiado)
          ..where((p) =>
              p.anulado.equals(false) & p.fecha.isBetweenValues(inicio, fin)))
        .get();
    final gastos = await (_db.select(_db.gastos)
          ..where((g) =>
              g.anulado.equals(false) & g.fecha.isBetweenValues(inicio, fin)))
        .get();

    int recibido(MedioPago medio) =>
        _suma(ventas
            .where((v) => !v.esFiado && v.medioPago == medio)
            .map((v) => v.monto)) +
        _suma(pagos.where((p) => p.medioPago == medio).map((p) => p.monto));

    final porDia = <DateTime, int>{};
    for (var dia = inicio;
        !dia.isAfter(ultimo);
        dia = DateTime(dia.year, dia.month, dia.day + 1)) {
      porDia[dia] = 0;
    }
    for (final v in ventas) {
      porDia.update(inicioDelDia(v.fecha), (suma) => suma + v.monto);
    }
    DateTime? mejorDia;
    for (final entrada in porDia.entries) {
      if (entrada.value > 0 &&
          (mejorDia == null || entrada.value > porDia[mejorDia]!)) {
        mejorDia = entrada.key;
      }
    }

    return Reporte(
      ventas: _suma(ventas.map((v) => v.monto)),
      cantidadVentas: ventas.length,
      gastos: _suma(gastos.map((g) => g.monto)),
      recibidoEfectivo: recibido(MedioPago.efectivo),
      recibidoTransferencia: recibido(MedioPago.transferencia),
      fiado: _suma(ventas.where((v) => v.esFiado).map((v) => v.monto)),
      cobrado: _suma(pagos.map((p) => p.monto)),
      deudaInicio: await _fiado.deudaTotalAl(
          DateTime(inicio.year, inicio.month, inicio.day - 1)),
      deudaFin: await _fiado.deudaTotalAl(ultimo),
      ventasPorDia: porDia,
      mejorDia: mejorDia,
    );
  }

  /// [periodo] contra el anterior. Si [periodo] contiene [hoy], cuenta
  /// hasta hoy y el anterior solo los mismos días (sin pasar de su último
  /// día); si ya cerró, ambos completos.
  Future<ComparacionReporte> comparar(
    Periodo periodo, {
    required DateTime hoy,
  }) async {
    final anterior = periodo.anterior;
    final DateTime hasta;
    final DateTime hastaAnterior;
    if (periodo.contiene(hoy)) {
      hasta = inicioDelDia(hoy);
      final mismoDia = DateTime(anterior.inicio.year, anterior.inicio.month,
          anterior.inicio.day + _diasEntre(periodo.inicio, hasta));
      hastaAnterior = mismoDia.isAfter(anterior.ultimoDia)
          ? anterior.ultimoDia
          : mismoDia;
    } else {
      hasta = periodo.ultimoDia;
      hastaAnterior = anterior.ultimoDia;
    }
    final actual = await reporte(periodo.inicio, hasta);
    final previo = await reporte(anterior.inicio, hastaAnterior);
    return ComparacionReporte(
      actual: actual,
      anterior: previo,
      cambioVentas: cambioPorcentual(actual.ventas, previo.ventas),
      cambioGanancia: cambioPorcentual(actual.ganancia, previo.ganancia),
    );
  }
}
