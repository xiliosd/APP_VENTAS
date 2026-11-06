import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/repositories/usuario_repository.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late UsuarioRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = UsuarioRepository(db);
  });

  tearDown(() => db.close());

  test('no usuarios inicialmente', () async {
    expect(await repo.existeAlgunUsuario(), isFalse);
  });

  test('crear usuario y listar', () async {
    await repo.crearUsuario(nombre: 'Ana', rol: 'admin', pin: '1234');
    final usuarios = await repo.listarUsuarios();
    expect(usuarios, hasLength(1));
    expect(usuarios.single.nombre, 'Ana');
    expect(usuarios.single.rol, 'admin');
    expect(await repo.existeAlgunUsuario(), isTrue);
  });

  test(
    'verificarPin acepta el PIN correcto y rechaza uno incorrecto',
    () async {
      final id = await repo.crearUsuario(
        nombre: 'Ana',
        rol: 'admin',
        pin: '1234',
      );

      expect((await repo.verificarPin(id, '1234'))?.nombre, 'Ana');
      expect(await repo.verificarPin(id, '0000'), isNull);
    },
  );

  test('resetearPin cambia el PIN vigente', () async {
    final id = await repo.crearUsuario(
      nombre: 'Ana',
      rol: 'admin',
      pin: '1234',
    );
    await repo.resetearPin(id, '9999');

    expect(await repo.verificarPin(id, '1234'), isNull);
    expect((await repo.verificarPin(id, '9999'))?.nombre, 'Ana');
  });

  test('un usuario desactivado no entra con su PIN', () async {
    final id = await repo.crearUsuario(
      nombre: 'Beto',
      rol: 'vendedor',
      pin: '1234',
    );

    await repo.desactivar(id);

    expect(await repo.verificarPin(id, '1234'), isNull);
  });

  test('listarActivos omite a los desactivados', () async {
    await repo.crearUsuario(nombre: 'Ana', rol: 'admin', pin: '1111');
    final beto = await repo.crearUsuario(
      nombre: 'Beto',
      rol: 'vendedor',
      pin: '1234',
    );
    await repo.desactivar(beto);

    expect([for (final u in await repo.listarActivos()) u.nombre], ['Ana']);
    expect(await repo.listarUsuarios(), hasLength(2));
  });

  test('el siguiente número de vendedor es el mayor más uno', () async {
    expect(await repo.siguienteNumeroVendedor(), 1);
    await repo.crearUsuario(
      nombre: 'Beto',
      rol: 'vendedor',
      pin: '1234',
      numeroVendedor: 1,
    );
    await repo.crearUsuario(
      nombre: 'Caro',
      rol: 'vendedor',
      pin: '1234',
      numeroVendedor: 4,
    );

    expect(await repo.siguienteNumeroVendedor(), 5);
  });

  test('resetear el PIN sube su versión', () async {
    final id = await repo.crearUsuario(
      nombre: 'Ana',
      rol: 'admin',
      pin: '1234',
    );

    await repo.resetearPin(id, '9999');
    await repo.resetearPin(id, '8888');

    final usuario = (await repo.listarUsuarios()).single;
    expect(usuario.versionPin, 2);
  });

  test('guardarPinLocal deja entrar sin internet la próxima vez', () async {
    final id = await repo.crearUsuario(
      nombre: 'Ana',
      rol: 'admin',
      pin: '1234',
    );
    await (db.update(db.usuarios)..where((u) => u.id.equals(id))).write(
      const UsuariosCompanion(pinHash: Value('')),
    );
    expect(await repo.verificarPin(id, '1234'), isNull);

    await repo.guardarPinLocal(id, '1234');

    expect((await repo.verificarPin(id, '1234'))?.nombre, 'Ana');
  });

  test('activar devuelve el acceso a un usuario desactivado', () async {
    final id = await repo.crearUsuario(
      nombre: 'Beto',
      rol: 'vendedor',
      pin: '1234',
    );
    await repo.desactivar(id);

    await repo.activar(id);

    expect((await repo.verificarPin(id, '1234'))?.nombre, 'Beto');
  });
}
