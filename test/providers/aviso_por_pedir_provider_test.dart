import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/aviso_por_pedir_provider.dart';
import 'package:app_ventas/repositories/inventario_repository.dart';
import 'package:app_ventas/repositories/producto_repository.dart';
import 'package:app_ventas/repositories/venta_repository.dart';
import 'package:app_ventas/providers/sesion_provider.dart';
import 'package:app_ventas/util/aviso_existencias.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/montaje.dart';

AvisoExistencias aviso(int id, String nombre, int hay) => AvisoExistencias(
  productoId: id,
  nombre: nombre,
  existencias: hay,
  minimo: 5,
);

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    container = await containerConSesion(db);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('mostrar une por producto y el nuevo reemplaza al viejo', () {
    final notifier = container.read(avisoPorPedirProvider.notifier);
    notifier.mostrar([aviso(1, 'Coca', 3), aviso(2, 'Pan', 2)]);
    notifier.mostrar([aviso(1, 'Coca', 0)]);
    final estado = container.read(avisoPorPedirProvider);
    expect(estado, hasLength(2));
    expect(estado.firstWhere((a) => a.productoId == 1).existencias, 0);
    expect(estado.any((a) => a.productoId == 2), isTrue);
  });

  test('cerrar deja la lista vacía', () {
    final notifier = container.read(avisoPorPedirProvider.notifier);
    notifier.mostrar([aviso(1, 'Coca', 3)]);
    notifier.cerrar();
    expect(container.read(avisoPorPedirProvider), isEmpty);
  });

  test('cambiar el usuario activo borra el aviso', () async {
    container.read(avisoPorPedirProvider.notifier).mostrar([
      aviso(1, 'Coca', 3),
    ]);
    expect(container.read(avisoPorPedirProvider), isNotEmpty);
    final id = await db
        .into(db.usuarios)
        .insert(
          UsuariosCompanion.insert(
            nombre: 'Luis',
            rol: 'vendedor',
            pinHash: 'x',
          ),
        );
    final otro = await (db.select(
      db.usuarios,
    )..where((u) => u.id.equals(id))).getSingle();
    container.read(sesionProvider.notifier).state = SesionState(
      usuarioActivo: otro,
    );
    expect(container.read(avisoPorPedirProvider), isEmpty);
  });

  test('mostrar deja agotados primero y luego por nombre', () {
    final notifier = container.read(avisoPorPedirProvider.notifier);
    notifier.mostrar([aviso(1, 'Pan', 3)]);
    notifier.mostrar([aviso(2, 'Coca', 3), aviso(3, 'Zumo', 0)]);
    final nombres = container
        .read(avisoPorPedirProvider)
        .map((a) => a.nombre)
        .toList();
    expect(nombres, ['Zumo', 'Coca', 'Pan']);
  });
  group('trasVenta', () {
    late int productoId;

    setUp(() async {
      final usuario = container.read(sesionProvider).usuarioActivo!;
      productoId = await ProductoRepository(db)
          .guardarProducto(nombre: 'Arroz', precio: 1000);
      // Conteo fechado una hora antes para que las ventas cuenten como posteriores.
      await InventarioRepository(
        db,
        reloj: () => DateTime.now().subtract(const Duration(hours: 1)),
      ).activarControl(productoId, cantidad: 6, minimo: 5, por: usuario);
    });

    Future<void> vender(int cantidad) async {
      await VentaRepository(db).registrarVenta(
        monto: 1000 * cantidad,
        esFiado: false,
        usuarioId: container.read(sesionProvider).usuarioActivo!.id,
        lineas: [
          LineaNueva(
            productoId: productoId,
            descripcion: 'Arroz',
            precioUnitario: 1000,
            cantidad: cantidad,
          ),
        ],
      );
    }

    test('actualiza la cantidad de un aviso que ya estaba', () async {
      final notifier = container.read(avisoPorPedirProvider.notifier);
      final inventario = InventarioRepository(db);
      var antes = await inventario.existenciasDe([productoId]);
      await vender(2);
      await notifier.trasVenta(await inventario.avisosTrasVenta(antes));
      expect(container.read(avisoPorPedirProvider).single.existencias, 4);

      antes = await inventario.existenciasDe([productoId]);
      await vender(2);
      // La segunda venta no cruza el mínimo: no hay avisos nuevos.
      await notifier.trasVenta(await inventario.avisosTrasVenta(antes));
      expect(container.read(avisoPorPedirProvider).single.existencias, 2);
    });

    test('quita los que ya no están en el mínimo', () async {
      final notifier = container.read(avisoPorPedirProvider.notifier);
      await vender(2);
      await notifier.trasVenta([aviso(productoId, 'Arroz', 4)]);
      expect(container.read(avisoPorPedirProvider), hasLength(1));

      await InventarioRepository(db).activarControl(
        productoId,
        cantidad: 20,
        minimo: 5,
        por: container.read(sesionProvider).usuarioActivo!,
      );
      await notifier.trasVenta(const []);
      expect(container.read(avisoPorPedirProvider), isEmpty);
    });

    test('sin avisos nuevos ni abiertos no consulta la base', () async {
      final notifier = container.read(avisoPorPedirProvider.notifier);
      await db.close();
      await notifier.trasVenta(const []);
      expect(container.read(avisoPorPedirProvider), isEmpty);
      db = AppDatabase(NativeDatabase.memory());
    });
  });
}
