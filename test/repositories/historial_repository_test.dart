import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/repositories/gasto_repository.dart';
import 'package:app_ventas/repositories/historial_repository.dart';
import 'package:app_ventas/repositories/venta_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late VentaRepository ventaRepo;
  late GastoRepository gastoRepo;
  late HistorialRepository repo;
  late int ana;
  late int beto;
  final dia = DateTime(2026, 9, 2);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    ventaRepo = VentaRepository(db);
    gastoRepo = GastoRepository(db);
    repo = HistorialRepository(ventaRepo, gastoRepo);
    ana = await db.into(db.usuarios).insert(
          UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'x'),
        );
    beto = await db.into(db.usuarios).insert(
          UsuariosCompanion.insert(nombre: 'Beto', rol: 'vendedor', pinHash: 'y'),
        );
  });

  tearDown(() => db.close());

  Future<void> cargarDia() async {
    await ventaRepo.registrarVenta(
        monto: 5000, esFiado: false, usuarioId: ana, fecha: DateTime(2026, 9, 2, 9));
    await ventaRepo.registrarVenta(
        monto: 3000, esFiado: true, usuarioId: beto, fecha: DateTime(2026, 9, 2, 10));
    await gastoRepo.registrarGasto(
        monto: 1000,
        descripcion: 'Hielo',
        usuarioId: beto,
        fecha: DateTime(2026, 9, 2, 11));
  }

  test('movimientosDelDia mezcla ventas y gastos, más reciente primero',
      () async {
    await cargarDia();

    final movimientos = await repo.movimientosDelDia(dia);

    expect(movimientos.map((m) => m.monto), [1000, 3000, 5000]);
    expect(movimientos[0].tipo, TipoMovimientoHistorial.gasto);
    expect(movimientos[0].descripcion, 'Hielo');
    expect(movimientos[0].esFiado, isFalse);
    expect(movimientos[1].tipo, TipoMovimientoHistorial.venta);
    expect(movimientos[1].esFiado, isTrue);
    expect(movimientos[2].usuarioId, ana);
  });

  test('movimientosDelDia filtra por usuario', () async {
    await cargarDia();

    final movimientos = await repo.movimientosDelDia(dia, usuarioId: beto);

    expect(movimientos.map((m) => m.monto), [1000, 3000]);
    expect(movimientos.every((m) => m.usuarioId == beto), isTrue);
  });

  test('movimientosDelDia excluye otros días y conserva gastos sin descripción',
      () async {
    await ventaRepo.registrarVenta(
        monto: 111, esFiado: false, usuarioId: ana, fecha: DateTime(2026, 9, 1, 23, 59));
    await ventaRepo.registrarVenta(
        monto: 222, esFiado: false, usuarioId: ana, fecha: DateTime(2026, 9, 3));
    await gastoRepo.registrarGasto(
        monto: 500, usuarioId: ana, fecha: DateTime(2026, 9, 2, 8));

    final movimientos = await repo.movimientosDelDia(dia);

    expect(movimientos, hasLength(1));
    expect(movimientos.single.monto, 500);
    expect(movimientos.single.descripcion, isNull);
  });

  test('las ventas del historial llevan su medio de pago', () async {
    await ventaRepo.registrarVenta(
        monto: 4000,
        esFiado: false,
        usuarioId: ana,
        fecha: dia,
        medioPago: MedioPago.transferencia);

    final movimientos = await repo.movimientosDelDia(dia);

    expect(movimientos.single.medioPago, MedioPago.transferencia);
  });
}
