import 'dart:io';
import 'dart:typed_data';

import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/repositories/inventario_repository.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart' show sqlite3;
import 'package:flutter_test/flutter_test.dart';

import '../support/esquema_v1.dart';
import '../support/esquema_v10.dart';
import '../support/esquema_v2.dart';
import '../support/esquema_v3.dart';
import '../support/esquema_v4.dart';
import '../support/esquema_v5.dart';
import '../support/esquema_v6.dart';
import '../support/esquema_v7.dart';
import '../support/esquema_v8.dart';
import '../support/esquema_v9.dart';

void main() {
  late Directory carpeta;

  setUp(() async => carpeta = await Directory.systemTemp.createTemp('migra'));
  tearDown(() => carpeta.delete(recursive: true));

  test('una base v1 abre en v2 con ventas y abonos en efectivo', () async {
    final archivo = File('${carpeta.path}/v1.sqlite');
    crearBaseV1(archivo.path);

    final db = AppDatabase(NativeDatabase(archivo));
    addTearDown(db.close);

    final ventas = await db.select(db.ventas).get();
    final pagos = await db.select(db.pagosFiado).get();
    expect(ventas.single.medioPago, MedioPago.efectivo);
    expect(pagos.single.medioPago, MedioPago.efectivo);
    expect(await db.select(db.configuracionTienda).get(), isEmpty);
  });

  test('una base nueva guarda el medio de pago y la imagen del QR', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final usuario = await db
        .into(db.usuarios)
        .insert(
          UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'x'),
        );

    await db
        .into(db.ventas)
        .insert(
          VentasCompanion.insert(
            monto: 1000,
            fecha: DateTime(2026, 10, 5),
            usuarioId: usuario,
            medioPago: const Value(MedioPago.transferencia),
          ),
        );
    await db
        .into(db.configuracionTienda)
        .insert(
          ConfiguracionTiendaCompanion.insert(
            id: const Value(1),
            imagenQr: Value(Uint8List.fromList([1, 2])),
          ),
        );

    expect(
      (await db.select(db.ventas).getSingle()).medioPago,
      MedioPago.transferencia,
    );
    expect((await db.select(db.configuracionTienda).getSingle()).imagenQr, [
      1,
      2,
    ]);
    expect(db.schemaVersion, 11);
  });

  test('una base v2 abre en v3 sin nada anulado y sin correcciones', () async {
    final archivo = File('${carpeta.path}/v2.sqlite');
    crearBaseV2(archivo.path);

    final db = AppDatabase(NativeDatabase(archivo));
    addTearDown(db.close);

    expect((await db.select(db.ventas).getSingle()).anulado, isFalse);
    expect((await db.select(db.pagosFiado).getSingle()).anulado, isFalse);
    expect((await db.select(db.gastos).getSingle()).anulado, isFalse);
    expect(await db.select(db.correcciones).get(), isEmpty);
  });

  test('una base v1 abre en v3 sin nada anulado', () async {
    final archivo = File('${carpeta.path}/v1b.sqlite');
    crearBaseV1(archivo.path);

    final db = AppDatabase(NativeDatabase(archivo));
    addTearDown(db.close);

    expect((await db.select(db.ventas).getSingle()).anulado, isFalse);
    expect(await db.select(db.correcciones).get(), isEmpty);
  });

  test('una base nueva guarda correcciones con sus enums', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final usuario = await db
        .into(db.usuarios)
        .insert(
          UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'x'),
        );

    await db
        .into(db.correcciones)
        .insert(
          CorreccionesCompanion.insert(
            tipoMovimiento: TipoMovimiento.abono,
            movimientoId: 7,
            accion: AccionCorreccion.anulado,
            usuarioId: usuario,
            fecha: DateTime(2026, 10, 6, 15),
            antes: r'$2.000 · Efectivo',
          ),
        );

    final fila = await db.select(db.correcciones).getSingle();
    expect(fila.tipoMovimiento, TipoMovimiento.abono);
    expect(fila.movimientoId, 7);
    expect(fila.accion, AccionCorreccion.anulado);
    expect(fila.antes, r'$2.000 · Efectivo');
  });

  test('una base v3 abre en v4 con lineas_venta vacía', () async {
    final archivo = File('${carpeta.path}/v3.sqlite');
    crearBaseV3(archivo.path);

    final db = AppDatabase(NativeDatabase(archivo));
    addTearDown(db.close);

    expect(await db.select(db.ventas).get(), hasLength(1));
    expect(await db.select(db.lineasVenta).get(), isEmpty);
  });

  test('una base nueva guarda líneas de venta', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final usuario = await db
        .into(db.usuarios)
        .insert(
          UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'x'),
        );
    final venta = await db
        .into(db.ventas)
        .insert(
          VentasCompanion.insert(
            monto: 5000,
            fecha: DateTime(2026, 10, 7),
            usuarioId: usuario,
          ),
        );

    await db
        .into(db.lineasVenta)
        .insert(
          LineasVentaCompanion.insert(
            ventaId: venta,
            descripcion: r'$5.000',
            precioUnitario: 5000,
            cantidad: 1,
          ),
        );

    final linea = await db.select(db.lineasVenta).getSingle();
    expect(linea.ventaId, venta);
    expect(linea.productoId, isNull);
    expect(linea.descripcion, r'$5.000');
  });

  test(
    'una base v4 abre en v5 sin costos, proveedores ni nombre de tienda',
    () async {
      final archivo = File('${carpeta.path}/v4.sqlite');
      crearBaseV4(archivo.path);

      final db = AppDatabase(NativeDatabase(archivo));
      addTearDown(db.close);

      expect(
        (await db.select(db.lineasVenta).getSingle()).costoUnitario,
        isNull,
      );
      expect(await db.select(db.proveedores).get(), isEmpty);
      expect(await db.select(db.productosProveedores).get(), isEmpty);
      expect(await db.select(db.configuracionTienda).get(), isEmpty);
    },
  );

  for (final (version, crear) in [
    (1, crearBaseV1),
    (2, crearBaseV2),
    (3, crearBaseV3),
  ]) {
    test(
      'una base v$version abre en v5 y acepta líneas con costo y nombre',
      () async {
        final archivo = File('${carpeta.path}/vieja$version.sqlite');
        crear(archivo.path);

        final db = AppDatabase(NativeDatabase(archivo));
        addTearDown(db.close);

        final venta = (await db.select(db.ventas).getSingle()).id;
        await db
            .into(db.lineasVenta)
            .insert(
              LineasVentaCompanion.insert(
                ventaId: venta,
                descripcion: 'Arepa',
                precioUnitario: 3500,
                cantidad: 1,
                costoUnitario: const Value(2500),
              ),
            );
        await db
            .into(db.configuracionTienda)
            .insert(
              const ConfiguracionTiendaCompanion(
                id: Value(1),
                nombreTienda: Value('La Esquina'),
              ),
            );
        expect(
          (await db.select(db.lineasVenta).getSingle()).costoUnitario,
          2500,
        );
        expect(
          (await db.select(db.configuracionTienda).getSingle()).nombreTienda,
          'La Esquina',
        );
      },
    );
  }

  test('producto y proveedor no se pueden repetir', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final producto = await db
        .into(db.productos)
        .insert(ProductosCompanion.insert(nombre: 'Arepa', precio: 3500));
    final proveedor = await db
        .into(db.proveedores)
        .insert(ProveedoresCompanion.insert(nombre: 'Postobón'));
    await db
        .into(db.productosProveedores)
        .insert(
          ProductosProveedoresCompanion.insert(
            productoId: producto,
            proveedorId: proveedor,
            precioCompra: 2500,
          ),
        );

    await expectLater(
      db
          .into(db.productosProveedores)
          .insert(
            ProductosProveedoresCompanion.insert(
              productoId: producto,
              proveedorId: proveedor,
              precioCompra: 2600,
            ),
          ),
      throwsA(anything),
    );
    expect((await db.select(db.proveedores).getSingle()).activo, isTrue);
  });

  test(
    'una base v5 abre en v6 con productos sin control de existencias',
    () async {
      final archivo = File('${carpeta.path}/v5.sqlite');
      crearBaseV5(archivo.path);

      final db = AppDatabase(NativeDatabase(archivo));
      addTearDown(db.close);

      final producto = await db.select(db.productos).getSingle();
      expect(producto.controlaExistencias, isFalse);
      expect(producto.minimo, 0);
      expect(await db.select(db.conteosInventario).get(), isEmpty);
      expect(await db.select(db.entradasMercancia).get(), isEmpty);
      expect(await db.select(db.lineasEntrada).get(), isEmpty);
    },
  );

  for (final (version, crear) in [
    (1, crearBaseV1),
    (2, crearBaseV2),
    (3, crearBaseV3),
    (4, crearBaseV4),
  ]) {
    test('una base v$version abre en v6 y acepta conteos', () async {
      final archivo = File('${carpeta.path}/inv$version.sqlite');
      crear(archivo.path);

      final db = AppDatabase(NativeDatabase(archivo));
      addTearDown(db.close);

      final producto = await db
          .into(db.productos)
          .insert(ProductosCompanion.insert(nombre: 'Pan', precio: 500));
      final usuario = (await db.select(db.usuarios).get()).first.id;
      await db
          .into(db.conteosInventario)
          .insert(
            ConteosInventarioCompanion.insert(
              productoId: producto,
              cantidad: 10,
              tipo: TipoConteo.inicial,
              usuarioId: usuario,
              fecha: DateTime(2026, 10, 7),
            ),
          );
      expect(
        (await db.select(db.conteosInventario).getSingle()).tipo,
        TipoConteo.inicial,
      );
    });
  }

  test('una base v6 abre en v7 con pedir hasta vacío', () async {
    final archivo = File('${carpeta.path}/v6.sqlite');
    crearBaseV6(archivo.path);

    final db = AppDatabase(NativeDatabase(archivo));
    addTearDown(db.close);

    final producto = await db.select(db.productos).getSingle();
    expect(producto.controlaExistencias, isTrue);
    expect(producto.minimo, 5);
    expect(producto.pedirHasta, isNull);
  });

  test('una base v1 abre en v7 y guarda pedir hasta', () async {
    final archivo = File('${carpeta.path}/v1c.sqlite');
    crearBaseV1(archivo.path);

    final db = AppDatabase(NativeDatabase(archivo));
    addTearDown(db.close);

    final id = await db
        .into(db.productos)
        .insert(
          ProductosCompanion.insert(
            nombre: 'Pan',
            precio: 500,
            pedirHasta: const Value(24),
          ),
        );
    expect(
      (await (db.select(
        db.productos,
      )..where((p) => p.id.equals(id))).getSingle()).pedirHasta,
      24,
    );
  });

  test('una base v7 abre en v8 sin código ni detalles', () async {
    final archivo = File('${carpeta.path}/v7.sqlite');
    crearBaseV7(archivo.path);

    final db = AppDatabase(NativeDatabase(archivo));
    addTearDown(db.close);

    final producto = await db.select(db.productos).getSingle();
    expect(producto.minimo, 5);
    expect(producto.codigoBarras, isNull);
    expect(producto.marca, isNull);
    expect(producto.tamano, isNull);
    expect(producto.envase, isNull);
    expect(producto.tipo, isNull);
  });

  test('una base v1 abre en v8 y guarda código y detalles', () async {
    final archivo = File('${carpeta.path}/v1d.sqlite');
    crearBaseV1(archivo.path);

    final db = AppDatabase(NativeDatabase(archivo));
    addTearDown(db.close);

    final id = await db
        .into(db.productos)
        .insert(
          ProductosCompanion.insert(
            nombre: 'Coca-Cola',
            precio: 4500,
            codigoBarras: const Value('7702004003508'),
            tipo: const Value('bebidas'),
          ),
        );
    final p = await (db.select(
      db.productos,
    )..where((x) => x.id.equals(id))).getSingle();
    expect((p.codigoBarras, p.tipo), ('7702004003508', 'bebidas'));
  });

  test('una base v8 abre en v9 sin pedidos y con gastos sin entrada', () async {
    final archivo = File('${carpeta.path}/v8.sqlite');
    crearBaseV8(archivo.path);

    final db = AppDatabase(NativeDatabase(archivo));
    addTearDown(db.close);

    final gasto = await db.select(db.gastos).getSingle();
    expect(gasto.entradaId, isNull);
    expect(await db.select(db.pedidos).get(), isEmpty);
    expect(await db.select(db.lineasPedido).get(), isEmpty);
  });

  test(
    'una base v1 abre en v9 y guarda pedidos y gastos con entrada',
    () async {
      final archivo = File('${carpeta.path}/v1p.sqlite');
      crearBaseV1(archivo.path);

      final db = AppDatabase(NativeDatabase(archivo));
      addTearDown(db.close);

      final usuario = (await db.select(db.usuarios).get()).first.id;
      final proveedor = await db
          .into(db.proveedores)
          .insert(ProveedoresCompanion.insert(nombre: 'Postobón'));
      final producto = await db
          .into(db.productos)
          .insert(ProductosCompanion.insert(nombre: 'Coca', precio: 1500));
      final pedido = await db
          .into(db.pedidos)
          .insert(
            PedidosCompanion.insert(
              proveedorId: proveedor,
              usuarioId: usuario,
              fecha: DateTime(2026, 10, 16),
            ),
          );
      await db
          .into(db.lineasPedido)
          .insert(
            LineasPedidoCompanion.insert(
              pedidoId: pedido,
              productoId: producto,
              cantidad: 24,
            ),
          );
      final entrada = await db
          .into(db.entradasMercancia)
          .insert(
            EntradasMercanciaCompanion.insert(
              proveedorId: proveedor,
              usuarioId: usuario,
              fecha: DateTime(2026, 10, 18),
              total: 21600,
            ),
          );
      await db
          .into(db.gastos)
          .insert(
            GastosCompanion.insert(
              monto: 21600,
              fecha: DateTime(2026, 10, 18),
              usuarioId: usuario,
              entradaId: Value(entrada),
            ),
          );

      final guardado = await db.select(db.pedidos).getSingle();
      expect(guardado.estado, EstadoPedido.porLlegar);
      expect(guardado.entradaId, isNull);
      expect(
        (await db.select(db.lineasPedido).getSingle()).precioEsperado,
        isNull,
      );
      final gastos = await db.select(db.gastos).get();
      expect(gastos.last.entradaId, entrada);
    },
  );

  test('una base v9 abre en v10 con clientes sin apellido', () async {
    final archivo = File('${carpeta.path}/v9.sqlite');
    crearBaseV9(archivo.path);

    final db = AppDatabase(NativeDatabase(archivo));
    addTearDown(db.close);

    final cliente = await db.select(db.clientes).getSingle();
    expect(cliente.nombre, 'Don Pedro');
    expect(cliente.apellido, isNull);
  });

  test('una base v1 abre en v10 y guarda apellido', () async {
    final archivo = File('${carpeta.path}/v1c.sqlite');
    crearBaseV1(archivo.path);

    final db = AppDatabase(NativeDatabase(archivo));
    addTearDown(db.close);

    await db
        .into(db.clientes)
        .insert(
          ClientesCompanion.insert(
            nombre: 'Juan',
            apellido: const Value('Pérez'),
          ),
        );
    final clientes = await db.select(db.clientes).get();
    expect(clientes.last.apellido, 'Pérez');
  });

  test(
    'una base v10 abre en v11 con un id global distinto en cada fila',
    () async {
      final archivo = File('${carpeta.path}/v10.sqlite');
      crearBaseV10(archivo.path);
      final db = AppDatabase(NativeDatabase(archivo));
      addTearDown(db.close);

      for (final tabla in tablasConIdGlobal) {
        final ids = await idsGlobales(db, tabla);
        expect(ids.every((id) => id.length == 36), isTrue, reason: tabla);
        expect(ids.toSet().length, ids.length, reason: tabla);
      }
      expect((await idsGlobales(db, 'ventas')), isNotEmpty);
      expect((await db.select(db.clientes).getSingle()).nombre, 'Don Pedro');
    },
  );

  test('una base v10 con 500 ventas recibe 500 ids distintos', () async {
    final archivo = File('${carpeta.path}/v10m.sqlite');
    crearBaseV10(archivo.path);
    final sqlite = sqlite3.open(archivo.path);
    for (var i = 0; i < 499; i++) {
      sqlite.execute(
        'INSERT INTO ventas (monto, fecha, usuario_id) VALUES (1000, 0, 1)',
      );
    }
    sqlite.close();

    final db = AppDatabase(NativeDatabase(archivo));
    addTearDown(db.close);

    final ids = await idsGlobales(db, 'ventas');
    expect(ids.length, 500);
    expect(ids.toSet().length, 500);
  });

  test('una base v1 abre en v11 y guarda filas nuevas con id global', () async {
    final archivo = File('${carpeta.path}/v1g.sqlite');
    crearBaseV1(archivo.path);
    final db = AppDatabase(NativeDatabase(archivo));
    addTearDown(db.close);

    await db.into(db.clientes).insert(ClientesCompanion.insert(nombre: 'Juan'));

    final ids = await idsGlobales(db, 'clientes');
    expect(ids, hasLength(2));
    expect(ids.every((id) => id.length == 36), isTrue);
    expect(ids.toSet(), hasLength(2));
  });

  test(
    'una base v10 migrada tiene las mismas columnas que una base nueva',
    () async {
      final archivo = File('${carpeta.path}/v10c.sqlite');
      crearBaseV10(archivo.path);
      final migrada = AppDatabase(NativeDatabase(archivo));
      addTearDown(migrada.close);
      final nueva = AppDatabase(NativeDatabase.memory());
      addTearDown(nueva.close);

      expect(await columnasPorTabla(migrada), await columnasPorTabla(nueva));
    },
  );

  test('una base v10 migrada tiene los índices únicos de id global', () async {
    final archivo = File('${carpeta.path}/v10i.sqlite');
    crearBaseV10(archivo.path);
    final db = AppDatabase(NativeDatabase(archivo));
    addTearDown(db.close);

    for (final tabla in tablasConIdGlobal) {
      final indices = await db
          .customSelect("PRAGMA index_list('$tabla')")
          .get();
      final indice = indices.where(
        (i) => i.read<String>('name') == '${tabla}_id_global',
      );
      expect(indice, hasLength(1), reason: tabla);
      expect(indice.single.read<int>('unique'), 1, reason: tabla);
    }
  });

  test(
    'la migración deja la versión 11 solo con todas las filas llenas',
    () async {
      final archivo = File('${carpeta.path}/v10v.sqlite');
      crearBaseV10(archivo.path);
      final db = AppDatabase(NativeDatabase(archivo));
      addTearDown(db.close);

      final version = await db.customSelect('PRAGMA user_version').getSingle();
      expect(version.read<int>('user_version'), 11);
      for (final tabla in tablasConIdGlobal) {
        final vacios = await db
            .customSelect(
              "SELECT COUNT(*) AS n FROM $tabla WHERE id_global = ''",
            )
            .getSingle();
        expect(vacios.read<int>('n'), 0, reason: tabla);
      }
    },
  );

  test(
    'una migración interrumpida no deja la base a medias y se reintenta',
    () async {
      final archivo = File('${carpeta.path}/v9f.sqlite');
      crearBaseV9(archivo.path);
      // Simula que el celular falla a mitad del llenado de ids (gastos va
      // después de clientes, que ya recibió su apellido y sus ids).
      sqlite3.open(archivo.path)
        ..execute(
          'CREATE TRIGGER falla BEFORE UPDATE ON gastos '
          "BEGIN SELECT RAISE(ABORT, 'falla'); END;",
        )
        ..close();

      final fallida = AppDatabase(NativeDatabase(archivo));
      await expectLater(
        fallida.select(fallida.clientes).get(),
        throwsA(anything),
      );
      await fallida.close();

      final revisada = sqlite3.open(archivo.path);
      expect(revisada.userVersion, 9);
      final columnasClientes = revisada
          .select("PRAGMA table_info('clientes')")
          .map((c) => c['name'])
          .toList();
      expect(columnasClientes, isNot(contains('apellido')));
      revisada
        ..execute('DROP TRIGGER falla')
        ..close();

      final db = AppDatabase(NativeDatabase(archivo));
      addTearDown(db.close);
      expect((await db.select(db.clientes).getSingle()).nombre, 'Don Pedro');
      final ids = await idsGlobales(db, 'gastos');
      expect(ids.every((id) => id.length == 36), isTrue);
    },
  );

  test(
    'una base v9 migrada tiene las mismas columnas que una base nueva',
    () async {
      final archivo = File('${carpeta.path}/v9c.sqlite');
      crearBaseV9(archivo.path);
      final migrada = AppDatabase(NativeDatabase(archivo));
      addTearDown(migrada.close);
      final nueva = AppDatabase(NativeDatabase.memory());
      addTearDown(nueva.close);

      expect(await columnasPorTabla(migrada), await columnasPorTabla(nueva));
    },
  );

  test(
    'una base v9 migrada lista las entradas recientes con su proveedor',
    () async {
      final archivo = File('${carpeta.path}/v9e.sqlite');
      crearBaseV9(archivo.path);
      final db = AppDatabase(NativeDatabase(archivo));
      addTearDown(db.close);
      final usuario = (await db.select(db.usuarios).get()).first.id;
      final proveedor = await db
          .into(db.proveedores)
          .insert(ProveedoresCompanion.insert(nombre: 'Postobón'));
      await db
          .into(db.entradasMercancia)
          .insert(
            EntradasMercanciaCompanion.insert(
              proveedorId: proveedor,
              usuarioId: usuario,
              fecha: DateTime(2026, 10, 26),
              total: 21600,
            ),
          );

      final entradas = await InventarioRepository(db).entradasRecientes();

      expect(entradas.single.proveedor, 'Postobón');
    },
  );
}

/// Los `id_global` de todas las filas de [tabla].
Future<List<String>> idsGlobales(AppDatabase db, String tabla) async {
  final filas = await db.customSelect('SELECT id_global FROM $tabla').get();
  return [for (final fila in filas) fila.read<String>('id_global')];
}

/// Nombres de columnas de cada tabla de [db], para comparar esquemas.
Future<Map<String, Set<String>>> columnasPorTabla(AppDatabase db) async {
  final tablas = await db
      .customSelect(
        "SELECT name FROM sqlite_master WHERE type = 'table' "
        "AND name NOT LIKE 'sqlite_%' ORDER BY name",
      )
      .get();
  return {
    for (final tabla in tablas)
      tabla.read<String>('name'): {
        for (final columna
            in await db
                .customSelect(
                  "PRAGMA table_info('${tabla.read<String>('name')}')",
                )
                .get())
          columna.read<String>('name'),
      },
  };
}
