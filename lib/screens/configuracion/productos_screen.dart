import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/productos_providers.dart';
import '../../providers/repository_providers.dart';
import '../../util/formato_moneda.dart';

class ProductosScreen extends ConsumerStatefulWidget {
  const ProductosScreen({super.key});

  @override
  ConsumerState<ProductosScreen> createState() => _ProductosScreenState();
}

class _ProductosScreenState extends ConsumerState<ProductosScreen> {
  final _nombreController = TextEditingController();
  final _precioController = TextEditingController();

  Future<void> _crear() async {
    final nombre = _nombreController.text.trim();
    final precio = int.tryParse(_precioController.text.trim());
    if (nombre.isEmpty || precio == null || precio <= 0) return;
    await ref
        .read(productoRepositoryProvider)
        .crearProducto(nombre: nombre, precio: precio);
    _nombreController.clear();
    _precioController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final productosAsync = ref.watch(productosActivosProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Productos')),
      body: Column(
        children: [
          Expanded(
            child: productosAsync.when(
              data: (productos) => ListView(
                children: productos
                    .map((p) => ListTile(
                          key: Key('producto_item_${p.id}'),
                          title: Text(p.nombre),
                          subtitle: Text(formatoMoneda(p.precio)),
                          trailing: IconButton(
                            key: Key('boton_desactivar_${p.id}'),
                            icon: const Icon(Icons.delete),
                            onPressed: () => ref
                                .read(productoRepositoryProvider)
                                .desactivarProducto(p.id),
                          ),
                        ))
                    .toList(),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Error: $e')),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  key: const Key('campo_nombre_producto'),
                  controller: _nombreController,
                  decoration: const InputDecoration(labelText: 'Nombre del producto'),
                ),
                TextField(
                  key: const Key('campo_precio_producto'),
                  controller: _precioController,
                  decoration: const InputDecoration(labelText: 'Precio'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  key: const Key('boton_crear_producto'),
                  onPressed: _crear,
                  child: const Text('Agregar producto'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
