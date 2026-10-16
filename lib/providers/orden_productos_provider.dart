import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../respaldo/respaldo_provider.dart';
import 'repository_providers.dart';
import '../util/orden_productos.dart';

/// Listados de productos que recuerdan su orden por separado.
enum ListadoProductos { venta, ajustes }

class OrdenDeListado extends FamilyNotifier<OrdenProductos, ListadoProductos> {
  String get _clave => 'orden_productos_${arg.name}';

  @override
  OrdenProductos build(ListadoProductos arg) {
    final guardado = ref.read(preferenciasProvider).getString(_clave);
    return OrdenProductos.values.where((o) => o.name == guardado).firstOrNull ??
        OrdenProductos.alfabetico;
  }

  Future<void> elegir(OrdenProductos orden) async {
    state = orden;
    await ref.read(preferenciasProvider).setString(_clave, orden.name);
  }
}

/// Orden elegido en este celular para cada listado; arranca en A–Z.
final ordenProductosProvider =
    NotifierProvider.family<OrdenDeListado, OrdenProductos, ListadoProductos>(
      OrdenDeListado.new,
    );

/// Unidades vendidas por producto en los últimos 30 días, para "Más
/// vendidos".
final unidadesVendidasProvider = FutureProvider.autoDispose<Map<int, int>>(
  (ref) => ref
      .watch(productoRepositoryProvider)
      .unidadesVendidas(
        desde: DateTime.now().subtract(const Duration(days: 30)),
      ),
);
