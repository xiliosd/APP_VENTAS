import 'dart:io';
import 'dart:typed_data';

import 'package:app_ventas/data/database.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/esquema_v1.dart';
import '../support/esquema_v2.dart';

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
    expect(db.schemaVersion, 3);
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
}
