import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import 'database_provider.dart';
import 'repository_providers.dart';

final proveedoresActivosProvider = StreamProvider<List<Proveedor>>(
  (ref) => ref.watch(proveedorRepositoryProvider).observarActivos(),
);

final proveedoresInactivosProvider = StreamProvider<List<Proveedor>>(
  (ref) => ref.watch(proveedorRepositoryProvider).observarInactivos(),
);

/// Emite con cada cambio en la base (mismo patrón que fiado_providers).
final _cambiosProveedoresProvider = StreamProvider<void>((ref) {
  return ref.watch(databaseProvider).tableUpdates().map((_) {});
});

final cantidadProductosPorProveedorProvider =
    FutureProvider<Map<int, int>>((ref) {
  ref.watch(_cambiosProveedoresProvider);
  return ref.watch(proveedorRepositoryProvider).cantidadProductos();
});

final productosDeProveedorProvider = FutureProvider.autoDispose
    .family<List<({Producto producto, int precioCompra})>, int>((ref, id) {
  ref.watch(_cambiosProveedoresProvider);
  return ref.watch(proveedorRepositoryProvider).productosDe(id);
});
