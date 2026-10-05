import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../providers/productos_providers.dart';
import '../../providers/repository_providers.dart';
import '../../util/formato_moneda.dart';
import 'editar_producto_dialog.dart';

class ProductosScreen extends ConsumerStatefulWidget {
  const ProductosScreen({super.key});

  @override
  ConsumerState<ProductosScreen> createState() => _ProductosScreenState();
}

class _ProductosScreenState extends ConsumerState<ProductosScreen> {
  final _nombreController = TextEditingController();
  final _precioController = TextEditingController();

  @override
  void dispose() {
    _nombreController.dispose();
    _precioController.dispose();
    super.dispose();
  }

  Future<void> _crear() async {
    final nombre = _nombreController.text.trim();
    final precio = parsearMonto(_precioController.text);
    if (nombre.isEmpty || precio == null || precio <= 0) return;
    await ref
        .read(productoRepositoryProvider)
        .crearProducto(nombre: nombre, precio: precio);
    _nombreController.clear();
    _precioController.clear();
  }

  Future<void> _editar(Producto producto) async {
    await showDialog<bool>(
      context: context,
      builder: (_) => EditarProductoDialog(producto: producto),
    );
  }

  @override
  Widget build(BuildContext context) {
    final productosAsync = ref.watch(productosActivosProvider);
    final inactivos =
        ref.watch(productosInactivosProvider).valueOrNull ?? const <Producto>[];
    return Scaffold(
      appBar: AppBar(title: const Text('Productos')),
      body: Column(
        children: [
          Expanded(
            child: productosAsync.when(
              data: (productos) => ListView(
                children: [
                  ...productos.map((p) => ListTile(
                        key: Key('producto_item_${p.id}'),
                        title: Text(p.nombre),
                        subtitle: Text(formatoMoneda(p.precio)),
                        onTap: () => _editar(p),
                        trailing: IconButton(
                          key: Key('boton_desactivar_${p.id}'),
                          icon: const Icon(Icons.delete),
                          onPressed: () => ref
                              .read(productoRepositoryProvider)
                              .desactivarProducto(p.id),
                        ),
                      )),
                  if (inactivos.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                      child: Text(
                        'Inactivos',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ...inactivos.map((p) => ListTile(
                        key: Key('producto_inactivo_${p.id}'),
                        title: Text(p.nombre),
                        subtitle: Text(formatoMoneda(p.precio)),
                        trailing: TextButton(
                          key: Key('boton_reactivar_${p.id}'),
                          onPressed: () => ref
                              .read(productoRepositoryProvider)
                              .reactivarProducto(p.id),
                          child: const Text('Reactivar'),
                        ),
                      )),
                ],
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
                  decoration:
                      const InputDecoration(labelText: 'Nombre del producto'),
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
