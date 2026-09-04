import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import 'repository_providers.dart';

final historialDelDiaProvider = FutureProvider.autoDispose<List<Venta>>((ref) {
  return ref.watch(ventaRepositoryProvider).ventasDelDia(DateTime.now());
});
