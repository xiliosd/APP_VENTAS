import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/repositories/fiado_repository.dart';
import 'package:app_ventas/repositories/gasto_repository.dart';
import 'package:app_ventas/repositories/resumen_repository.dart';
import 'package:app_ventas/repositories/venta_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late ResumenRepository repo;
  late VentaRepository ventaRepo;
  late GastoRepository gastoRepo;
  late int vendedor1;
  late int vendedor2;
  final dia = DateTime(2026, 9, 2, 10);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    ventaRepo = VentaRepository(db);
    gastoRepo = GastoRepository(db);
    repo = ResumenRepository(db, ventaRepo, gastoRepo, FiadoRepository(db));

    vendedor1 = await db.into(db.usuarios).insert(
          UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'x'),
        );
    vendedor2 = await db.into(db.usuarios).insert(
          UsuariosCompanion.insert(nombre: 'Beto', rol: 'vendedor', pinHash: 'y'),
        );
  });

  tearDown(() => db.close());

  test('resumenDelDia suma ventas y gastos, y por cobrar es la deuda pendiente', () async {
    await ventaRepo.registrarVenta(
        monto: 5000, esFiado: false, usuarioId: vendedor1, fecha: dia);
    await ventaRepo.registrarVenta(
        monto: 3000,
        esFiado: true,
        clienteId: await db
            .into(db.clientes)
            .insert(ClientesCompanion.insert(nombre: 'Don Pedro')),
        usuarioId: vendedor1,
        fecha: dia);
    await gastoRepo.registrarGasto(monto: 2000, usuarioId: vendedor1, fecha: dia);

    final resumen = await repo.resumenDelDia(dia);
    expect(resumen.totalVendido, 8000);
    expect(resumen.totalGastado, 2000);
    expect(resumen.totalPorCobrar, 3000);
  });

  test('resumenDelDia filtra por usuarioId', () async {
    await ventaRepo.registrarVenta(
        monto: 1000, esFiado: false, usuarioId: vendedor1, fecha: dia);
    await ventaRepo.registrarVenta(
        monto: 2000, esFiado: false, usuarioId: vendedor2, fecha: dia);

    final resumenVendedor1 = await repo.resumenDelDia(dia, usuarioId: vendedor1);
    expect(resumenVendedor1.totalVendido, 1000);
  });

  test('resumenPorVendedor incluye una entrada por cada usuario', () async {
    await ventaRepo.registrarVenta(
        monto: 1000, esFiado: false, usuarioId: vendedor1, fecha: dia);
    await ventaRepo.registrarVenta(
        monto: 2000, esFiado: false, usuarioId: vendedor2, fecha: dia);

    final mapa = await repo.resumenPorVendedor(dia);
    expect(mapa, hasLength(2));
    final totalesPorNombre = {
      for (final entrada in mapa.entries) entrada.key.nombre: entrada.value.totalVendido
    };
    expect(totalesPorNombre['Ana'], 1000);
    expect(totalesPorNombre['Beto'], 2000);
  });

  test(
      'totalPorCobrar es la deuda total al cierre del día, no solo lo fiado '
      'ese día', () async {
    final pedro = await db
        .into(db.clientes)
        .insert(ClientesCompanion.insert(nombre: 'Don Pedro'));
    final fiado = FiadoRepository(db);
    await ventaRepo.registrarVenta(
        monto: 4000,
        esFiado: true,
        clienteId: pedro,
        usuarioId: vendedor1,
        fecha: DateTime(2026, 9, 1, 10));
    await ventaRepo.registrarVenta(
        monto: 3000,
        esFiado: true,
        clienteId: pedro,
        usuarioId: vendedor1,
        fecha: dia);
    await fiado.registrarPago(
        clienteId: pedro, monto: 1000, usuarioId: vendedor1, fecha: dia);
    // Abono del día siguiente: no cuenta para el cierre de `dia`.
    await fiado.registrarPago(
        clienteId: pedro,
        monto: 500,
        usuarioId: vendedor1,
        fecha: DateTime(2026, 9, 3));

    final resumen = await repo.resumenDelDia(dia);
    expect(resumen.totalPorCobrar, 6000);
  });
}
