import 'package:app_ventas/util/periodo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('semana', () {
    test('la semana de un miércoles va de lunes a domingo', () {
      final p = Periodo.de(TipoPeriodo.semana, DateTime(2026, 10, 7, 15));
      expect(p.inicio, DateTime(2026, 10, 5));
      expect(p.ultimoDia, DateTime(2026, 10, 11));
      expect(p.fin, DateTime(2026, 10, 11, 23, 59, 59, 999));
      expect(p.titulo, 'Semana del 5 al 11 oct.');
    });

    test('una semana que cruza de mes nombra los dos meses', () {
      final p = Periodo.de(TipoPeriodo.semana, DateTime(2026, 10, 1));
      expect(p.inicio, DateTime(2026, 9, 28));
      expect(p.titulo, 'Semana del 28 sep. al 4 oct.');
    });

    test('una semana que cruza de año lleva el año', () {
      final p = Periodo.de(TipoPeriodo.semana, DateTime(2026, 12, 30));
      expect(p.inicio, DateTime(2026, 12, 28));
      expect(p.ultimoDia, DateTime(2027, 1, 3));
      expect(p.titulo, 'Semana del 28 dic. al 3 ene. 2027');
    });

    test('anterior y siguiente cruzan el año', () {
      final enero = Periodo.de(TipoPeriodo.semana, DateTime(2027, 1, 5));
      expect(enero.anterior.inicio, DateTime(2026, 12, 28));
      expect(enero.anterior.siguiente, enero);
    });

    test('contiene hasta el último instante del domingo', () {
      final p = Periodo.de(TipoPeriodo.semana, DateTime(2026, 10, 7));
      expect(p.contiene(DateTime(2026, 10, 11, 23, 59)), isTrue);
      expect(p.contiene(DateTime(2026, 10, 12)), isFalse);
      expect(p.contiene(DateTime(2026, 10, 4, 23, 59)), isFalse);
    });

    test('dos días de la misma semana dan el mismo periodo', () {
      expect(
        Periodo.de(TipoPeriodo.semana, DateTime(2026, 10, 6)),
        Periodo.de(TipoPeriodo.semana, DateTime(2026, 10, 10)),
      );
      expect(
        Periodo.de(TipoPeriodo.semana, DateTime(2026, 10, 6)).hashCode,
        Periodo.de(TipoPeriodo.semana, DateTime(2026, 10, 10)).hashCode,
      );
    });
  });

  group('mes', () {
    test('el mes va del 1 al último día y se titula con su nombre', () {
      final p = Periodo.de(TipoPeriodo.mes, DateTime(2026, 10, 15));
      expect(p.inicio, DateTime(2026, 10, 1));
      expect(p.ultimoDia, DateTime(2026, 10, 31));
      expect(p.titulo, 'Octubre 2026');
    });

    test('febrero tiene 28 o 29 días', () {
      expect(
        Periodo.de(TipoPeriodo.mes, DateTime(2026, 2, 10)).ultimoDia,
        DateTime(2026, 2, 28),
      );
      expect(
        Periodo.de(TipoPeriodo.mes, DateTime(2028, 2, 10)).ultimoDia,
        DateTime(2028, 2, 29),
      );
    });

    test('el anterior de enero es diciembre del año pasado', () {
      final anterior = Periodo.de(
        TipoPeriodo.mes,
        DateTime(2026, 1, 20),
      ).anterior;
      expect(anterior.inicio, DateTime(2025, 12, 1));
      expect(anterior.titulo, 'Diciembre 2025');
    });
  });

  test('Periodo.actual es el que contiene hoy', () {
    final hoy = DateTime(2026, 10, 7);
    expect(Periodo.actual(TipoPeriodo.semana, hoy).contiene(hoy), isTrue);
    expect(Periodo.actual(TipoPeriodo.mes, hoy).inicio, DateTime(2026, 10, 1));
  });
}
