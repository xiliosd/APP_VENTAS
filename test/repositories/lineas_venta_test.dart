import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/repositories/venta_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late VentaRepository repo;
  late int ana;
  late int arepa;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = VentaRepository(db);
    ana = await db.into(db.usuarios).insert(
        UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'x'));
    arepa = await db
        .into(db.productos)
        .insert(ProductosCompanion.insert(nombre: 'Arepa', precio: 3500));
  });

  tearDown(() => db.close());

  List<LineaNueva> ticket() => [
        LineaNueva(
            productoId: arepa,
            descripcion: 'Arepa',
            precioUnitario: 3500,
            cantidad: 2),
        const LineaNueva(
            descripcion: r'$5.000', precioUnitario: 5000, cantidad: 1),
      ];

  test('registrarVenta guarda las líneas con la venta', () async {
    final id = await repo.registrarVenta(
        monto: 12000, esFiado: false, usuarioId: ana, lineas: ticket());

    final lineas = await repo.lineasDeVenta(id);
    expect(lineas, hasLength(2));
    expect(lineas[0].productoId, arepa);
    expect(lineas[0].cantidad, 2);
    expect(lineas[0].precioUnitario, 3500);
    expect(lineas[1].productoId, isNull);
    expect(lineas[1].descripcion, r'$5.000');
  });

  test('un monto que no es la suma de las líneas se rechaza', () async {
    await expectLater(
        repo.registrarVenta(
            monto: 9999, esFiado: false, usuarioId: ana, lineas: ticket()),
        throwsArgumentError);

    expect(await db.select(db.ventas).get(), isEmpty);
    expect(await db.select(db.lineasVenta).get(), isEmpty);
  });

  test('eliminarVenta borra también sus líneas', () async {
    final id = await repo.registrarVenta(
        monto: 12000, esFiado: false, usuarioId: ana, lineas: ticket());

    await repo.eliminarVenta(id);

    expect(await db.select(db.ventas).get(), isEmpty);
    expect(await db.select(db.lineasVenta).get(), isEmpty);
  });

  test('sin líneas funciona como antes', () async {
    final id =
        await repo.registrarVenta(monto: 3000, esFiado: false, usuarioId: ana);

    expect(await repo.lineasDeVenta(id), isEmpty);
  });
}
