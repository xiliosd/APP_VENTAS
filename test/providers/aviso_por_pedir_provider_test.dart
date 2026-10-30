import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/aviso_por_pedir_provider.dart';
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
}
