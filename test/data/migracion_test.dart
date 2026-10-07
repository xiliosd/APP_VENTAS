import 'dart:io';
import 'dart:typed_data';

import 'package:app_ventas/data/database.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/esquema_v1.dart';
import '../support/esquema_v2.dart';
import '../support/esquema_v3.dart';
import '../support/esquema_v4.dart';
import '../support/esquema_v5.dart';
import '../support/esquema_v6.dart';

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
    final usuario = await db.into(db.usuarios).insert(
        UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'x'));

    await db.into(db.ventas).insert(VentasCompanion.insert(
          monto: 1000,
          fecha: DateTime(2026, 10, 5),
          usuarioId: usuario,
          medioPago: const Value(MedioPago.transferencia),
        ));
    await db.into(db.configuracionTienda).insert(
        ConfiguracionTiendaCompanion.insert(
            id: const Value(1), imagenQr: Value(Uint8List.fromList([1, 2]))));

    expect((await db.select(db.ventas).getSingle()).medioPago,
        MedioPago.transferencia);
    expect((await db.select(db.configuracionTienda).getSingle()).imagenQr,
        [1, 2]);
    expect(db.schemaVersion, 7);
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
    final usuario = await db.into(db.usuarios).insert(
        UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'x'));

    await db.into(db.correcciones).insert(CorreccionesCompanion.insert(
          tipoMovimiento: TipoMovimiento.abono,
          movimientoId: 7,
          accion: AccionCorreccion.anulado,
          usuarioId: usuario,
          fecha: DateTime(2026, 10, 6, 15),
          antes: r'$2.000 · Efectivo',
        ));

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
    final usuario = await db.into(db.usuarios).insert(
        UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'x'));
    final venta = await db.into(db.ventas).insert(VentasCompanion.insert(
        monto: 5000, fecha: DateTime(2026, 10, 7), usuarioId: usuario));

    await db.into(db.lineasVenta).insert(LineasVentaCompanion.insert(
          ventaId: venta,
          descripcion: r'$5.000',
          precioUnitario: 5000,
          cantidad: 1,
        ));

    final linea = await db.select(db.lineasVenta).getSingle();
    expect(linea.ventaId, venta);
    expect(linea.productoId, isNull);
    expect(linea.descripcion, r'$5.000');
  });

  test('una base v4 abre en v5 sin costos, proveedores ni nombre de tienda',
      () async {
    final archivo = File('${carpeta.path}/v4.sqlite');
    crearBaseV4(archivo.path);

    final db = AppDatabase(NativeDatabase(archivo));
    addTearDown(db.close);

    expect((await db.select(db.lineasVenta).getSingle()).costoUnitario,
        isNull);
    expect(await db.select(db.proveedores).get(), isEmpty);
    expect(await db.select(db.productosProveedores).get(), isEmpty);
    expect(await db.select(db.configuracionTienda).get(), isEmpty);
  });

  for (final (version, crear) in [
    (1, crearBaseV1),
    (2, crearBaseV2),
    (3, crearBaseV3),
  ]) {
    test('una base v$version abre en v5 y acepta líneas con costo y nombre',
        () async {
      final archivo = File('${carpeta.path}/vieja$version.sqlite');
      crear(archivo.path);

      final db = AppDatabase(NativeDatabase(archivo));
      addTearDown(db.close);

      final venta = (await db.select(db.ventas).getSingle()).id;
      await db.into(db.lineasVenta).insert(LineasVentaCompanion.insert(
            ventaId: venta,
            descripcion: 'Arepa',
            precioUnitario: 3500,
            cantidad: 1,
            costoUnitario: const Value(2500),
          ));
      await db.into(db.configuracionTienda).insert(
          const ConfiguracionTiendaCompanion(
              id: Value(1), nombreTienda: Value('La Esquina')));
      expect((await db.select(db.lineasVenta).getSingle()).costoUnitario,
          2500);
      expect((await db.select(db.configuracionTienda).getSingle()).nombreTienda,
          'La Esquina');
    });
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
    await db.into(db.productosProveedores).insert(
        ProductosProveedoresCompanion.insert(
            productoId: producto, proveedorId: proveedor, precioCompra: 2500));

    await expectLater(
        db.into(db.productosProveedores).insert(
            ProductosProveedoresCompanion.insert(
                productoId: producto,
                proveedorId: proveedor,
                precioCompra: 2600)),
        throwsA(anything));
    expect((await db.select(db.proveedores).getSingle()).activo, isTrue);
  });

  test('una base v5 abre en v6 con productos sin control de existencias',
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
  });

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
      await db.into(db.conteosInventario).insert(
          ConteosInventarioCompanion.insert(
            productoId: producto,
            cantidad: 10,
            tipo: TipoConteo.inicial,
            usuarioId: usuario,
            fecha: DateTime(2026, 10, 7),
          ));
      expect((await db.select(db.conteosInventario).getSingle()).tipo,
          TipoConteo.inicial);
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

    final id = await db.into(db.productos).insert(ProductosCompanion.insert(
        nombre: 'Pan', precio: 500, pedirHasta: const Value(24)));
    expect(
        (await (db.select(db.productos)..where((p) => p.id.equals(id)))
                .getSingle())
            .pedirHasta,
        24);
  });
}
