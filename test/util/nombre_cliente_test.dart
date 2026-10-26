import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/util/nombre_cliente.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('nombreCompleto une nombre y apellido', () {
    const cliente = Cliente(id: 1, nombre: 'Juan', apellido: 'Pérez');
    expect(cliente.nombreCompleto, 'Juan Pérez');
  });

  test('nombreCompleto sin apellido es el nombre', () {
    expect(
      const Cliente(id: 1, nombre: 'Don Pedro').nombreCompleto,
      'Don Pedro',
    );
    expect(
      const Cliente(id: 1, nombre: 'Don Pedro', apellido: '').nombreCompleto,
      'Don Pedro',
    );
  });

  test('claveCliente ignora mayúsculas, tildes y espacios', () {
    expect(claveCliente('  José   PÉREZ '), claveCliente('jose perez'));
  });

  test('telefonoNormalizado', () {
    expect(telefonoNormalizado('300 123 4567'), '3001234567');
    expect(telefonoNormalizado('+57 300-123-4567'), '3001234567');
    expect(telefonoNormalizado('  '), isNull);
    expect(telefonoNormalizado(null), isNull);
  });
}
