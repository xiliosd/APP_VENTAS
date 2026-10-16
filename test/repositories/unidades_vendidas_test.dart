import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/repositories/producto_repository.dart';
import 'package:app_ventas/repositories/venta_repository.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late ProductoRepository productos;
  late int ana;
  late int pan;
  late int leche;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    productos = ProductoRepository(db);
    ana = await db
        .into(db.usuarios)
        .insert(
          UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'x'),
        );
    pan = await productos.guardarProducto(nombre: 'Pan', precio: 500);
    leche = await productos.guardarProducto(nombre: 'Leche', precio: 4000);
  });

  tearDown(() => db.close());

  Future<int> vender(int producto, int cantidad, DateTime fecha) =>
      VentaRepository(db).registrarVenta(
        monto: 500 * cantidad,
        esFiado: false,
        usuarioId: ana,
        fecha: fecha,
        lineas: [
          LineaNueva(
            productoId: producto,
            descripcion: 'x',
            precioUnitario: 500,
            cantidad: cantidad,
          ),
        ],
      );

  test('suma unidades desde la fecha y no cuenta lo anulado', () async {
    await vender(pan, 3, DateTime(2026, 10, 10));
    await vender(pan, 2, DateTime(2026, 10, 15));
    await vender(leche, 1, DateTime(2026, 10, 15));
    final anulada = await vender(leche, 9, DateTime(2026, 10, 15));
    await (db.update(db.ventas)..where((v) => v.id.equals(anulada))).write(
      const VentasCompanion(anulado: Value(true)),
    );
    // Antes del periodo: no cuenta.
    await vender(pan, 50, DateTime(2026, 9, 1));

    expect(
      await productos.unidadesVendidas(desde: DateTime(2026, 9, 16)),
      {pan: 5, leche: 1},
    );
  });
}
