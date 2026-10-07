import 'dart:typed_data';

import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/repositories/configuracion_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late ConfiguracionRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ConfiguracionRepository(db);
  });
  tearDown(() => db.close());

  test('sin QR cargado devuelve null', () async {
    expect(await repo.imagenQr(), isNull);
  });

  test('guardar, reemplazar y quitar el QR', () async {
    await repo.guardarImagenQr(Uint8List.fromList([1, 2, 3]));
    expect(await repo.imagenQr(), [1, 2, 3]);

    await repo.guardarImagenQr(Uint8List.fromList([9]));
    expect(await repo.imagenQr(), [9]);
    expect(await db.select(db.configuracionTienda).get(), hasLength(1));

    await repo.quitarImagenQr();
    expect(await repo.imagenQr(), isNull);
  });

  test('observarImagenQr emite los cambios', () async {
    final emitidos = <Uint8List?>[];
    final sub = repo.observarImagenQr().listen(emitidos.add);
    await pumpEventQueue();
    await repo.guardarImagenQr(Uint8List.fromList([7]));
    await pumpEventQueue();
    await sub.cancel();

    expect(emitidos.first, isNull);
    expect(emitidos.last, [7]);
  });

  test('guarda el nombre de la tienda recortado y lo lee', () async {
    await repo.guardarNombreTienda('  La Esquina  ');
    expect(await repo.nombreTienda(), 'La Esquina');
  });

  test('sin guardar no hay nombre de tienda', () async {
    expect(await repo.nombreTienda(), isNull);
  });

  test('un nombre vacío, de solo espacios o muy largo se rechaza', () async {
    await expectLater(repo.guardarNombreTienda(''), throwsArgumentError);
    await expectLater(repo.guardarNombreTienda('   '), throwsArgumentError);
    await expectLater(
        repo.guardarNombreTienda('x' * 41), throwsArgumentError);
    expect(await repo.nombreTienda(), isNull);
    expect(errorNombreTienda(''), 'Escribe el nombre de tu tienda');
    expect(errorNombreTienda('x' * 41), 'Máximo 40 caracteres');
    expect(errorNombreTienda('x' * 40), isNull);
  });

  test('el nombre de la tienda y el QR no se borran entre sí', () async {
    final qr = Uint8List.fromList([1, 2, 3]);
    await repo.guardarImagenQr(qr);
    await repo.guardarNombreTienda('La Esquina');
    expect(await repo.imagenQr(), qr);

    await repo.guardarImagenQr(Uint8List.fromList([4]));
    expect(await repo.nombreTienda(), 'La Esquina');
  });
}
