import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import 'repository_providers.dart';

final productosActivosProvider = StreamProvider<List<Producto>>((ref) {
  return ref.watch(productoRepositoryProvider).observarProductosActivos();
});

final productosInactivosProvider = StreamProvider<List<Producto>>((ref) {
  return ref.watch(productoRepositoryProvider).observarProductosInactivos();
});
