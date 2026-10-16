import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/repositories/correccion_repository.dart';
import 'package:app_ventas/repositories/inventario_repository.dart';
import 'package:app_ventas/repositories/pedido_repository.dart';
import 'package:app_ventas/repositories/producto_repository.dart';
import 'package:app_ventas/repositories/proveedor_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late InventarioRepository inventario;
  late PedidoRepository pedidos;
  late CorreccionRepository correccion;
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
    inventario = InventarioRepository(db, reloj: () => ahora);
    pedidos = PedidoRepository(db, reloj: () => ahora);
    correccion = CorreccionRepository(db, reloj: () => ahora);
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

  Future<int> pedido() => pedidos.guardarPedido(
    proveedorId: postobon,
    lineas: [
      LineaPedidoNueva(productoId: coca, cantidad: 24, precioEsperado: 900),
      LineaPedidoNueva(productoId: pan, cantidad: 10, precioEsperado: 400),
    ],
    por: beto,
  );

  Future<int> recibir({
    int? pedidoId,
    bool pagadoDeCaja = true,
    Usuario? por,
  }) => inventario.recibirMercancia(
    proveedorId: postobon,
    lineas: [LineaRecibida(productoId: coca, cantidad: 20, precioCompra: 1000)],
    por: por ?? beto,
    pedidoId: pedidoId,
    pagadoDeCaja: pagadoDeCaja,
  );

  group('gasto al recibir', () {
    test(
      'por defecto se registra un gasto Mercancía por lo que llegó',
      () async {
        ahora = DateTime(2026, 10, 18, 9);
        final entrada = await inventario.recibirMercancia(
          proveedorId: postobon,
          lineas: [
            LineaRecibida(productoId: coca, cantidad: 20, precioCompra: 1000),
          ],
          por: beto,
        );

        final gasto = await db.select(db.gastos).getSingle();
        expect(gasto.monto, 20000);
        expect(gasto.descripcion, 'Mercancía · Postobón');
        expect(gasto.fecha, DateTime(2026, 10, 18, 9));
        expect(gasto.usuarioId, beto.id);
        expect(gasto.entradaId, entrada);
      },
    );

    test('sin pagar de la caja no hay gasto', () async {
      await recibir(pagadoDeCaja: false);

      expect(await db.select(db.gastos).get(), isEmpty);
    });
  });

  group('recibir contra un pedido', () {
    test('el pedido queda recibido y enlazado a la entrada', () async {
      final id = await pedido();

      final entrada = await recibir(pedidoId: id);

      final p = await db.select(db.pedidos).getSingle();
      expect(p.estado, EstadoPedido.recibido);
      expect(p.entradaId, entrada);
      expect(await pedidos.pedidosPorLlegar(), isEmpty);
    });

    test('un pedido de otro proveedor se rechaza', () async {
      final id = await pedidos.guardarPedido(
        proveedorId: alpina,
        lineas: [LineaPedidoNueva(productoId: coca, cantidad: 2)],
        por: beto,
      );

      await expectLater(recibir(pedidoId: id), throwsArgumentError);
      expect(await db.select(db.entradasMercancia).get(), isEmpty);
    });

    test(
      'un pedido ya recibido o anulado se rechaza sin entrada ni gasto nuevos',
      () async {
        final recibido = await pedido();
        await recibir(pedidoId: recibido);
        final anulado = await pedido();
        await pedidos.anularPedido(anulado, por: beto);

        await expectLater(recibir(pedidoId: recibido), throwsArgumentError);
        await expectLater(recibir(pedidoId: anulado), throwsArgumentError);
        expect(await db.select(db.entradasMercancia).get(), hasLength(1));
        expect(await db.select(db.gastos).get(), hasLength(1));
      },
    );
  });

  group('anular la entrada', () {
    test(
      'anula su gasto, lo registra y devuelve el pedido a por llegar',
      () async {
        final id = await pedido();
        final entrada = await recibir(pedidoId: id);

        await inventario.anularEntrada(entrada, por: beto);

        final gasto = await db.select(db.gastos).getSingle();
        expect(gasto.anulado, isTrue);
        final c = await db.select(db.correcciones).getSingle();
        expect(
          (c.tipoMovimiento, c.movimientoId, c.accion),
          (TipoMovimiento.gasto, gasto.id, AccionCorreccion.anulado),
        );
        expect(c.antes, r'$20.000 · Mercancía · Postobón');
        final p = await db.select(db.pedidos).getSingle();
        expect(p.estado, EstadoPedido.porLlegar);
        expect(p.entradaId, isNull);
      },
    );

    test('la segunda anulación falla sin una segunda corrección', () async {
      final entrada = await recibir();
      await inventario.anularEntrada(entrada, por: beto);

      await expectLater(
        inventario.anularEntrada(entrada, por: beto),
        throwsArgumentError,
      );
      expect(await db.select(db.correcciones).get(), hasLength(1));
    });

    test('con gasto, un vendedor solo anula lo suyo y del mismo día', () async {
      final entrada = await recibir();

      await expectLater(
        inventario.anularEntrada(entrada, por: caro),
        throwsA(isA<PermisoDenegado>()),
      );
      ahora = DateTime(2026, 10, 17, 8);
      await expectLater(
        inventario.anularEntrada(entrada, por: beto),
        throwsA(isA<PermisoDenegado>()),
      );
      expect((await db.select(db.gastos).getSingle()).anulado, isFalse);

      await inventario.anularEntrada(entrada, por: ana);
      expect((await db.select(db.gastos).getSingle()).anulado, isTrue);
    });

    test('sin gasto, cualquiera la anula como antes', () async {
      final entrada = await recibir(pagadoDeCaja: false);
      ahora = DateTime(2026, 10, 17, 8);

      await inventario.anularEntrada(entrada, por: caro);

      expect(
        (await db.select(db.entradasMercancia).getSingle()).anulada,
        isTrue,
      );
    });
  });

  group('gasto enlazado', () {
    test('no se corrige ni se anula suelto', () async {
      await recibir();
      final gasto = await db.select(db.gastos).getSingle();
      final bloqueo = isA<CorreccionInvalida>().having(
        (e) => e.mensaje,
        'mensaje',
        'Viene de la mercancía recibida; para cambiarlo anula la entrada',
      );

      await expectLater(
        correccion.corregirGasto(gasto.id, monto: 1, por: ana),
        throwsA(bloqueo),
      );
      await expectLater(
        correccion.anularGasto(gasto.id, por: ana),
        throwsA(bloqueo),
      );
      expect((await db.select(db.gastos).getSingle()).monto, 20000);
    });
  });

  test(
    'el detalle de la entrada trae su gasto y las líneas del pedido',
    () async {
      final id = await pedido();
      final entrada = await recibir(pedidoId: id);
      final sinPedido = await recibir(pagadoDeCaja: false);

      final detalle = await inventario.detalleEntrada(entrada);
      expect(detalle.gasto?.monto, 20000);
      expect(
        [
          for (final l in detalle.lineasPedido!)
            (l.producto.nombre, l.linea.cantidad),
        ],
        [('Coca', 24), ('Pan', 10)],
      );

      final otro = await inventario.detalleEntrada(sinPedido);
      expect(otro.gasto, isNull);
      expect(otro.lineasPedido, isNull);
    },
  );
}
