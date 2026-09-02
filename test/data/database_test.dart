import 'package:app_ventas/data/database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('creates tables and can insert/read a usuario', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final id = await db.into(db.usuarios).insert(
          UsuariosCompanion.insert(
            nombre: 'Admin',
            rol: 'admin',
            pinHash: 'hash',
          ),
        );

    final usuarios = await db.select(db.usuarios).get();
    expect(usuarios, hasLength(1));
    expect(usuarios.single.id, id);
    expect(usuarios.single.nombre, 'Admin');
  });
}
