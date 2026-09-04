import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/repositories/usuario_repository.dart';
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

  test('verificarPin acepta el PIN correcto y rechaza uno incorrecto', () async {
    final id = await repo.crearUsuario(nombre: 'Ana', rol: 'admin', pin: '1234');

    expect((await repo.verificarPin(id, '1234'))?.nombre, 'Ana');
    expect(await repo.verificarPin(id, '0000'), isNull);
  });

  test('resetearPin cambia el PIN vigente', () async {
    final id = await repo.crearUsuario(nombre: 'Ana', rol: 'admin', pin: '1234');
    await repo.resetearPin(id, '9999');

    expect(await repo.verificarPin(id, '1234'), isNull);
    expect((await repo.verificarPin(id, '9999'))?.nombre, 'Ana');
  });
}
