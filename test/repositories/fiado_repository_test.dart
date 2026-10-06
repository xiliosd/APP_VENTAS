import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/repositories/correccion_repository.dart';
import 'package:app_ventas/repositories/fiado_repository.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late FiadoRepository repo;
  late int usuarioId;
  late int clienteId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = FiadoRepository(db);
    usuarioId = await db.into(db.usuarios).insert(
          UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'x'),
        );
    clienteId = await db.into(db.clientes).insert(
          ClientesCompanion.insert(nombre: 'Don Pedro'),
        );
  });

  tearDown(() => db.close());

  Future<void> venderFiado(int monto, DateTime fecha) {
    return db.into(db.ventas).insert(
          VentasCompanion.insert(
            monto: monto,
            fecha: fecha,
            esFiado: const Value(true),
            clienteId: Value(clienteId),
            usuarioId: usuarioId,
          ),
        );
  }

  test('saldoCliente es la suma de ventas fiadas menos pagos', () async {
    await venderFiado(5000, DateTime(2026, 9, 1));
    await venderFiado(3000, DateTime(2026, 9, 2));
    await repo.registrarPago(clienteId: clienteId, monto: 2000, usuarioId: usuarioId);

    expect(await repo.saldoCliente(clienteId), 6000);
  });

  test('saldoCliente es 0 para un cliente sin ventas fiadas', () async {
    expect(await repo.saldoCliente(clienteId), 0);
  });

  test('listaClientesConDeuda excluye clientes con saldo 0 o negativo', () async {
    await venderFiado(5000, DateTime(2026, 9, 1));
    await repo.registrarPago(clienteId: clienteId, monto: 5000, usuarioId: usuarioId);

    expect(await repo.listaClientesConDeuda(), isEmpty);
  });

  test('listaClientesConDeuda ordena por la deuda más antigua primero', () async {
    final clienteReciente = await db.into(db.clientes).insert(
          ClientesCompanion.insert(nombre: 'Doña Rosa'),
        );
    await venderFiado(1000, DateTime(2026, 9, 2)); // Don Pedro, más reciente
    await db.into(db.ventas).insert(
          VentasCompanion.insert(
            monto: 1000,
            fecha: DateTime(2026, 8, 15), // Doña Rosa, más antigua
            esFiado: const Value(true),
            clienteId: Value(clienteReciente),
            usuarioId: usuarioId,
          ),
        );

    final lista = await repo.listaClientesConDeuda();
    expect(lista, hasLength(2));
    expect(lista.first.cliente.nombre, 'Doña Rosa');
    expect(lista.last.cliente.nombre, 'Don Pedro');
  });

  test('registrarPago y pagosCliente/ventasFiadasCliente devuelven el historial',
      () async {
    await venderFiado(5000, DateTime(2026, 9, 1));
    await repo.registrarPago(
      clienteId: clienteId,
      monto: 2000,
      usuarioId: usuarioId,
      fecha: DateTime(2026, 9, 2),
    );

    expect(await repo.ventasFiadasCliente(clienteId), hasLength(1));
    final pagos = await repo.pagosCliente(clienteId);
    expect(pagos, hasLength(1));
    expect(pagos.single.monto, 2000);
  });

  test(
      'movimientosCliente mezcla ventas fiadas y abonos del cliente, '
      'más reciente primero', () async {
    await venderFiado(5000, DateTime(2026, 9, 1));
    await repo.registrarPago(
      clienteId: clienteId,
      monto: 2000,
      usuarioId: usuarioId,
      fecha: DateTime(2026, 9, 2),
    );
    await venderFiado(1000, DateTime(2026, 9, 3));
    // Venta de contado del mismo cliente: no es fiado, no debe aparecer.
    await db.into(db.ventas).insert(
          VentasCompanion.insert(
            monto: 9999,
            fecha: DateTime(2026, 9, 4),
            clienteId: Value(clienteId),
            usuarioId: usuarioId,
          ),
        );
    // Abono de otro cliente: no debe aparecer.
    final otroCliente = await db.into(db.clientes).insert(
          ClientesCompanion.insert(nombre: 'Doña Rosa'),
        );
    await repo.registrarPago(
      clienteId: otroCliente,
      monto: 777,
      usuarioId: usuarioId,
      fecha: DateTime(2026, 9, 5),
    );

    final movimientos = await repo.movimientosCliente(clienteId);

    expect(movimientos.map((m) => m.tipo), [
      TipoMovimientoFiado.venta,
      TipoMovimientoFiado.abono,
      TipoMovimientoFiado.venta,
    ]);
    expect(movimientos.map((m) => m.monto), [1000, 2000, 5000]);
    expect(movimientos.first.fecha, DateTime(2026, 9, 3));
  });

  test('deudaTotalAl suma lo que deben todos los clientes, descontando abonos',
      () async {
    final rosa = await db.into(db.clientes).insert(
          ClientesCompanion.insert(nombre: 'Doña Rosa'),
        );
    await venderFiado(5000, DateTime(2026, 9, 1));
    await repo.registrarPago(
        clienteId: clienteId,
        monto: 2000,
        usuarioId: usuarioId,
        fecha: DateTime(2026, 9, 2));
    await db.into(db.ventas).insert(
          VentasCompanion.insert(
            monto: 4000,
            fecha: DateTime(2026, 9, 2),
            esFiado: const Value(true),
            clienteId: Value(rosa),
            usuarioId: usuarioId,
          ),
        );

    expect(await repo.deudaTotalAl(DateTime(2026, 9, 2)), 7000);
  });

  test('deudaTotalAl no cuenta a quien pagó todo ni resta saldos a favor',
      () async {
    final rosa = await db.into(db.clientes).insert(
          ClientesCompanion.insert(nombre: 'Doña Rosa'),
        );
    await venderFiado(5000, DateTime(2026, 9, 1));
    await db.into(db.ventas).insert(
          VentasCompanion.insert(
            monto: 1000,
            fecha: DateTime(2026, 9, 1),
            esFiado: const Value(true),
            clienteId: Value(rosa),
            usuarioId: usuarioId,
          ),
        );
    // Doña Rosa abona de más: queda con saldo a favor, que no debe restar
    // a la deuda de Don Pedro.
    await repo.registrarPago(
        clienteId: rosa,
        monto: 3000,
        usuarioId: usuarioId,
        fecha: DateTime(2026, 9, 1));

    expect(await repo.deudaTotalAl(DateTime(2026, 9, 1)), 5000);
  });

  test('deudaTotalAl ignora ventas y abonos posteriores al día', () async {
    await venderFiado(5000, DateTime(2026, 9, 1, 18));
    await repo.registrarPago(
        clienteId: clienteId,
        monto: 2000,
        usuarioId: usuarioId,
        fecha: DateTime(2026, 9, 2, 8));
    await venderFiado(1000, DateTime(2026, 9, 2, 9));

    expect(await repo.deudaTotalAl(DateTime(2026, 9, 1)), 5000);
    expect(await repo.deudaTotalAl(DateTime(2026, 9, 2)), 4000);
  });

  test('clientesConDeudaAl cuenta solo clientes con saldo positivo', () async {
    final rosa = await db.into(db.clientes).insert(
          ClientesCompanion.insert(nombre: 'Doña Rosa'),
        );
    await venderFiado(5000, DateTime(2026, 9, 1));
    await db.into(db.ventas).insert(
          VentasCompanion.insert(
            monto: 1000,
            fecha: DateTime(2026, 9, 1),
            esFiado: const Value(true),
            clienteId: Value(rosa),
            usuarioId: usuarioId,
          ),
        );
    await repo.registrarPago(
        clienteId: rosa,
        monto: 1000,
        usuarioId: usuarioId,
        fecha: DateTime(2026, 9, 1));

    expect(await repo.clientesConDeudaAl(DateTime(2026, 9, 1)), 1);
  });

  test('registrarPago guarda el medio y pagosDelDia filtra por día y usuario',
      () async {
    final dia = DateTime(2026, 10, 5, 10);
    await repo.registrarPago(
        clienteId: clienteId, monto: 1000, usuarioId: usuarioId, fecha: dia);
    await repo.registrarPago(
        clienteId: clienteId,
        monto: 2000,
        usuarioId: usuarioId,
        fecha: dia,
        medioPago: MedioPago.transferencia);
    await repo.registrarPago(
        clienteId: clienteId,
        monto: 500,
        usuarioId: usuarioId,
        fecha: dia.subtract(const Duration(days: 1)));

    final pagos = await repo.pagosDelDia(dia);
    expect(pagos.map((p) => p.monto), unorderedEquals([1000, 2000]));
    expect(pagos.firstWhere((p) => p.monto == 2000).medioPago,
        MedioPago.transferencia);
    expect(await repo.pagosDelDia(dia, usuarioId: usuarioId + 99), isEmpty);

    final movimientos = await repo.movimientosCliente(clienteId);
    expect(movimientos.firstWhere((m) => m.monto == 2000).medioPago,
        MedioPago.transferencia);
  });

  test('movimientosCliente trae lo anulado marcado con su corrección',
      () async {
    final ana = await (db.select(db.usuarios)
          ..where((u) => u.id.equals(usuarioId)))
        .getSingle();
    final correcciones =
        CorreccionRepository(db, reloj: () => DateTime(2026, 9, 3));
    final ventaId = await db.into(db.ventas).insert(VentasCompanion.insert(
          monto: 5000,
          fecha: DateTime(2026, 9, 1),
          esFiado: const Value(true),
          clienteId: Value(clienteId),
          usuarioId: usuarioId,
        ));
    final pagoId = await repo.registrarPago(
        clienteId: clienteId,
        monto: 2000,
        usuarioId: usuarioId,
        fecha: DateTime(2026, 9, 2));
    await correcciones.anularPago(pagoId, por: ana);
    await correcciones.corregirVenta(ventaId,
        monto: 6000, esFiado: true, clienteId: clienteId, por: ana);

    final movimientos = await repo.movimientosCliente(clienteId);

    final abono =
        movimientos.singleWhere((m) => m.tipo == TipoMovimientoFiado.abono);
    expect(abono.id, pagoId);
    expect(abono.usuarioId, usuarioId);
    expect(abono.anulado, isTrue);
    expect(abono.ultimaCorreccion!.accion, AccionCorreccion.anulado);
    final venta =
        movimientos.singleWhere((m) => m.tipo == TipoMovimientoFiado.venta);
    expect(venta.id, ventaId);
    expect(venta.monto, 6000);
    expect(venta.ultimaCorreccion!.antes, r'$5.000 · Fiado · Don Pedro');
    expect(await repo.saldoCliente(clienteId), 6000);
  });


  test('clientesAlDia trae a quien ya no debe y tuvo movimientos', () async {
    await venderFiado(5000, DateTime(2026, 9, 1));
    await repo.registrarPago(
        clienteId: clienteId,
        monto: 5000,
        usuarioId: usuarioId,
        fecha: DateTime(2026, 9, 2));
    await db.into(db.clientes).insert(ClientesCompanion.insert(nombre: 'Nuevo'));
    final rosa = await db
        .into(db.clientes)
        .insert(ClientesCompanion.insert(nombre: 'Rosa'));
    await db.into(db.ventas).insert(VentasCompanion.insert(
          monto: 1000,
          fecha: DateTime(2026, 9, 3),
          esFiado: const Value(true),
          clienteId: Value(rosa),
          usuarioId: usuarioId,
        ));

    final alDia = await repo.clientesAlDia();

    expect(alDia.map((c) => c.cliente.id), [clienteId]);
    expect(alDia.single.saldo, 0);
    expect(alDia.single.fechaDeudaMasAntigua, isNull);
  });
}
