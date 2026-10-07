import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import 'repository_providers.dart';

/// Líneas de una venta (vacío si es una venta vieja sin detalle).
final lineasVentaProvider = FutureProvider.autoDispose
    .family<List<LineaVenta>, int>((ref, ventaId) {
  return ref.watch(ventaRepositoryProvider).lineasDeVenta(ventaId);
});
