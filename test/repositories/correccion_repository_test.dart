import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/repositories/correccion_repository.dart';
import 'package:app_ventas/repositories/fiado_repository.dart';
import 'package:app_ventas/repositories/gasto_repository.dart';
import 'package:app_ventas/repositories/venta_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late CorreccionRepository repo;
  late VentaRepository ventas;
  late GastoRepository gastos;
  late FiadoRepository fiado;
  late Usuario ana; // administradora
  late Usuario beto; // vendedor
  late int pedro;
  late int rosa;
  final ahora = DateTime(2026, 10, 6, 15, 40);
  final hoy = DateTime(2026, 10, 6, 9);
  final ayer = DateTime(2026, 10, 5, 9);

  Future<Usuario> crearUsuario(String nombre, String rol) async {
    final id = await db.into(db.usuarios).insert(
        UsuariosCompanion.insert(nombre: nombre, rol: rol, pinHash: 'x'));
    return (db.select(db.usuarios)..where((u) => u.id.equals(id))).getSingle();
  }

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = CorreccionRepository(db, reloj: () => ahora);
    ventas = VentaRepository(db);
    gastos = GastoRepository(db);
    fiado = FiadoRepository(db);
    ana = await crearUsuario('Ana', 'admin');
    beto = await crearUsuario('Beto', 'vendedor');
    pedro = await db
        .into(db.clientes)
        .insert(ClientesCompanion.insert(nombre: 'Don Pedro'));
    rosa =
        await db.into(db.clientes).insert(ClientesCompanion.insert(nombre: 'Rosa'));
  });

  tearDown(() => db.close());

  Future<Venta> venta(int id) =>
      (db.select(db.ventas)..where((v) => v.id.equals(id))).getSingle();
  Future<PagoFiado> pago(int id) =>
      (db.select(db.pagosFiado)..where((p) => p.id.equals(id))).getSingle();
  Future<Gasto> gasto(int id) =>
      (db.select(db.gastos)..where((g) => g.id.equals(id))).getSingle();
  Future<List<Correccion>> correcciones() => db.select(db.correcciones).get();

  group('ventas', () {
    test('anular marca la venta y deja el rastro', () async {
      final id = await ventas.registrarVenta(
          monto: 5000, esFiado: false, usuarioId: ana.id, fecha: hoy);

      await repo.anularVenta(id, por: ana);

      expect((await venta(id)).anulado, isTrue);
      final c = (await correcciones()).single;
      expect(c.tipoMovimiento, TipoMovimiento.venta);
      expect(c.movimientoId, id);
      expect(c.accion, AccionCorreccion.anulado);
      expect(c.usuarioId, ana.id);
      expect(c.fecha, ahora);
      expect(c.antes, r'$5.000 · Contado · Efectivo');
    });

    test('de contado a fiada suma a la deuda del cliente', () async {
      final id = await ventas.registrarVenta(
          monto: 5000,
          esFiado: false,
          usuarioId: ana.id,
          fecha: hoy,
          medioPago: MedioPago.transferencia);

      await repo.corregirVenta(id,
          monto: 6000, esFiado: true, clienteId: pedro, por: ana);

      final v = await venta(id);
      expect(v.monto, 6000);
      expect(v.esFiado, isTrue);
      expect(v.clienteId, pedro);
      expect(v.medioPago, MedioPago.efectivo);
      expect(v.anulado, isFalse);
      expect(await fiado.saldoCliente(pedro), 6000);
      final c = (await correcciones()).single;
      expect(c.accion, AccionCorreccion.corregido);
      expect(c.antes, r'$5.000 · Contado · Transferencia');
    });

    test('de fiada a contado quita la deuda y guarda el medio de pago',
        () async {
      final id = await ventas.registrarVenta(
          monto: 4000, esFiado: true, clienteId: rosa, usuarioId: ana.id, fecha: hoy);

      await repo.corregirVenta(id,
          monto: 4000,
          esFiado: false,
          medioPago: MedioPago.transferencia,
          por: ana);

      final v = await venta(id);
      expect(v.esFiado, isFalse);
      expect(v.clienteId, isNull);
      expect(v.medioPago, MedioPago.transferencia);
      expect(await fiado.saldoCliente(rosa), 0);
      expect((await correcciones()).single.antes, r'$4.000 · Fiado · Rosa');
    });

    test(
        'pasar a contado una venta ya abonada deja saldo a favor sin deuda '
        'negativa', () async {
      final id = await ventas.registrarVenta(
          monto: 4000, esFiado: true, clienteId: rosa, usuarioId: ana.id, fecha: hoy);
      await fiado.registrarPago(
          clienteId: rosa, monto: 3000, usuarioId: ana.id, fecha: hoy);

      await repo.corregirVenta(id, monto: 4000, esFiado: false, por: ana);

      expect(await fiado.saldoCliente(rosa), -3000);
      expect(await fiado.listaClientesConDeuda(), isEmpty);
      expect(await fiado.deudaTotalAl(ahora), 0);
    });
  });

  group('abonos', () {
    test('corregir cambia monto y medio de pago', () async {
      final id = await fiado.registrarPago(
          clienteId: pedro, monto: 2000, usuarioId: ana.id, fecha: hoy);

      await repo.corregirPago(id,
          monto: 2500, medioPago: MedioPago.transferencia, por: ana);

      final p = await pago(id);
      expect(p.monto, 2500);
      expect(p.medioPago, MedioPago.transferencia);
      final c = (await correcciones()).single;
      expect(c.tipoMovimiento, TipoMovimiento.abono);
      expect(c.antes, r'$2.000 · Efectivo');
    });

    test('anular lo saca del saldo', () async {
      await ventas.registrarVenta(
          monto: 5000, esFiado: true, clienteId: pedro, usuarioId: ana.id, fecha: hoy);
      final id = await fiado.registrarPago(
          clienteId: pedro, monto: 2000, usuarioId: ana.id, fecha: hoy);

      await repo.anularPago(id, por: ana);

      expect((await pago(id)).anulado, isTrue);
      expect(await fiado.saldoCliente(pedro), 5000);
    });
  });

  group('gastos', () {
    test('corregir cambia monto y descripción', () async {
      final id = await gastos.registrarGasto(
          monto: 1500, descripcion: 'Hielo', usuarioId: ana.id, fecha: hoy);

      await repo.corregirGasto(id,
          monto: 1800, descripcion: 'Hielo y bolsas', por: ana);

      final g = await gasto(id);
      expect(g.monto, 1800);
      expect(g.descripcion, 'Hielo y bolsas');
      expect((await correcciones()).single.antes, r'$1.500 · Hielo');
    });

    test('anular un gasto sin descripción guarda solo el monto', () async {
      final id =
          await gastos.registrarGasto(monto: 1500, usuarioId: ana.id, fecha: hoy);

      await repo.anularGasto(id, por: ana);

      expect((await gasto(id)).anulado, isTrue);
      expect((await correcciones()).single.antes, r'$1.500');
    });
  });

  group('permisos', () {
    test('el vendedor corrige lo suyo de hoy', () async {
      final id = await ventas.registrarVenta(
          monto: 5000, esFiado: false, usuarioId: beto.id, fecha: hoy);

      await repo.anularVenta(id, por: beto);

      expect((await venta(id)).anulado, isTrue);
    });

    test('el vendedor no toca lo suyo de ayer', () async {
      final id = await ventas.registrarVenta(
          monto: 5000, esFiado: false, usuarioId: beto.id, fecha: ayer);

      await expectLater(
          repo.anularVenta(id, por: beto), throwsA(isA<PermisoDenegado>()));
      await expectLater(
          repo.corregirVenta(id, monto: 1000, esFiado: false, por: beto),
          throwsA(isA<PermisoDenegado>()));

      final v = await venta(id);
      expect(v.anulado, isFalse);
      expect(v.monto, 5000);
      expect(await correcciones(), isEmpty);
    });

    test('el vendedor no toca lo de otro', () async {
      final gastoId =
          await gastos.registrarGasto(monto: 900, usuarioId: ana.id, fecha: hoy);
      final pagoId = await fiado.registrarPago(
          clienteId: pedro, monto: 2000, usuarioId: ana.id, fecha: hoy);

      await expectLater(repo.corregirGasto(gastoId, monto: 100, por: beto),
          throwsA(isA<PermisoDenegado>()));
      await expectLater(
          repo.anularPago(pagoId, por: beto), throwsA(isA<PermisoDenegado>()));
      expect(await correcciones(), isEmpty);
    });

    test('el administrador corrige lo de otro de días anteriores', () async {
      final id = await ventas.registrarVenta(
          monto: 5000, esFiado: false, usuarioId: beto.id, fecha: ayer);

      await repo.anularVenta(id, por: ana);

      expect((await venta(id)).anulado, isTrue);
    });
  });

  group('reglas', () {
    test('no se anula ni se corrige algo ya anulado', () async {
      final id = await ventas.registrarVenta(
          monto: 5000, esFiado: false, usuarioId: ana.id, fecha: hoy);
      await repo.anularVenta(id, por: ana);

      await expectLater(repo.anularVenta(id, por: ana),
          throwsA(isA<CorreccionInvalida>()));
      await expectLater(
          repo.corregirVenta(id, monto: 100, esFiado: false, por: ana),
          throwsA(isA<CorreccionInvalida>()));
      expect(await correcciones(), hasLength(1));
    });

    test('monto 0 o fiada sin cliente se rechazan sin cambiar nada', () async {
      final id = await ventas.registrarVenta(
          monto: 5000, esFiado: false, usuarioId: ana.id, fecha: hoy);

      await expectLater(
          repo.corregirVenta(id, monto: 0, esFiado: false, por: ana),
          throwsA(isA<CorreccionInvalida>()));
      await expectLater(
          repo.corregirVenta(id, monto: 5000, esFiado: true, por: ana),
          throwsA(isA<CorreccionInvalida>()));

      expect((await venta(id)).monto, 5000);
      expect((await venta(id)).esFiado, isFalse);
      expect(await correcciones(), isEmpty);
    });

    test('ultimasCorrecciones da la más reciente de cada movimiento', () async {
      final id = await ventas.registrarVenta(
          monto: 5000, esFiado: false, usuarioId: ana.id, fecha: hoy);
      final gastoId =
          await gastos.registrarGasto(monto: 900, usuarioId: ana.id, fecha: hoy);
      await repo.corregirVenta(id, monto: 6000, esFiado: false, por: ana);
      await repo.corregirVenta(id, monto: 7000, esFiado: false, por: ana);
      await repo.anularGasto(gastoId, por: ana);

      final ultimas =
          await repo.ultimasCorrecciones(TipoMovimiento.venta, [id]);

      expect(ultimas.keys.toList(), [id]);
      expect(ultimas[id]!.antes, r'$6.000 · Contado · Efectivo');
      expect(
          (await repo.ultimasCorrecciones(TipoMovimiento.gasto, [gastoId]))[
                  gastoId]!
              .accion,
          AccionCorreccion.anulado);
      expect(await repo.ultimasCorrecciones(TipoMovimiento.abono, const []),
          isEmpty);
    });
  });
}
