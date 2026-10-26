import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/repositories/cliente_repository.dart';
import 'package:drift/drift.dart' hide isNull;
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

  test('crearCliente guarda nombre, apellido y teléfono normalizado', () async {
    final id = await repo.crearCliente(
      nombre: ' Pedro ',
      apellido: ' Gómez ',
      telefono: '300 123 4567',
      notas: '  ',
    );
    final cliente = await repo.obtenerCliente(id);

    expect(cliente?.nombre, 'Pedro');
    expect(cliente?.apellido, 'Gómez');
    expect(cliente?.telefono, '3001234567');
    expect(cliente?.notas, isNull);
  });

  test('crearCliente sin teléfono deja el campo nulo', () async {
    final id = await repo.crearCliente(nombre: 'Rosa', apellido: 'Díaz');
    final cliente = await repo.obtenerCliente(id);

    expect(cliente?.telefono, isNull);
  });

  test('crearCliente exige nombre y apellido', () async {
    await expectLater(
      repo.crearCliente(nombre: 'Juan', apellido: '  '),
      throwsArgumentError,
    );
    await expectLater(
      repo.crearCliente(nombre: ' ', apellido: 'Pérez'),
      throwsArgumentError,
    );
    expect(await repo.listarClientes(), isEmpty);
  });

  test('listarClientes devuelve todos los clientes creados', () async {
    await repo.crearCliente(nombre: 'Pedro', apellido: 'Gómez');
    await repo.crearCliente(nombre: 'Rosa', apellido: 'Díaz');

    expect(await repo.listarClientes(), hasLength(2));
  });

  test('obtenerCliente con id inexistente devuelve null', () async {
    expect(await repo.obtenerCliente(999), isNull);
  });

  test('clientesParecidos encuentra el mismo nombre completo sin tildes ni '
      'mayúsculas', () async {
    final id = await repo.crearCliente(nombre: 'José', apellido: 'Pérez');

    final parecidos = await repo.clientesParecidos(
      nombre: ' jose ',
      apellido: 'PEREZ',
    );

    expect(parecidos.single.id, id);
  });

  test('clientesParecidos encuentra un cliente antiguo sin apellido con el '
      'nombre completo', () async {
    final viejo = await db
        .into(db.clientes)
        .insert(ClientesCompanion.insert(nombre: 'Juan Pérez'));

    final parecidos = await repo.clientesParecidos(
      nombre: 'juan',
      apellido: 'perez',
    );

    expect(parecidos.single.id, viejo);
  });

  test(
    'clientesParecidos encuentra el mismo teléfono con otro nombre',
    () async {
      final id = await repo.crearCliente(
        nombre: 'Pedro',
        apellido: 'Gómez',
        telefono: '3001234567',
      );

      final parecidos = await repo.clientesParecidos(
        nombre: 'Luis',
        apellido: 'Rojas',
        telefono: '+57 300 123 4567',
      );

      expect(parecidos.single.id, id);
    },
  );

  test('clientesParecidos excluye al cliente que se edita (salvo)', () async {
    final id = await repo.crearCliente(nombre: 'Pedro', apellido: 'Gómez');

    final parecidos = await repo.clientesParecidos(
      nombre: 'Pedro',
      apellido: 'Gómez',
      salvo: id,
    );

    expect(parecidos, isEmpty);
  });

  test('clientesParecidos sin coincidencias devuelve vacío', () async {
    await repo.crearCliente(
      nombre: 'Pedro',
      apellido: 'Gómez',
      telefono: '3001234567',
    );

    expect(
      await repo.clientesParecidos(
        nombre: 'Luis',
        apellido: 'Rojas',
        telefono: '3109999999',
      ),
      isEmpty,
    );
    expect(
      await repo.clientesParecidos(nombre: 'Luis', apellido: 'Rojas'),
      isEmpty,
    );
  });

  test('clientesParecidos ordena A–Z por nombre completo', () async {
    await repo.crearCliente(
      nombre: 'Zoila',
      apellido: 'Ruiz',
      telefono: '3001234567',
    );
    await repo.crearCliente(
      nombre: 'Ana',
      apellido: 'Mora',
      telefono: '3001234567',
    );

    final parecidos = await repo.clientesParecidos(
      nombre: 'Otro',
      apellido: 'Nombre',
      telefono: '3001234567',
    );

    expect(parecidos.map((c) => c.nombre), ['Ana', 'Zoila']);
  });

  test('actualizarCliente cambia datos y exige apellido', () async {
    final id = await repo.crearCliente(nombre: 'Pedro', apellido: 'Gómez');

    await repo.actualizarCliente(
      id,
      nombre: ' Pablo ',
      apellido: 'Gil',
      telefono: '310 111 2222',
      notas: ' paga los viernes ',
    );
    final cliente = await repo.obtenerCliente(id);

    expect(cliente?.nombre, 'Pablo');
    expect(cliente?.apellido, 'Gil');
    expect(cliente?.telefono, '3101112222');
    expect(cliente?.notas, 'paga los viernes');

    await expectLater(
      repo.actualizarCliente(id, nombre: 'Pablo', apellido: ''),
      throwsArgumentError,
    );
    await expectLater(
      repo.actualizarCliente(id, nombre: '', apellido: 'Gil'),
      throwsArgumentError,
    );
  });

  test(
    'comprasCliente trae contado y fiado sin anuladas, recientes primero',
    () async {
      final usuario = await db
          .into(db.usuarios)
          .insert(
            UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'x'),
          );
      final cliente = await repo.crearCliente(
        nombre: 'Pedro',
        apellido: 'Gómez',
      );
      final otro = await repo.crearCliente(nombre: 'Rosa', apellido: 'Díaz');

      Future<int> venta(
        DateTime fecha, {
        int? clienteId,
        bool fiado = false,
        bool anulado = false,
      }) {
        return db
            .into(db.ventas)
            .insert(
              VentasCompanion.insert(
                monto: 1000,
                fecha: fecha,
                usuarioId: usuario,
                clienteId: Value(clienteId),
                esFiado: Value(fiado),
                anulado: Value(anulado),
              ),
            );
      }

      final antigua = await venta(DateTime(2026, 10, 1), clienteId: cliente);
      final reciente = await venta(
        DateTime(2026, 10, 5),
        clienteId: cliente,
        fiado: true,
      );
      await venta(DateTime(2026, 10, 3), clienteId: cliente, anulado: true);
      await venta(DateTime(2026, 10, 4), clienteId: otro);
      await venta(DateTime(2026, 10, 6));

      final compras = await repo.comprasCliente(cliente);

      expect(compras.map((v) => v.id), [reciente, antigua]);
    },
  );

  test('nombresPorId devuelve el nombre completo', () async {
    final id = await repo.crearCliente(nombre: 'Pedro', apellido: 'Gómez');

    expect(await repo.nombresPorId([id]), {id: 'Pedro Gómez'});
    expect(await repo.nombresPorId([]), isEmpty);
  });
}
