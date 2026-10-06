import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/repositories/fiado_repository.dart';
import 'package:app_ventas/repositories/gasto_repository.dart';
import 'package:app_ventas/repositories/resumen_repository.dart';
import 'package:app_ventas/repositories/venta_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late VentaRepository ventas;
  late GastoRepository gastos;
  late FiadoRepository fiado;
  late ResumenRepository resumen;
  late int ana;
  late int pedro;
  final dia = DateTime(2026, 10, 6);
  DateTime a(int hora) => DateTime(2026, 10, 6, hora);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    ventas = VentaRepository(db);
    gastos = GastoRepository(db);
    fiado = FiadoRepository(db);
    resumen = ResumenRepository(db, ventas, gastos, fiado);
    ana = await db.into(db.usuarios).insert(
        UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'x'));
    pedro = await db
        .into(db.clientes)
        .insert(ClientesCompanion.insert(nombre: 'Don Pedro'));
  });

  tearDown(() => db.close());

  Future<void> anular(String tabla, int id) => db.customStatement(
      'UPDATE $tabla SET anulado = 1 WHERE id = ?', [id]);

  /// Un día con un movimiento anulado de cada clase y otros vigentes.
  Future<({int fiadaVigente, int pagoAnulado})> cargarDia() async {
    final contadoAnulada = await ventas.registrarVenta(
        monto: 5000, esFiado: false, usuarioId: ana, fecha: a(8));
    await ventas.registrarVenta(
        monto: 3000,
        esFiado: false,
        usuarioId: ana,
        fecha: a(9),
        medioPago: MedioPago.transferencia);
    final fiadaAnulada = await ventas.registrarVenta(
        monto: 2000, esFiado: true, clienteId: pedro, usuarioId: ana, fecha: a(7));
    final fiadaVigente = await ventas.registrarVenta(
        monto: 4000, esFiado: true, clienteId: pedro, usuarioId: ana, fecha: a(10));
    final pagoAnulado = await fiado.registrarPago(
        clienteId: pedro, monto: 1000, usuarioId: ana, fecha: a(11));
    final gastoAnulado =
        await gastos.registrarGasto(monto: 700, usuarioId: ana, fecha: a(12));
    await gastos.registrarGasto(monto: 300, usuarioId: ana, fecha: a(13));
    await anular('ventas', contadoAnulada);
    await anular('ventas', fiadaAnulada);
    await anular('pagos_fiado', pagoAnulado);
    await anular('gastos', gastoAnulado);
    return (fiadaVigente: fiadaVigente, pagoAnulado: pagoAnulado);
  }

  test('el resumen del día no cuenta lo anulado', () async {
    await cargarDia();
    final r = await resumen.resumenDelDia(dia);
    expect(r.totalVendido, 7000);
    expect(r.cantidadVentas, 2);
    expect(r.cantidadFiadas, 1);
    expect(r.recibidoEfectivo, 0);
    expect(r.recibidoTransferencia, 3000);
    expect(r.totalGastado, 300);
    expect(r.totalPorCobrar, 4000);
    expect(r.clientesConDeuda, 1);
  });

  test('el resumen por vendedor no cuenta lo anulado', () async {
    await cargarDia();
    final porVendedor = await resumen.resumenPorVendedor(dia);
    expect(porVendedor.values.single.totalVendido, 7000);
  });

  test('el saldo y la lista de Fiado no cuentan lo anulado', () async {
    await cargarDia();
    expect(await fiado.saldoCliente(pedro), 4000);
    final lista = await fiado.listaClientesConDeuda();
    expect(lista.single.saldo, 4000);
    expect(lista.single.fechaDeudaMasAntigua, a(10));
  });

  test('anular la única venta fiada saca al cliente de Fiado', () async {
    final id = await ventas.registrarVenta(
        monto: 2000, esFiado: true, clienteId: pedro, usuarioId: ana, fecha: a(7));
    await anular('ventas', id);
    expect(await fiado.listaClientesConDeuda(), isEmpty);
    expect(await fiado.deudaTotalAl(dia), 0);
    expect(await fiado.clientesConDeudaAl(dia), 0);
  });

  test('las listas traen lo anulado solo si se pide', () async {
    final ids = await cargarDia();
    expect(await ventas.ventasDelDia(dia), hasLength(2));
    expect(await ventas.ventasDelDia(dia, incluirAnulados: true), hasLength(4));
    expect(await gastos.gastosDelDia(dia), hasLength(1));
    expect(await gastos.gastosDelDia(dia, incluirAnulados: true), hasLength(2));
    expect(await fiado.pagosDelDia(dia), isEmpty);
    expect((await fiado.ventasFiadasCliente(pedro)).map((v) => v.id),
        [ids.fiadaVigente]);
    expect(await fiado.ventasFiadasCliente(pedro, incluirAnulados: true),
        hasLength(2));
    expect(await fiado.pagosCliente(pedro), isEmpty);
    expect((await fiado.pagosCliente(pedro, incluirAnulados: true)).single.id,
        ids.pagoAnulado);
  });
}
