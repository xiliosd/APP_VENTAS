import 'fecha_util.dart';

enum TipoPeriodo { semana, mes }

const _mesesCortos = [
  'ene.',
  'feb.',
  'mar.',
  'abr.',
  'may.',
  'jun.',
  'jul.',
  'ago.',
  'sep.',
  'oct.',
  'nov.',
  'dic.',
];

const _mesesLargos = [
  'Enero',
  'Febrero',
  'Marzo',
  'Abril',
  'Mayo',
  'Junio',
  'Julio',
  'Agosto',
  'Septiembre',
  'Octubre',
  'Noviembre',
  'Diciembre',
];

/// Una semana (lunes a domingo) o un mes calendario, en hora local. Se
/// compara por valor, así sirve de clave de provider.
class Periodo {
  const Periodo._(this.tipo, this.inicio);

  /// El periodo de [tipo] que contiene [dia].
  factory Periodo.de(TipoPeriodo tipo, DateTime dia) {
    final d = inicioDelDia(dia);
    return switch (tipo) {
      TipoPeriodo.semana => Periodo._(
        tipo,
        DateTime(d.year, d.month, d.day - (d.weekday - 1)),
      ),
      TipoPeriodo.mes => Periodo._(tipo, DateTime(d.year, d.month)),
    };
  }

  /// El periodo de [tipo] en curso.
  factory Periodo.actual(TipoPeriodo tipo, DateTime hoy) =>
      Periodo.de(tipo, hoy);

  final TipoPeriodo tipo;

  /// Primer día, a las 00:00.
  final DateTime inicio;

  /// Último día, a las 00:00.
  DateTime get ultimoDia => switch (tipo) {
    TipoPeriodo.semana => DateTime(inicio.year, inicio.month, inicio.day + 6),
    TipoPeriodo.mes => DateTime(inicio.year, inicio.month + 1, 0),
  };

  /// Último instante del periodo.
  DateTime get fin => finDelDia(ultimoDia);

  Periodo get anterior =>
      Periodo.de(tipo, DateTime(inicio.year, inicio.month, inicio.day - 1));

  Periodo get siguiente => Periodo.de(
    tipo,
    DateTime(ultimoDia.year, ultimoDia.month, ultimoDia.day + 1),
  );

  bool contiene(DateTime momento) =>
      !momento.isBefore(inicio) && !momento.isAfter(fin);

  /// "Semana del 5 al 11 oct.", "Semana del 28 sep. al 4 oct.",
  /// "Semana del 28 dic. al 3 ene. 2027", "Semana del 6 al 12 oct. 2025"
  /// (de otro año que [hoy]) u "Octubre 2026".
  String titulo(DateTime hoy) {
    if (tipo == TipoPeriodo.mes) {
      return '${_mesesLargos[inicio.month - 1]} ${inicio.year}';
    }
    final a = inicio;
    final b = ultimoDia;
    final mesA = _mesesCortos[a.month - 1];
    final mesB = _mesesCortos[b.month - 1];
    final anio = a.year != b.year || b.year != hoy.year ? ' ${b.year}' : '';
    if (a.month != b.month) {
      return 'Semana del ${a.day} $mesA al ${b.day} $mesB$anio';
    }
    return 'Semana del ${a.day} al ${b.day} $mesB$anio';
  }

  @override
  bool operator ==(Object other) =>
      other is Periodo && other.tipo == tipo && other.inicio == inicio;

  @override
  int get hashCode => Object.hash(tipo, inicio);
}
