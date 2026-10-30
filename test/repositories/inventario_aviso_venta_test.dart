import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/repositories/inventario_repository.dart';
import 'package:app_ventas/repositories/producto_repository.dart';
import 'package:app_ventas/repositories/venta_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late InventarioRepository repo;
  late Usuario ana;
  late int arroz;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = InventarioRepository(db, reloj: () => DateTime(2026, 10, 7, 8));
    final id = await db
        .into(db.usuarios)
        .insert(
          UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'x'),
        );
    ana = await (db.select(
      db.usuarios,
    )..where((u) => u.id.equals(id))).getSingle();
    arroz = await ProductoRepository(db)
        .guardarProducto(nombre: 'Arroz', precio: 1000);
    await repo.activarControl(arroz, cantidad: 4, minimo: 3, por: ana);
  });

  tearDown(() => db.close());

  Future<int> vender(int cantidad) => VentaRepository(db).registrarVenta(
    monto: 1000 * cantidad,
    esFiado: false,
    usuarioId: ana.id,
    fecha: DateTime(2026, 10, 7, 9),
    lineas: [
      LineaNueva(
        productoId: arroz,
        descripcion: 'Arroz',
        precioUnitario: 1000,
        cantidad: cantidad,
      ),
    ],
  );

  test(
    'avisosTrasVenta detecta el cruce tras registrarVenta de 2 unidades',
    () async {
      final antes = await repo.existenciasDe([arroz]);
      await vender(2);

      final avisos = await repo.avisosTrasVenta(antes);

      expect(avisos.single.texto, 'Quedan 2 Arroz: toca pedir');
    },
  );

  test('avisosVigentes descarta el aviso después de eliminarVenta', () async {
    final antes = await repo.existenciasDe([arroz]);
    final ventaId = await vender(2);
    final avisos = await repo.avisosTrasVenta(antes);
    expect(await repo.avisosVigentes(avisos), hasLength(1));

    await VentaRepository(db).eliminarVenta(ventaId);

    expect(await repo.avisosVigentes(avisos), isEmpty);
  });
}
