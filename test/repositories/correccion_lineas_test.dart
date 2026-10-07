import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/repositories/correccion_repository.dart';
import 'package:app_ventas/repositories/venta_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late CorreccionRepository repo;
  late VentaRepository ventas;
  late Usuario ana;
  late int ventaId;
  late LineaVenta deArepa;
  late LineaVenta deCoca;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = CorreccionRepository(db);
    ventas = VentaRepository(db);
    final id = await db.into(db.usuarios).insert(
        UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'x'));
    ana = await (db.select(db.usuarios)..where((u) => u.id.equals(id)))
        .getSingle();
    final arepa = await db
        .into(db.productos)
        .insert(ProductosCompanion.insert(nombre: 'Arepa', precio: 3500));
    final coca = await db
        .into(db.productos)
        .insert(ProductosCompanion.insert(nombre: 'Cocacola', precio: 1200));
    ventaId = await ventas.registrarVenta(
      monto: 8200,
      esFiado: false,
      usuarioId: ana.id,
      lineas: [
        LineaNueva(
            productoId: arepa,
            descripcion: 'Arepa',
            precioUnitario: 3500,
            cantidad: 2),
        LineaNueva(
            productoId: coca,
            descripcion: 'Cocacola',
            precioUnitario: 1200,
            cantidad: 1),
      ],
    );
    final lineas = await ventas.lineasDeVenta(ventaId);
    deArepa = lineas[0];
    deCoca = lineas[1];
  });

  tearDown(() => db.close());

  Future<Venta> venta() =>
      (db.select(db.ventas)..where((v) => v.id.equals(ventaId))).getSingle();

  test('cambiar cantidades recalcula el monto y guarda los productos antes',
      () async {
    await repo.corregirVenta(ventaId,
        monto: 1, // se ignora: la venta tiene líneas
        esFiado: false,
        cantidades: {deArepa.id: 3, deCoca.id: 0},
        por: ana);

    expect((await venta()).monto, 10500);
    final lineas = await ventas.lineasDeVenta(ventaId);
    expect(lineas.single.id, deArepa.id);
    expect(lineas.single.cantidad, 3);
    expect((await db.select(db.correcciones).getSingle()).antes,
        r'$8.200 · Contado · Efectivo · 2× Arepa, 1× Cocacola');
  });

  test('quitar todas las líneas se rechaza y nada cambia', () async {
    await expectLater(
        repo.corregirVenta(ventaId,
            monto: 8200,
            esFiado: false,
            cantidades: {deArepa.id: 0, deCoca.id: 0},
            por: ana),
        throwsA(isA<CorreccionInvalida>()
            .having((e) => e.mensaje, 'mensaje',
                'Para quitar todo, anula la venta')));

    expect((await venta()).monto, 8200);
    expect(await ventas.lineasDeVenta(ventaId), hasLength(2));
    expect(await db.select(db.correcciones).get(), isEmpty);
  });

  test('sin cambios de cantidad conserva las líneas y su total', () async {
    await repo.corregirVenta(ventaId,
        monto: 8200,
        esFiado: false,
        medioPago: MedioPago.transferencia,
        por: ana);

    final v = await venta();
    expect(v.monto, 8200);
    expect(v.medioPago, MedioPago.transferencia);
    expect(await ventas.lineasDeVenta(ventaId), hasLength(2));
  });

  test('anular guarda los productos en antes y conserva las líneas',
      () async {
    await repo.anularVenta(ventaId, por: ana);

    expect((await db.select(db.correcciones).getSingle()).antes,
        r'$8.200 · Contado · Efectivo · 2× Arepa, 1× Cocacola');
    expect(await ventas.lineasDeVenta(ventaId), hasLength(2));
  });

  test('una venta sin detalle se sigue corrigiendo por monto', () async {
    final vieja =
        await ventas.registrarVenta(monto: 4000, esFiado: false, usuarioId: ana.id);

    await repo.corregirVenta(vieja, monto: 4500, esFiado: false, por: ana);

    final v = await (db.select(db.ventas)..where((x) => x.id.equals(vieja)))
        .getSingle();
    expect(v.monto, 4500);
  });
}
