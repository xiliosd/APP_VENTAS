import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/repositories/correccion_repository.dart';
import 'package:app_ventas/repositories/inventario_repository.dart';
import 'package:app_ventas/repositories/venta_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late InventarioRepository repo;
  late VentaRepository ventas;
  late Usuario ana;
  late int arepa;
  var ahora = DateTime(2026, 10, 7, 8);

  setUp(() async {
    ahora = DateTime(2026, 10, 7, 8);
    db = AppDatabase(NativeDatabase.memory());
    repo = InventarioRepository(db, reloj: () => ahora);
    ventas = VentaRepository(db);
    final id = await db.into(db.usuarios).insert(
        UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'x'));
    ana = await (db.select(db.usuarios)..where((u) => u.id.equals(id)))
        .getSingle();
    arepa = await db
        .into(db.productos)
        .insert(ProductosCompanion.insert(nombre: 'Arepa', precio: 3500));
  });

  tearDown(() => db.close());

  Future<int> vender(int cantidad, DateTime fecha) => ventas.registrarVenta(
        monto: 3500 * cantidad,
        esFiado: false,
        usuarioId: ana.id,
        fecha: fecha,
        lineas: [
          LineaNueva(
              productoId: arepa,
              descripcion: 'Arepa',
              precioUnitario: 3500,
              cantidad: cantidad),
        ],
      );

  test('sin control no hay existencias', () async {
    expect(await repo.existencias(arepa), isNull);
    expect(await repo.existenciasDe([arepa]), isEmpty);
  });

  test('el conteo inicial menos lo vendido después', () async {
    await vender(5, DateTime(2026, 10, 7, 7)); // antes de activar
    await repo.activarControl(arepa, cantidad: 20, minimo: 5, por: ana);
    await vender(3, DateTime(2026, 10, 7, 9));

    expect(await repo.existencias(arepa), 17);
    final p = await (db.select(db.productos)..where((x) => x.id.equals(arepa)))
        .getSingle();
    expect(p.controlaExistencias, isTrue);
    expect(p.minimo, 5);
  });

  test('una venta en el mismo segundo del conteo ya estaba contada',
      () async {
    await repo.activarControl(arepa, cantidad: 20, minimo: 5, por: ana);
    await vender(3, DateTime(2026, 10, 7, 8));

    expect(await repo.existencias(arepa), 20);
  });

  test('anular, corregir y deshacer se reflejan solos', () async {
    await repo.activarControl(arepa, cantidad: 20, minimo: 5, por: ana);
    final anulada = await vender(4, DateTime(2026, 10, 7, 9));
    final corregida = await vender(5, DateTime(2026, 10, 7, 10));
    final deshecha = await vender(2, DateTime(2026, 10, 7, 11));
    expect(await repo.existencias(arepa), 9);

    final correcciones = CorreccionRepository(db);
    await correcciones.anularVenta(anulada, por: ana);
    final linea = (await ventas.lineasDeVenta(corregida)).single;
    await correcciones.corregirVenta(corregida,
        monto: 0, esFiado: false, cantidades: {linea.id: 1}, por: ana);
    await ventas.eliminarVenta(deshecha);

    expect(await repo.existencias(arepa), 19);
  });

  test('quitar la línea al corregir devuelve las unidades', () async {
    final otro = await db
        .into(db.productos)
        .insert(ProductosCompanion.insert(nombre: 'Pan', precio: 500));
    await repo.activarControl(arepa, cantidad: 10, minimo: 0, por: ana);
    final venta = await ventas.registrarVenta(
      monto: 7500,
      esFiado: false,
      usuarioId: ana.id,
      fecha: DateTime(2026, 10, 7, 9),
      lineas: [
        LineaNueva(
            productoId: arepa,
            descripcion: 'Arepa',
            precioUnitario: 3500,
            cantidad: 2),
        LineaNueva(
            productoId: otro, descripcion: 'Pan', precioUnitario: 500, cantidad: 1),
      ],
    );
    expect(await repo.existencias(arepa), 8);

    final lineas = await ventas.lineasDeVenta(venta);
    await CorreccionRepository(db).corregirVenta(venta,
        monto: 0, esFiado: false, cantidades: {lineas[0].id: 0}, por: ana);

    expect(await repo.existencias(arepa), 10);
  });

  test('un ajuste deja atrás lo vendido antes y guarda lo anterior',
      () async {
    await repo.activarControl(arepa, cantidad: 20, minimo: 5, por: ana);
    await vender(3, DateTime(2026, 10, 7, 9));
    ahora = DateTime(2026, 10, 7, 10);
    await repo.ajustarConteo(arepa, cantidad: 15, nota: 'Revisión', por: ana);
    await vender(1, DateTime(2026, 10, 7, 11));

    expect(await repo.existencias(arepa), 14);
    final ajuste = (await db.select(db.conteosInventario).get()).last;
    expect(ajuste.tipo, TipoConteo.ajuste);
    expect(ajuste.anterior, 17);
    expect(ajuste.nota, 'Revisión');
  });

  test('puede quedar en negativo', () async {
    await repo.activarControl(arepa, cantidad: 1, minimo: 0, por: ana);
    await vender(3, DateTime(2026, 10, 7, 9));
    expect(await repo.existencias(arepa), -2);
  });

  test('desactivar quita las existencias y reactivar parte de un conteo nuevo',
      () async {
    await repo.activarControl(arepa, cantidad: 20, minimo: 5, por: ana);
    await vender(3, DateTime(2026, 10, 7, 9));
    await repo.desactivarControl(arepa);
    expect(await repo.existencias(arepa), isNull);

    ahora = DateTime(2026, 10, 7, 12);
    await repo.activarControl(arepa, cantidad: 6, minimo: 2, por: ana);
    await vender(1, DateTime(2026, 10, 7, 13));
    expect(await repo.existencias(arepa), 5);
  });

  test('cambiar el mínimo', () async {
    await repo.activarControl(arepa, cantidad: 20, minimo: 5, por: ana);
    await repo.cambiarMinimo(arepa, 8);
    final p = await (db.select(db.productos)..where((x) => x.id.equals(arepa)))
        .getSingle();
    expect(p.minimo, 8);
  });

  test('valores inválidos se rechazan sin cambiar nada', () async {
    await expectLater(
        repo.activarControl(arepa, cantidad: -1, minimo: 0, por: ana),
        throwsArgumentError);
    await expectLater(
        repo.activarControl(arepa, cantidad: 1, minimo: -1, por: ana),
        throwsArgumentError);
    await expectLater(repo.ajustarConteo(arepa, cantidad: 3, por: ana),
        throwsArgumentError); // sin control
    await expectLater(repo.cambiarMinimo(arepa, -2), throwsArgumentError);
    expect(await db.select(db.conteosInventario).get(), isEmpty);

    await repo.activarControl(arepa, cantidad: 4, minimo: 1, por: ana);
    await expectLater(repo.ajustarConteo(arepa, cantidad: -1, por: ana),
        throwsArgumentError);
    expect(await db.select(db.conteosInventario).get(), hasLength(1));
  });
}
