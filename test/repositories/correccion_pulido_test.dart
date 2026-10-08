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
  late Usuario ana;
  late int pedro;
  final hoy = DateTime(2026, 10, 8, 9);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = CorreccionRepository(db, reloj: () => DateTime(2026, 10, 8, 15));
    final id = await db.into(db.usuarios).insert(
        UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'x'));
    ana = await (db.select(db.usuarios)..where((u) => u.id.equals(id)))
        .getSingle();
    pedro = await db
        .into(db.clientes)
        .insert(ClientesCompanion.insert(nombre: 'Don Pedro'));
  });
  tearDown(() => db.close());

  Future<List<Correccion>> correcciones() => db.select(db.correcciones).get();

  group('tope del abono', () {
    // Debe 10.000, abonó 4.000: queda 6.000; el abono puede subir hasta 10.000.
    Future<int> abono() async {
      await VentaRepository(db).registrarVenta(
          monto: 10000,
          esFiado: true,
          clienteId: pedro,
          usuarioId: ana.id,
          fecha: hoy);
      return FiadoRepository(db).registrarPago(
          clienteId: pedro, monto: 4000, usuarioId: ana.id, fecha: hoy);
    }

    test('subir hasta la deuda se permite', () async {
      final id = await abono();
      await repo.corregirPago(id,
          monto: 10000, medioPago: MedioPago.efectivo, por: ana);
      expect(await FiadoRepository(db).saldoCliente(pedro), 0);
    });

    test('pasar la deuda se rechaza con el máximo', () async {
      final id = await abono();
      await expectLater(
        repo.corregirPago(id,
            monto: 10001, medioPago: MedioPago.efectivo, por: ana),
        throwsA(isA<CorreccionInvalida>().having((e) => e.mensaje, 'mensaje',
            r'El abono no puede ser mayor que la deuda ($10.000)')),
      );
      expect(await correcciones(), isEmpty);
    });

    test('bajar o cambiar el medio siempre se permite, aun con saldo a favor',
        () async {
      // Abonó 2.000 sin deber nada: saldo −2.000.
      final id = await FiadoRepository(db).registrarPago(
          clienteId: pedro, monto: 2000, usuarioId: ana.id, fecha: hoy);
      await repo.corregirPago(id,
          monto: 2000, medioPago: MedioPago.transferencia, por: ana);
      await repo.corregirPago(id,
          monto: 1000, medioPago: MedioPago.transferencia, por: ana);
      expect(await correcciones(), hasLength(2));
    });
  });

  group('sin cambios no se registra corrección', () {
    test('venta fiada con el mismo cliente', () async {
      final id = await VentaRepository(db).registrarVenta(
          monto: 5000,
          esFiado: true,
          clienteId: pedro,
          usuarioId: ana.id,
          fecha: hoy);
      await repo.corregirVenta(id,
          monto: 5000, esFiado: true, clienteId: pedro, por: ana);
      expect(await correcciones(), isEmpty);
    });

    test('venta con líneas y las mismas cantidades', () async {
      final ventas = VentaRepository(db);
      final id = await ventas.registrarVenta(
        monto: 7000,
        esFiado: false,
        usuarioId: ana.id,
        fecha: hoy,
        lineas: const [
          LineaNueva(descripcion: 'Arepa', precioUnitario: 3500, cantidad: 2),
        ],
      );
      final linea = (await ventas.lineasDeVenta(id)).single;
      await repo.corregirVenta(id,
          monto: 7000, esFiado: false, cantidades: {linea.id: 2}, por: ana);
      expect(await correcciones(), isEmpty);
    });

    test('abono igual', () async {
      final id = await FiadoRepository(db).registrarPago(
          clienteId: pedro, monto: 2000, usuarioId: ana.id, fecha: hoy);
      await repo.corregirPago(id,
          monto: 2000, medioPago: MedioPago.efectivo, por: ana);
      expect(await correcciones(), isEmpty);
    });

    test('gasto con la misma descripción entre espacios', () async {
      final id = await GastoRepository(db).registrarGasto(
          monto: 1000, descripcion: 'Hielo', usuarioId: ana.id, fecha: hoy);
      await repo.corregirGasto(id,
          monto: 1000, descripcion: ' Hielo ', por: ana);
      expect(await correcciones(), isEmpty);
    });
  });
}
