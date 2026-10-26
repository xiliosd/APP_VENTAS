import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/repositories/fiado_repository.dart';
import 'package:app_ventas/repositories/reporte_repository.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late ReporteRepository repo;
  late int ana;
  final lunes = DateTime(2026, 10, 5);
  final domingo = DateTime(2026, 10, 11);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = ReporteRepository(db, FiadoRepository(db));
    ana = await db
        .into(db.usuarios)
        .insert(
          UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'x'),
        );
  });

  tearDown(() => db.close());

  Future<int> cliente(String nombre, [String? apellido]) => db
      .into(db.clientes)
      .insert(
        ClientesCompanion.insert(nombre: nombre, apellido: Value(apellido)),
      );

  Future<int> vender(
    int monto, {
    int? clienteId,
    bool fiado = false,
    int dia = 6,
    bool anulada = false,
  }) => db
      .into(db.ventas)
      .insert(
        VentasCompanion.insert(
          monto: monto,
          fecha: DateTime(2026, 10, dia, 10),
          usuarioId: ana,
          esFiado: Value(fiado),
          clienteId: Value(clienteId),
          anulado: Value(anulada),
        ),
      );

  test('separa lo vendido a habituales y de paso', () async {
    final pedro = await cliente('Pedro', 'Gómez');
    await vender(1000, clienteId: pedro);
    await vender(2000, clienteId: pedro, fiado: true);
    await vender(500);
    await vender(700, dia: 12);

    final r = await repo.reporte(lunes, domingo);

    expect(r.vendidoHabituales, 3000);
    expect(r.vendidoDePaso, 500);
  });

  test(
    'mejores clientes suma contado y fiado y excluye anuladas y abonos',
    () async {
      final pedro = await cliente('Pedro', 'Gómez');
      await vender(1000, clienteId: pedro);
      await vender(2000, clienteId: pedro, fiado: true);
      await vender(9000, clienteId: pedro, anulada: true);
      await db
          .into(db.pagosFiado)
          .insert(
            PagosFiadoCompanion.insert(
              clienteId: pedro,
              monto: 5000,
              fecha: DateTime(2026, 10, 7),
              usuarioId: ana,
            ),
          );

      final r = await repo.reporte(lunes, domingo);

      expect(r.mejoresClientes, hasLength(1));
      expect(r.mejoresClientes.single.clienteId, pedro);
      expect(r.mejoresClientes.single.compras, 2);
      expect(r.mejoresClientes.single.dinero, 3000);
    },
  );

  test('mejores clientes ordena por dinero y luego por compras', () async {
    final a = await cliente('Ana', 'Ruiz');
    final b = await cliente('Beto', 'Soto');
    final c = await cliente('Carla', 'Paz');
    await vender(3000, clienteId: a);
    await vender(1000, clienteId: b);
    await vender(1000, clienteId: b);
    await vender(1000, clienteId: b);
    await vender(5000, clienteId: c);

    final r = await repo.reporte(lunes, domingo);

    expect(r.mejoresClientes.map((x) => x.clienteId), [c, b, a]);
    expect(r.mejoresClientes.map((x) => x.dinero), [5000, 3000, 3000]);
  });

  test(
    'mejores clientes usa el nombre completo actual y recorta a 10',
    () async {
      final pedro = await cliente('Pedro');
      await vender(1000, clienteId: pedro);
      await (db.update(db.clientes)..where((c) => c.id.equals(pedro))).write(
        const ClientesCompanion(apellido: Value('Gómez')),
      );
      for (var i = 0; i < 11; i++) {
        await vender(10, clienteId: await cliente('Cliente', 'N$i'));
      }

      final r = await repo.reporte(lunes, domingo);

      expect(r.mejoresClientes.first.nombre, 'Pedro Gómez');
      expect(r.mejoresClientes, hasLength(10));
    },
  );
}
