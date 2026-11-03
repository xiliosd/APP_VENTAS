import 'dart:typed_data';

import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/repositories/inventario_repository.dart';
import 'package:app_ventas/repositories/venta_repository.dart';
import 'package:app_ventas/sincronizacion/sincronizador.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/nube_tienda_falsa.dart';

void main() {
  late AppDatabase a;
  late AppDatabase b;
  late NubeTiendaFalsa nube;
  late Sincronizador sincronizadorA;
  late Sincronizador sincronizadorB;

  setUp(() {
    a = AppDatabase(NativeDatabase.memory());
    b = AppDatabase(NativeDatabase.memory());
    nube = NubeTiendaFalsa();
    sincronizadorA = Sincronizador(a, nube);
    sincronizadorB = Sincronizador(b, nube);
  });

  tearDown(() async {
    await a.close();
    await b.close();
  });

  /// Una tienda con usuario, cliente, producto, venta fiada con dos líneas,
  /// gasto y configuración. Devuelve los ids locales en A.
  Future<({int usuario, int cliente, int producto, int venta})> sembrarTienda(
    AppDatabase db,
  ) async {
    final usuario = await db
        .into(db.usuarios)
        .insert(
          UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'h'),
        );
    final cliente = await db
        .into(db.clientes)
        .insert(ClientesCompanion.insert(nombre: 'Don Pedro'));
    final producto = await db
        .into(db.productos)
        .insert(ProductosCompanion.insert(nombre: 'Arepa', precio: 3500));
    final venta = await db
        .into(db.ventas)
        .insert(
          VentasCompanion.insert(
            monto: 7000,
            fecha: DateTime(2026, 11, 3, 10),
            usuarioId: usuario,
            esFiado: const Value(true),
            clienteId: Value(cliente),
          ),
        );
    for (var i = 0; i < 2; i++) {
      await db
          .into(db.lineasVenta)
          .insert(
            LineasVentaCompanion.insert(
              ventaId: venta,
              productoId: Value(producto),
              descripcion: 'Arepa',
              precioUnitario: 3500,
              cantidad: 1,
            ),
          );
    }
    await db
        .into(db.gastos)
        .insert(
          GastosCompanion.insert(
            monto: 2000,
            fecha: DateTime(2026, 11, 3, 11),
            usuarioId: usuario,
          ),
        );
    await db
        .into(db.configuracionTienda)
        .insert(
          ConfiguracionTiendaCompanion.insert(
            id: const Value(1),
            nombreTienda: const Value('La Esquina'),
            imagenQr: Value(Uint8List.fromList([7, 7])),
          ),
        );
    return (
      usuario: usuario,
      cliente: cliente,
      producto: producto,
      venta: venta,
    );
  }

  Future<int> totalVentas(AppDatabase db) async {
    final ventas = await db.select(db.ventas).get();
    return ventas.fold<int>(0, (suma, v) => suma + v.monto);
  }

  /// Comparte la tienda de A y la descarga en B.
  Future<void> compartirEnAmbos() async {
    await sincronizadorA.convertirEnCompartida('La Esquina');
    await sincronizadorB.descargarTienda(await nube.miTienda() as String);
  }

  test('convertir sube todo lo que había en la tienda', () async {
    await sembrarTienda(a);

    await sincronizadorA.convertirEnCompartida('La Esquina');

    expect(await sincronizadorA.esCompartida(), isTrue);
    expect(await sincronizadorA.cuantosPendientes(), 0);
    final porTabla = <String, int>{};
    for (final fila in nube.filas) {
      porTabla[fila.tabla] = (porTabla[fila.tabla] ?? 0) + 1;
    }
    expect(porTabla, {
      'usuarios': 1,
      'clientes': 1,
      'productos': 1,
      'ventas': 1,
      'lineas_venta': 2,
      'gastos': 1,
      'configuracion_tienda': 1,
    });
  });

  test('B nuevo descarga la tienda completa', () async {
    await sembrarTienda(a);

    await compartirEnAmbos();

    expect(await sincronizadorB.esCompartida(), isTrue);
    final usuario = await b.select(b.usuarios).getSingle();
    expect(usuario.nombre, 'Ana');
    expect(usuario.pinHash, 'h');
    final configuracion = await b.select(b.configuracionTienda).getSingle();
    expect(configuracion.nombreTienda, 'La Esquina');
    expect(configuracion.imagenQr, [7, 7]);
    expect(await b.select(b.lineasVenta).get(), hasLength(2));
    expect(await totalVentas(b), 7000);
    expect(await sincronizadorB.cuantosPendientes(), 0);
  });

  test(
    'vaciar la base deja el celular listo para descargar otra tienda',
    () async {
      await sembrarTienda(b);
      await sembrarTienda(a);
      await sincronizadorA.convertirEnCompartida('La Esquina');

      await sincronizadorB.vaciarBase();
      await sincronizadorB.descargarTienda('tienda-1');

      expect(await b.select(b.usuarios).get(), hasLength(1));
      expect(await b.select(b.ventas).get(), hasLength(1));
      expect(await sincronizadorB.cuantosPendientes(), 0);
      expect(await sincronizadorB.ultimaSincronizacion(), isNotNull);
    },
  );

  test('descargar en un celular con datos no se permite', () async {
    await sembrarTienda(a);
    await sembrarTienda(b);
    await sincronizadorA.convertirEnCompartida('La Esquina');

    expect(
      () => sincronizadorB.descargarTienda('tienda-1'),
      throwsA(isA<StateError>()),
    );
  });

  test(
    'una venta hecha en A aparece en B después de sincronizar ambos',
    () async {
      final ids = await sembrarTienda(a);
      await compartirEnAmbos();

      await a
          .into(a.ventas)
          .insert(
            VentasCompanion.insert(
              monto: 1500,
              fecha: DateTime(2026, 11, 3, 12),
              usuarioId: ids.usuario,
            ),
          );
      expect(await sincronizadorA.sincronizar(), ResultadoSincronizacion.alDia);
      expect(await sincronizadorB.sincronizar(), ResultadoSincronizacion.alDia);

      expect(await totalVentas(b), await totalVentas(a));
      expect(await totalVentas(b), 8500);
    },
  );

  test('sin conexión no se pierde nada y luego se sube', () async {
    final ids = await sembrarTienda(a);
    await compartirEnAmbos();
    await a
        .into(a.ventas)
        .insert(
          VentasCompanion.insert(
            monto: 1500,
            fecha: DateTime(2026, 11, 3, 12),
            usuarioId: ids.usuario,
          ),
        );

    nube.sinConexion = true;
    expect(
      await sincronizadorA.sincronizar(),
      ResultadoSincronizacion.sinConexion,
    );
    expect(await sincronizadorA.cuantosPendientes(), 1);

    nube.sinConexion = false;
    expect(await sincronizadorA.sincronizar(), ResultadoSincronizacion.alDia);
    await sincronizadorB.sincronizar();
    expect(await totalVentas(b), 8500);
  });

  test('1 200 cambios pendientes se suben en lotes', () async {
    await sincronizadorA.convertirEnCompartida('La Esquina');
    for (var i = 0; i < 1200; i++) {
      await a
          .into(a.clientes)
          .insert(ClientesCompanion.insert(nombre: 'Cliente $i'));
    }
    nube.subidas.clear();

    expect(await sincronizadorA.sincronizar(), ResultadoSincronizacion.alDia);

    expect(nube.subidas, [500, 500, 200]);
    expect(await sincronizadorA.cuantosPendientes(), 0);
  });

  test(
    'un fallo a mitad de la subida deja pendientes los no confirmados',
    () async {
      await sincronizadorA.convertirEnCompartida('La Esquina');
      for (var i = 0; i < 700; i++) {
        await a
            .into(a.clientes)
            .insert(ClientesCompanion.insert(nombre: 'Cliente $i'));
      }
      nube.subidas.clear();
      nube.fallarEnSubida = 2;

      expect(
        await sincronizadorA.sincronizar(),
        ResultadoSincronizacion.sinConexion,
      );
      expect(await sincronizadorA.cuantosPendientes(), 200);

      nube.fallarEnSubida = null;
      expect(await sincronizadorA.sincronizar(), ResultadoSincronizacion.alDia);
      expect(nube.filas.where((f) => f.tabla == 'clientes'), hasLength(700));
    },
  );

  test('un cambio hecho durante la subida sigue pendiente', () async {
    final ids = await sembrarTienda(a);
    await sincronizadorA.convertirEnCompartida('La Esquina');
    await (a.update(a.clientes)..where((c) => c.id.equals(ids.cliente))).write(
      const ClientesCompanion(telefono: Value('100')),
    );
    var unaVez = true;
    nube.alSubir = () async {
      if (!unaVez) return;
      unaVez = false;
      await (a.update(a.clientes)..where((c) => c.id.equals(ids.cliente)))
          .write(const ClientesCompanion(telefono: Value('200')));
    };

    await sincronizadorA.sincronizar();

    expect(await sincronizadorA.cuantosPendientes(), 1);
    await sincronizadorA.sincronizar();
    final enNube = nube.filas.singleWhere((f) => f.tabla == 'clientes');
    expect(enNube.datos!['telefono'], '200');
    expect(await sincronizadorA.cuantosPendientes(), 0);
  });

  test(
    'un cambio local hecho después de subir no lo pisa la copia de la nube',
    () async {
      final ids = await sembrarTienda(a);
      await compartirEnAmbos();
      await (a.update(a.clientes)..where((c) => c.id.equals(ids.cliente)))
          .write(const ClientesCompanion(telefono: Value('111')));
      await sincronizadorA.sincronizar();
      nube.alBajar = () async {
        nube.alBajar = null;
        await b
            .update(b.clientes)
            .write(const ClientesCompanion(telefono: Value('222')));
      };

      await sincronizadorB.sincronizar();

      expect((await b.select(b.clientes).getSingle()).telefono, '222');
      expect(await sincronizadorB.cuantosPendientes(), 1);
    },
  );

  test('deshacer una venta en A la borra en B con sus líneas', () async {
    final ids = await sembrarTienda(a);
    await compartirEnAmbos();

    await VentaRepository(a).eliminarVenta(ids.venta);
    await sincronizadorA.sincronizar();
    await sincronizadorB.sincronizar();

    expect(await b.select(b.ventas).get(), isEmpty);
    expect(await b.select(b.lineasVenta).get(), isEmpty);
  });

  test(
    'reemplazar líneas (proveedores de un producto) se refleja en B',
    () async {
      final ids = await sembrarTienda(a);
      final proveedor = await a
          .into(a.proveedores)
          .insert(ProveedoresCompanion.insert(nombre: 'Postobón'));
      await a
          .into(a.productosProveedores)
          .insert(
            ProductosProveedoresCompanion.insert(
              productoId: ids.producto,
              proveedorId: proveedor,
              precioCompra: 2000,
            ),
          );
      await compartirEnAmbos();

      // Como guardarProducto: borra los proveedores del producto y los vuelve
      // a crear (con un id global nuevo).
      await a.transaction(() async {
        await (a.delete(
          a.productosProveedores,
        )..where((p) => p.productoId.equals(ids.producto))).go();
        await a
            .into(a.productosProveedores)
            .insert(
              ProductosProveedoresCompanion.insert(
                productoId: ids.producto,
                proveedorId: proveedor,
                precioCompra: 2500,
              ),
            );
      });
      await sincronizadorA.sincronizar();
      await sincronizadorB.sincronizar();

      final enB = await b.select(b.productosProveedores).getSingle();
      expect(enB.precioCompra, 2500);
    },
  );

  test(
    'lo mismo editado en ambos celulares: gana el último que sube',
    () async {
      await sembrarTienda(a);
      await compartirEnAmbos();
      await a
          .update(a.clientes)
          .write(const ClientesCompanion(telefono: Value('111')));
      await b
          .update(b.clientes)
          .write(const ClientesCompanion(telefono: Value('222')));

      await sincronizadorA.sincronizar();
      await sincronizadorB.sincronizar();
      await sincronizadorA.sincronizar();

      expect((await a.select(a.clientes).getSingle()).telefono, '222');
      expect((await b.select(b.clientes).getSingle()).telefono, '222');
    },
  );

  test('con una versión mínima mayor no sincroniza y lo dice', () async {
    await sembrarTienda(a);
    await sincronizadorA.convertirEnCompartida('La Esquina');
    await a.into(a.clientes).insert(ClientesCompanion.insert(nombre: 'Nuevo'));
    nube.subidas.clear();
    nube.versionMinima = versionProtocoloSincronizacion + 1;

    expect(
      await sincronizadorA.sincronizar(),
      ResultadoSincronizacion.actualizarApp,
    );
    expect(nube.subidas, isEmpty);
    expect(await sincronizadorA.cuantosPendientes(), 1);
  });

  test('sesión vencida se informa', () async {
    await sincronizadorA.convertirEnCompartida('La Esquina');
    nube.sesionVencida = true;

    expect(
      await sincronizadorA.sincronizar(),
      ResultadoSincronizacion.sesionVencida,
    );
  });

  test('una tienda sin compartir no sincroniza', () async {
    expect(
      await sincronizadorA.sincronizar(),
      ResultadoSincronizacion.noCompartida,
    );
  });

  test(
    'aplicar cambios de la nube no los vuelve a anotar como pendientes',
    () async {
      await sembrarTienda(a);
      await compartirEnAmbos();
      await a
          .into(a.clientes)
          .insert(ClientesCompanion.insert(nombre: 'Nuevo'));
      await sincronizadorA.sincronizar();

      await sincronizadorB.sincronizar();

      expect(await sincronizadorB.cuantosPendientes(), 0);
      expect(await b.select(b.clientes).get(), hasLength(2));
    },
  );

  test('las existencias son iguales en A y B tras sincronizar', () async {
    final ids = await sembrarTienda(a);
    final ana = await a.select(a.usuarios).getSingle();
    await InventarioRepository(
      a,
      reloj: () => DateTime(2026, 11, 3, 8),
    ).activarControl(ids.producto, cantidad: 20, minimo: 0, por: ana);
    await compartirEnAmbos();
    final productoB = await b.select(b.productos).getSingle();
    final anaB = await b.select(b.usuarios).getSingle();
    await b
        .into(b.ventas)
        .insert(
          VentasCompanion.insert(
            monto: 3500,
            fecha: DateTime(2026, 11, 3, 13),
            usuarioId: anaB.id,
          ),
        )
        .then(
          (venta) => b
              .into(b.lineasVenta)
              .insert(
                LineasVentaCompanion.insert(
                  ventaId: venta,
                  productoId: Value(productoB.id),
                  descripcion: 'Arepa',
                  precioUnitario: 3500,
                  cantidad: 3,
                ),
              ),
        );

    await sincronizadorB.sincronizar();
    await sincronizadorA.sincronizar();

    final enA = await InventarioRepository(a).existencias(ids.producto);
    final enB = await InventarioRepository(b).existencias(productoB.id);
    expect(enA, enB);
    expect(enA, 20 - 2 - 3);
  });
}
