import 'package:app_ventas/util/fecha_util.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('inicioDelDia trunca a medianoche', () {
    final dia = DateTime(2026, 9, 2, 15, 30, 45);
    expect(inicioDelDia(dia), DateTime(2026, 9, 2));
  });

  test('finDelDia es justo antes de medianoche siguiente', () {
    final dia = DateTime(2026, 9, 2, 15, 30, 45);
    final fin = finDelDia(dia);
    expect(fin.isAfter(DateTime(2026, 9, 2, 23, 59, 59)), isTrue);
    expect(fin.isBefore(DateTime(2026, 9, 3)), isTrue);
  });

  test('formatoFecha usa dd/mm/aaaa con ceros a la izquierda', () {
    expect(formatoFecha(DateTime(2026, 9, 2, 7, 5)), '02/09/2026');
  });

  test('formatoHora usa hh:mm en 24 horas con ceros a la izquierda', () {
    expect(formatoHora(DateTime(2026, 9, 2, 7, 5)), '07:05');
    expect(formatoHora(DateTime(2026, 9, 2, 18, 30)), '18:30');
  });

  test('formatoFechaHora une fecha y hora', () {
    expect(formatoFechaHora(DateTime(2026, 9, 2, 7, 5)), '02/09/2026 07:05');
  });

  test('textoDebeDesde usa hoy, ayer o hace N días', () {
    final hoy = DateTime(2026, 10, 5, 9);
    expect(textoDebeDesde(DateTime(2026, 10, 5, 7), hoy), 'Debe desde hoy');
    expect(textoDebeDesde(DateTime(2026, 10, 4, 23), hoy), 'Debe desde ayer');
    expect(textoDebeDesde(DateTime(2026, 9, 23), hoy),
        'Debe desde hace 12 días');
  });
}
