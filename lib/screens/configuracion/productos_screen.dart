import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../providers/productos_providers.dart';
import '../../providers/repository_providers.dart';
import '../../ui/avisos.dart';
import '../../ui/colores_app.dart';
import '../../ui/estado_vacio.dart';
import '../../util/formato_moneda.dart';
import 'producto_screen.dart';

class ProductosScreen extends ConsumerStatefulWidget {
  const ProductosScreen({super.key});

  @override
  ConsumerState<ProductosScreen> createState() => _ProductosScreenState();
}

class _ProductosScreenState extends ConsumerState<ProductosScreen> {
  Future<void> _abrir({Producto? producto}) async {
    final guardado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ProductoScreen(producto: producto)),
    );
    if (guardado == true && mounted) avisar(context, 'Producto guardado');
  }

  @override
  Widget build(BuildContext context) {
    final productosAsync = ref.watch(productosActivosProvider);
    final inactivos =
        ref.watch(productosInactivosProvider).valueOrNull ?? const <Producto>[];
    final costos =
        ref.watch(costosProductosProvider).valueOrNull ?? const <int, int>{};
    return Scaffold(
      appBar: AppBar(title: const Text('Productos')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('boton_agregar_producto'),
        onPressed: () => _abrir(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Agregar'),
      ),
      body: productosAsync.when(
        data: (productos) {
          if (productos.isEmpty && inactivos.isEmpty) {
            return const EstadoVacio(
              icono: Icons.inventory_2_outlined,
              titulo: 'Aún no tienes productos',
              mensaje: 'Agrega los que más vendes para cobrarlos con un toque',
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              if (productos.isNotEmpty)
                Card(
                  child: Column(
                    children: [
                      for (final p in productos)
                        ListTile(
                          key: Key('producto_item_${p.id}'),
                          title: Text(p.nombre,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(costos[p.id] == null
                              ? '${formatoMoneda(p.precio)} · sin costo'
                              : '${formatoMoneda(p.precio)} · gana '
                                  '${formatoMoneda(p.precio - costos[p.id]!)}'),
                          onTap: () => _abrir(producto: p),
                          trailing: IconButton(
                            key: Key('boton_desactivar_${p.id}'),
                            tooltip: 'Desactivar',
                            icon: const Icon(Icons.visibility_off_outlined),
                            onPressed: () => ref
                                .read(productoRepositoryProvider)
                                .desactivarProducto(p.id),
                          ),
                        ),
                    ],
                  ),
                ),
              if (inactivos.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(4, 24, 4, 8),
                  child: Text(
                    'Inactivos',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: ColoresApp.textoSecundario,
                    ),
                  ),
                ),
                Card(
                  child: Column(
                    children: [
                      for (final p in inactivos)
                        ListTile(
                          key: Key('producto_inactivo_${p.id}'),
                          title: Text(p.nombre,
                              style: const TextStyle(
                                  color: ColoresApp.textoSecundario)),
                          subtitle: Text(formatoMoneda(p.precio)),
                          trailing: TextButton(
                            key: Key('boton_reactivar_${p.id}'),
                            onPressed: () => ref
                                .read(productoRepositoryProvider)
                                .reactivarProducto(p.id),
                            child: const Text('Reactivar'),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
