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
}
