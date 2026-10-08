import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/repositories/venta_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late VentaRepository repo;
  late int ana;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = VentaRepository(db);
    ana = await db.into(db.usuarios).insert(
        UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'x'));
  });
  tearDown(() => db.close());

  for (final (nombre, cantidad, precio) in [
    ('cantidad 0', 0, 1000),
    ('cantidad negativa', -1, 1000),
    ('precio 0', 1, 0),
  ]) {
    test('rechaza una línea con $nombre sin guardar nada', () async {
      await expectLater(
        repo.registrarVenta(
          monto: cantidad * precio,
          esFiado: false,
          usuarioId: ana,
          lineas: [
            LineaNueva(
                descripcion: 'Arepa', precioUnitario: precio, cantidad: cantidad),
          ],
        ),
        throwsArgumentError,
      );
      expect(await db.select(db.ventas).get(), isEmpty);
    });
  }
}
