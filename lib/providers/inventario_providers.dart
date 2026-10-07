import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../repositories/inventario_repository.dart';
import 'database_provider.dart';
import 'repository_providers.dart';

/// Emite con cada cambio en la base (mismo patrón que fiado_providers).
final _cambiosInventarioProvider = StreamProvider<void>((ref) {
  return ref.watch(databaseProvider).tableUpdates().map((_) {});
});

final productosConControlProvider =
    FutureProvider<List<({Producto producto, int existencias})>>((ref) {
      ref.watch(_cambiosInventarioProvider);
      return ref.watch(inventarioRepositoryProvider).productosConControl();
    });

final porPedirProvider = FutureProvider<List<GrupoPorPedir>>((ref) {
  ref.watch(_cambiosInventarioProvider);
  return ref.watch(inventarioRepositoryProvider).porPedir();
});

final entradasRecientesProvider = FutureProvider<List<EntradaResumen>>((ref) {
  ref.watch(_cambiosInventarioProvider);
  return ref.watch(inventarioRepositoryProvider).entradasRecientes();
});

final existenciasProductoProvider = FutureProvider.autoDispose
    .family<int?, int>((ref, productoId) {
      ref.watch(_cambiosInventarioProvider);
      return ref.watch(inventarioRepositoryProvider).existencias(productoId);
    });

final historialInventarioProvider = FutureProvider.autoDispose
    .family<List<MovimientoInventario>, int>((ref, productoId) {
      ref.watch(_cambiosInventarioProvider);
      return ref.watch(inventarioRepositoryProvider).historial(productoId);
    });

final detalleEntradaProvider = FutureProvider.autoDispose
    .family<
      ({
        EntradaResumen resumen,
        List<({LineaEntrada linea, String producto})> lineas,
      }),
      int
    >((ref, entradaId) {
      ref.watch(_cambiosInventarioProvider);
      return ref.watch(inventarioRepositoryProvider).detalleEntrada(entradaId);
    });

final sugerenciaPedidoProvider = FutureProvider.autoDispose
    .family<List<LineaSugerida>, int?>((ref, proveedorId) {
      ref.watch(_cambiosInventarioProvider);
      return ref
          .watch(inventarioRepositoryProvider)
          .sugerenciaPedido(proveedorId);
    });
