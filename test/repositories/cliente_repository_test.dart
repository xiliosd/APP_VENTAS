import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/repositories/cliente_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late ClienteRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ClienteRepository(db);
  });

  tearDown(() => db.close());

  test('crearCliente y obtenerCliente', () async {
    final id = await repo.crearCliente(nombre: 'Don Pedro', telefono: '3001234567');
    final cliente = await repo.obtenerCliente(id);

    expect(cliente?.nombre, 'Don Pedro');
    expect(cliente?.telefono, '3001234567');
  });

  test('crearCliente sin teléfono deja el campo nulo', () async {
    final id = await repo.crearCliente(nombre: 'Doña Rosa');
    final cliente = await repo.obtenerCliente(id);

    expect(cliente?.telefono, isNull);
  });

  test('listarClientes devuelve todos los clientes creados', () async {
    await repo.crearCliente(nombre: 'Don Pedro');
    await repo.crearCliente(nombre: 'Doña Rosa');

    expect(await repo.listarClientes(), hasLength(2));
  });

  test('obtenerCliente con id inexistente devuelve null', () async {
    expect(await repo.obtenerCliente(999), isNull);
  });

  test('obtenerOCrearCliente reutiliza un cliente con el mismo nombre',
      () async {
    final id = await repo.crearCliente(nombre: 'Don Pedro');

    expect(await repo.obtenerOCrearCliente('  don pedro '), id);
    expect(await repo.listarClientes(), hasLength(1));
  });

  test('obtenerOCrearCliente crea el cliente si no existe, sin espacios',
      () async {
    final id = await repo.obtenerOCrearCliente('  Doña Rosa ');

    final cliente = await repo.obtenerCliente(id);
    expect(cliente!.nombre, 'Doña Rosa');
  });
}
