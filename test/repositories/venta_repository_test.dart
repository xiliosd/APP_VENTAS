import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/repositories/venta_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late VentaRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = VentaRepository(db);
  });

  tearDown(() => db.close());

  Future<int> crearUsuario() {
    return db.into(db.usuarios).insert(
          UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'x'),
        );
  }

  test('registrarVenta guarda una venta de contado', () async {
    final usuarioId = await crearUsuario();
    await repo.registrarVenta(
      monto: 5000,
      esFiado: false,
      usuarioId: usuarioId,
      fecha: DateTime(2026, 9, 2, 10),
    );

    final ventas = await repo.ventasDelDia(DateTime(2026, 9, 2));
    expect(ventas, hasLength(1));
    expect(ventas.single.monto, 5000);
    expect(ventas.single.esFiado, isFalse);
  });

  test('ventasDelDia solo trae ventas de ese día', () async {
    final usuarioId = await crearUsuario();
    await repo.registrarVenta(
      monto: 1000,
      esFiado: false,
      usuarioId: usuarioId,
      fecha: DateTime(2026, 9, 1, 23, 59),
    );
    await repo.registrarVenta(
      monto: 2000,
      esFiado: false,
      usuarioId: usuarioId,
      fecha: DateTime(2026, 9, 2, 0, 1),
    );

    final ventas = await repo.ventasDelDia(DateTime(2026, 9, 2));
    expect(ventas, hasLength(1));
    expect(ventas.single.monto, 2000);
  });

  test('ventasDelDia filtra por usuarioId cuando se indica', () async {
    final vendedor1 = await crearUsuario();
    final vendedor2 = await db.into(db.usuarios).insert(
          UsuariosCompanion.insert(nombre: 'Beto', rol: 'vendedor', pinHash: 'y'),
        );
    final dia = DateTime(2026, 9, 2, 10);
    await repo.registrarVenta(
        monto: 1000, esFiado: false, usuarioId: vendedor1, fecha: dia);
    await repo.registrarVenta(
        monto: 2000, esFiado: false, usuarioId: vendedor2, fecha: dia);

    final ventasVendedor1 = await repo.ventasDelDia(dia, usuarioId: vendedor1);
    expect(ventasVendedor1, hasLength(1));
    expect(ventasVendedor1.single.monto, 1000);
  });

  test('eliminarVenta borra solo esa venta', () async {
    final usuarioId = await crearUsuario();
    final id1 = await repo.registrarVenta(
        monto: 1000, esFiado: false, usuarioId: usuarioId);
    final id2 = await repo.registrarVenta(
        monto: 2000, esFiado: false, usuarioId: usuarioId);

    await repo.eliminarVenta(id1);

    final ventas = await db.select(db.ventas).get();
    expect(ventas.map((v) => v.id), [id2]);
  });

  test('registrarVenta guarda el medio de pago (efectivo por defecto)',
      () async {
    final usuarioId = await db.into(db.usuarios).insert(
        UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'x'));
    final a = await repo.registrarVenta(
        monto: 1000, esFiado: false, usuarioId: usuarioId);
    final b = await repo.registrarVenta(
        monto: 2000,
        esFiado: false,
        usuarioId: usuarioId,
        medioPago: MedioPago.transferencia);

    final ventas = await db.select(db.ventas).get();
    expect(ventas.firstWhere((v) => v.id == a).medioPago, MedioPago.efectivo);
    expect(ventas.firstWhere((v) => v.id == b).medioPago,
        MedioPago.transferencia);
  });
}
