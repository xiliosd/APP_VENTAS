import 'dart:io';

import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/respaldo/copia_base_datos.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Directory carpeta;

  setUp(() async => carpeta = await Directory.systemTemp.createTemp('copia'));
  tearDown(() => carpeta.delete(recursive: true));

  test('crearCopia produce una copia válida con los mismos datos', () async {
    final db = AppDatabase(NativeDatabase.memory());
    await db.into(db.usuarios).insert(
        UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'x'));

    final copia = await CopiaBaseDatos.crearCopia(db, carpeta);
    await db.close();

    expect(CopiaBaseDatos.esCopiaValida(copia, versionMaxima: 1), isTrue);
    final abierta = AppDatabase(NativeDatabase(copia));
    expect((await abierta.select(abierta.usuarios).get()).single.nombre, 'Ana');
    await abierta.close();
  });

  test('crearCopia reemplaza la copia anterior', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final primera = await CopiaBaseDatos.crearCopia(db, carpeta);
    final segunda = await CopiaBaseDatos.crearCopia(db, carpeta);
    await db.close();

    expect(segunda.path, primera.path);
    expect(segunda.existsSync(), isTrue);
  });

  test('esCopiaValida rechaza un archivo que no es una base', () {
    final basura = File('${carpeta.path}/basura.sqlite')
      ..writeAsStringSync('esto no es sqlite');
    expect(CopiaBaseDatos.esCopiaValida(basura, versionMaxima: 1), isFalse);
  });

  test('esCopiaValida rechaza una base sin las tablas de la app', () {
    final archivo = File('${carpeta.path}/vacia.sqlite');
    sqlite3.open(archivo.path)
      ..execute('CREATE TABLE otra (id INTEGER)')
      ..close();
    expect(CopiaBaseDatos.esCopiaValida(archivo, versionMaxima: 1), isFalse);
  });

  test('esCopiaValida rechaza una copia de una versión más nueva', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final copia = await CopiaBaseDatos.crearCopia(db, carpeta);
    await db.close();
    sqlite3.open(copia.path)
      ..userVersion = 99
      ..close();

    expect(CopiaBaseDatos.esCopiaValida(copia, versionMaxima: 1), isFalse);
  });

  test('esCopiaValida rechaza un archivo que no existe', () {
    expect(
        CopiaBaseDatos.esCopiaValida(File('${carpeta.path}/nada.sqlite'),
            versionMaxima: 1),
        isFalse);
  });
}
