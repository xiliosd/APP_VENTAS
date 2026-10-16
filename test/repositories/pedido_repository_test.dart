import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/repositories/correccion_repository.dart';
import 'package:app_ventas/repositories/pedido_repository.dart';
import 'package:app_ventas/repositories/producto_repository.dart';
import 'package:app_ventas/repositories/proveedor_repository.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late PedidoRepository repo;
  late Usuario ana; // admin
  late Usuario beto; // vendedor
  late Usuario caro; // vendedora
  late int postobon;
  late int alpina;
  late int coca;
  late int pan;
  var ahora = DateTime(2026, 10, 16, 8);

  Future<Usuario> usuario(String nombre, String rol) async {
    final id = await db
        .into(db.usuarios)
        .insert(
          UsuariosCompanion.insert(nombre: nombre, rol: rol, pinHash: 'x'),
        );
    return (db.select(db.usuarios)..where((u) => u.id.equals(id))).getSingle();
  }

  setUp(() async {
    ahora = DateTime(2026, 10, 16, 8);
    db = AppDatabase(NativeDatabase.memory());
    repo = PedidoRepository(db, reloj: () => ahora);
    ana = await usuario('Ana', 'admin');
    beto = await usuario('Beto', 'vendedor');
    caro = await usuario('Caro', 'vendedor');
    final proveedores = ProveedorRepository(db);
    postobon = await proveedores.crear(nombre: 'Postobón');
    alpina = await proveedores.crear(nombre: 'Alpina');
    final productos = ProductoRepository(db);
    coca = await productos.guardarProducto(nombre: 'Coca', precio: 1500);
    pan = await productos.guardarProducto(nombre: 'Pan', precio: 600);
  });

  tearDown(() => db.close());

  LineaPedidoNueva linea(int producto, int cantidad, [int? precio]) =>
      LineaPedidoNueva(
        productoId: producto,
        cantidad: cantidad,
        precioEsperado: precio,
      );

  group('guardarPedido', () {
    test('guarda fecha, usuario, estado por llegar y sus líneas', () async {
      final id = await repo.guardarPedido(
        proveedorId: postobon,
        lineas: [linea(coca, 24, 900), linea(pan, 10)],
        por: beto,
      );

      final pedido = await db.select(db.pedidos).getSingle();
      expect(pedido.id, id);
      expect(pedido.fecha, DateTime(2026, 10, 16, 8));
      expect(pedido.usuarioId, beto.id);
      expect(pedido.estado, EstadoPedido.porLlegar);
      final lineas = await db.select(db.lineasPedido).get();
      expect(
        [for (final l in lineas) (l.productoId, l.cantidad, l.precioEsperado)],
        [(coca, 24, 900), (pan, 10, null)],
      );
    });

    test(
      'rechaza pedidos sin líneas, con cantidades en 0 o repetidos',
      () async {
        expect(
          () => repo.guardarPedido(proveedorId: postobon, lineas: [], por: ana),
          throwsArgumentError,
        );
        expect(
          () => repo.guardarPedido(
            proveedorId: postobon,
            lineas: [linea(coca, 0)],
            por: ana,
          ),
          throwsArgumentError,
        );
        expect(
          () => repo.guardarPedido(
            proveedorId: postobon,
            lineas: [linea(coca, 2), linea(coca, 3)],
            por: ana,
          ),
          throwsArgumentError,
        );
        expect(await db.select(db.pedidos).get(), isEmpty);
      },
    );

    test('rechaza un proveedor inactivo', () async {
      await (db.update(db.proveedores)..where((p) => p.id.equals(alpina)))
          .write(const ProveedoresCompanion(activo: Value(false)));

      expect(
        () => repo.guardarPedido(
          proveedorId: alpina,
          lineas: [linea(coca, 2)],
          por: ana,
        ),
        throwsArgumentError,
      );
    });
  });

  group('pedidosPorLlegar', () {
    test(
      'solo los por llegar, del más viejo al más nuevo, con su total',
      () async {
        final primero = await repo.guardarPedido(
          proveedorId: postobon,
          lineas: [linea(coca, 24, 900), linea(pan, 10)],
          por: beto,
        );
        ahora = DateTime(2026, 10, 17, 8);
        final segundo = await repo.guardarPedido(
          proveedorId: alpina,
          lineas: [linea(pan, 5, 400)],
          por: ana,
        );
        final anulado = await repo.guardarPedido(
          proveedorId: postobon,
          lineas: [linea(pan, 1)],
          por: ana,
        );
        await repo.anularPedido(anulado, por: ana);
        final recibido = await repo.guardarPedido(
          proveedorId: postobon,
          lineas: [linea(pan, 1)],
          por: ana,
        );
        await (db.update(
          db.pedidos,
        )..where((p) => p.id.equals(recibido))).write(
          const PedidosCompanion(estado: Value(EstadoPedido.recibido)),
        );

        final todos = await repo.pedidosPorLlegar();
        expect([for (final r in todos) r.pedido.id], [primero, segundo]);
        expect(todos.first.proveedor.nombre, 'Postobón');
        expect(todos.first.usuario, 'Beto');
        expect(todos.first.productos, 2);
        // Pan sin precio esperado cuenta 0.
        expect(todos.first.totalEstimado, 21600);

        final dePostobon = await repo.pedidosPorLlegar(proveedorId: postobon);
        expect([for (final r in dePostobon) r.pedido.id], [primero]);
      },
    );
  });

  group('editar y anular', () {
    test('editar reemplaza todas las líneas', () async {
      final id = await repo.guardarPedido(
        proveedorId: postobon,
        lineas: [linea(coca, 24, 900)],
        por: beto,
      );

      await repo.editarPedido(id, [linea(pan, 6, 400)], por: beto);

      final detalle = await repo.detallePedido(id);
      expect(
        [for (final l in detalle.lineas) (l.producto.nombre, l.linea.cantidad)],
        [('Pan', 6)],
      );
    });

    test('editar valida las líneas como al guardar', () async {
      final id = await repo.guardarPedido(
        proveedorId: postobon,
        lineas: [linea(coca, 24)],
        por: beto,
      );

      expect(() => repo.editarPedido(id, [], por: beto), throwsArgumentError);
      expect((await repo.detallePedido(id)).lineas, hasLength(1));
    });

    test('anular lo saca de por llegar', () async {
      final id = await repo.guardarPedido(
        proveedorId: postobon,
        lineas: [linea(coca, 24)],
        por: beto,
      );

      await repo.anularPedido(id, por: beto);

      final pedido = await db.select(db.pedidos).getSingle();
      expect(pedido.estado, EstadoPedido.anulado);
      expect(await repo.pedidosPorLlegar(), isEmpty);
    });

    test(
      'un pedido que ya no está por llegar no se edita ni se anula',
      () async {
        final id = await repo.guardarPedido(
          proveedorId: postobon,
          lineas: [linea(coca, 24)],
          por: beto,
        );
        await repo.anularPedido(id, por: beto);

        expect(
          () => repo.editarPedido(id, [linea(coca, 1)], por: beto),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              'El pedido ya no está por llegar',
            ),
          ),
        );
        expect(() => repo.anularPedido(id, por: beto), throwsArgumentError);
      },
    );

    test('solo el autor o el administrador lo editan o anulan', () async {
      final id = await repo.guardarPedido(
        proveedorId: postobon,
        lineas: [linea(coca, 24)],
        por: beto,
      );

      expect(
        () => repo.editarPedido(id, [linea(coca, 1)], por: caro),
        throwsA(isA<PermisoDenegado>()),
      );
      expect(
        () => repo.anularPedido(id, por: caro),
        throwsA(isA<PermisoDenegado>()),
      );

      await repo.editarPedido(id, [linea(coca, 12)], por: ana);
      await repo.anularPedido(id, por: ana);
      expect(
        (await db.select(db.pedidos).getSingle()).estado,
        EstadoPedido.anulado,
      );
    });
  });

  group('detallePedido', () {
    test('muestra un producto desactivado después de pedirlo', () async {
      final id = await repo.guardarPedido(
        proveedorId: postobon,
        lineas: [linea(coca, 24, 900)],
        por: beto,
      );
      await ProductoRepository(db).desactivarProducto(coca);

      final detalle = await repo.detallePedido(id);
      expect(detalle.lineas.single.producto.nombre, 'Coca');
      expect(detalle.resumen.totalEstimado, 21600);
    });
  });

  group('cantidadesPorLlegar', () {
    test('suma los pedidos por llegar e ignora los anulados', () async {
      await repo.guardarPedido(
        proveedorId: postobon,
        lineas: [linea(coca, 8), linea(pan, 2)],
        por: beto,
      );
      await repo.guardarPedido(
        proveedorId: postobon,
        lineas: [linea(coca, 6)],
        por: beto,
      );
      final anulado = await repo.guardarPedido(
        proveedorId: alpina,
        lineas: [linea(pan, 50)],
        por: beto,
      );
      await repo.anularPedido(anulado, por: beto);

      expect(await cantidadesPorLlegar(db), {coca: 14, pan: 2});
    });
  });
}
