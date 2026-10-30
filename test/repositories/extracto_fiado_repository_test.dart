import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/repositories/correccion_repository.dart';
import 'package:app_ventas/repositories/fiado_repository.dart';
import 'package:app_ventas/repositories/venta_repository.dart';
import 'package:app_ventas/util/extracto_fiado.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late FiadoRepository fiado;
  late VentaRepository ventas;
  late CorreccionRepository correcciones;
  late Usuario ana;
  late int clienteId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    fiado = FiadoRepository(db);
    ventas = VentaRepository(db);
    correcciones = CorreccionRepository(db);
    final id = await db
        .into(db.usuarios)
        .insert(
          UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'x'),
        );
    ana = await (db.select(
      db.usuarios,
    )..where((u) => u.id.equals(id))).getSingle();
    clienteId = await db
        .into(db.clientes)
        .insert(ClientesCompanion.insert(nombre: 'Don Pedro'));
  });

  tearDown(() => db.close());

  test(
    'usa el monto y las líneas corregidas; saldoActual = saldoCliente',
    () async {
      final ventaId = await ventas.registrarVenta(
        monto: 7000,
        esFiado: true,
        clienteId: clienteId,
        usuarioId: ana.id,
        fecha: DateTime(2026, 10, 1),
        lineas: const [
          LineaNueva(descripcion: 'Arepa', precioUnitario: 3500, cantidad: 2),
        ],
      );
      final linea = (await ventas.lineasDeVenta(ventaId)).single;
      await correcciones.corregirVenta(
        ventaId,
        monto: 1,
        esFiado: true,
        clienteId: clienteId,
        cantidades: {linea.id: 1},
        por: ana,
      );
      await ventas.registrarVenta(
        monto: 2000,
        esFiado: true,
        clienteId: clienteId,
        usuarioId: ana.id,
        fecha: DateTime(2026, 10, 2),
      );
      await fiado.registrarPago(
        clienteId: clienteId,
        monto: 1000,
        usuarioId: ana.id,
        fecha: DateTime(2026, 10, 3),
      );

      final extracto = await fiado.extractoCliente(clienteId);

      final primero = extracto.anteriores.first as FiadoExtracto;
      expect(primero.monto, 3500);
      expect(primero.lineas.single.cantidad, 1);
      expect((extracto.anteriores.last as FiadoExtracto).lineas, isEmpty);
      expect(extracto.ultimoAbono!.saldoDespues, 4500);
      expect(extracto.saldoActual, await fiado.saldoCliente(clienteId));
    },
  );
}
