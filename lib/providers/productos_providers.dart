import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import 'database_provider.dart';
import 'repository_providers.dart';

final productosActivosProvider = StreamProvider<List<Producto>>((ref) {
  return ref.watch(productoRepositoryProvider).observarProductosActivos();
});

final productosInactivosProvider = StreamProvider<List<Producto>>((ref) {
  return ref.watch(productoRepositoryProvider).observarProductosInactivos();
});

/// Emite con cada cambio en la base, para refrescar los costos.
final _cambiosCostosProvider = StreamProvider<void>((ref) {
  return ref.watch(databaseProvider).tableUpdates().map((_) {});
});

/// Producto → costo (precio del proveedor preferido).
final costosProductosProvider = FutureProvider<Map<int, int>>((ref) {
  ref.watch(_cambiosCostosProvider);
  return ref.watch(productoRepositoryProvider).costos();
});
