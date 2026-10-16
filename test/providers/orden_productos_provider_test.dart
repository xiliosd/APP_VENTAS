import 'package:app_ventas/providers/orden_productos_provider.dart';
import 'package:app_ventas/respaldo/respaldo_provider.dart';
import 'package:app_ventas/util/orden_productos.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<(ProviderContainer, SharedPreferences)> crear(
    Map<String, Object> valores,
  ) async {
    SharedPreferences.setMockInitialValues(valores);
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [preferenciasProvider.overrideWithValue(prefs)],
    );
    addTearDown(c.dispose);
    return (c, prefs);
  }

  test('cada listado arranca en A–Z', () async {
    final (c, _) = await crear({});
    expect(
      c.read(ordenProductosProvider(ListadoProductos.venta)),
      OrdenProductos.alfabetico,
    );
    expect(
      c.read(ordenProductosProvider(ListadoProductos.ajustes)),
      OrdenProductos.alfabetico,
    );
  });

  test('cada listado recuerda su propia elección', () async {
    final (c, prefs) = await crear({});

    await c
        .read(ordenProductosProvider(ListadoProductos.venta).notifier)
        .elegir(OrdenProductos.masVendidos);

    expect(
      c.read(ordenProductosProvider(ListadoProductos.venta)),
      OrdenProductos.masVendidos,
    );
    expect(
      c.read(ordenProductosProvider(ListadoProductos.ajustes)),
      OrdenProductos.alfabetico,
    );
    expect(prefs.getString('orden_productos_venta'), 'masVendidos');
  });

  test('lee lo guardado e ignora valores desconocidos', () async {
    final (c, _) = await crear({
      'orden_productos_ajustes': 'creacion',
      'orden_productos_venta': 'raro',
    });
    expect(
      c.read(ordenProductosProvider(ListadoProductos.ajustes)),
      OrdenProductos.creacion,
    );
    expect(
      c.read(ordenProductosProvider(ListadoProductos.venta)),
      OrdenProductos.alfabetico,
    );
  });
}
