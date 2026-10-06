import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/util/permisos.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const ana = Usuario(id: 1, nombre: 'Ana', rol: 'admin', pinHash: 'x');
  const beto = Usuario(id: 2, nombre: 'Beto', rol: 'vendedor', pinHash: 'y');
  final ahora = DateTime(2026, 10, 6, 15);

  bool puede(Usuario usuario, int duenoId, DateTime fecha) => puedeCorregir(
      usuario: usuario, duenoId: duenoId, fechaMovimiento: fecha, ahora: ahora);

  test('el administrador puede con cualquier movimiento de cualquier día', () {
    expect(puede(ana, 2, DateTime(2026, 9, 1)), isTrue);
    expect(puede(ana, 1, DateTime(2026, 10, 6, 8)), isTrue);
  });

  test('el vendedor puede con lo suyo de hoy', () {
    expect(puede(beto, 2, DateTime(2026, 10, 6, 0, 1)), isTrue);
  });

  test('el vendedor no puede con lo suyo de ayer', () {
    expect(puede(beto, 2, DateTime(2026, 10, 5, 23, 59)), isFalse);
  });

  test('el vendedor no puede con lo de otro aunque sea de hoy', () {
    expect(puede(beto, 1, DateTime(2026, 10, 6, 9)), isFalse);
  });
}
