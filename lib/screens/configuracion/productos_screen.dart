import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../providers/productos_providers.dart';
import '../../providers/repository_providers.dart';
import '../../ui/avisos.dart';
import '../../ui/boton_principal.dart';
import '../../ui/colores_app.dart';
import '../../ui/estado_vacio.dart';
import '../../ui/hoja_inferior.dart';
import '../../ui/monto.dart';
import '../../util/formato_moneda.dart';
import 'editar_producto_dialog.dart';

class ProductosScreen extends ConsumerStatefulWidget {
  const ProductosScreen({super.key});

  @override
  ConsumerState<ProductosScreen> createState() => _ProductosScreenState();
}

class _ProductosScreenState extends ConsumerState<ProductosScreen> {
  Future<void> _agregar() async {
    final guardado = await mostrarHojaInferior<bool>(
      context,
      titulo: 'Nuevo producto',
      builder: (_) => const _FormularioProducto(),
    );
    if (guardado == true && mounted) avisar(context, 'Producto guardado');
  }

  Future<void> _editar(Producto producto) async {
    final guardado = await showDialog<bool>(
      context: context,
      builder: (_) => EditarProductoDialog(producto: producto),
    );
    if (guardado == true && mounted) avisar(context, 'Producto guardado');
  }

  @override
  Widget build(BuildContext context) {
    final productosAsync = ref.watch(productosActivosProvider);
    final inactivos =
        ref.watch(productosInactivosProvider).valueOrNull ?? const <Producto>[];
    return Scaffold(
      appBar: AppBar(title: const Text('Productos')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('boton_agregar_producto'),
        onPressed: _agregar,
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
                          subtitle: Monto(p.precio, tamano: 15),
                          onTap: () => _editar(p),
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

class _FormularioProducto extends ConsumerStatefulWidget {
  const _FormularioProducto();

  @override
  ConsumerState<_FormularioProducto> createState() =>
      _FormularioProductoState();
}

class _FormularioProductoState extends ConsumerState<_FormularioProducto> {
  final _nombreController = TextEditingController();
  final _precioController = TextEditingController();
  String? _errorNombre;
  String? _errorPrecio;
  bool _guardando = false;

  @override
  void dispose() {
    _nombreController.dispose();
    _precioController.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_guardando) return;
    final nombre = _nombreController.text.trim();
    final precio = parsearMonto(_precioController.text);
    setState(() {
      _errorNombre = nombre.isEmpty ? 'Escribe un nombre' : null;
      _errorPrecio =
          (precio == null || precio <= 0) ? 'Escribe un precio válido' : null;
    });
    if (_errorNombre != null || _errorPrecio != null) return;

    setState(() => _guardando = true);
    try {
      await ref
          .read(productoRepositoryProvider)
          .crearProducto(nombre: nombre, precio: precio!);
      if (mounted) Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          key: const Key('campo_nombre_producto'),
          controller: _nombreController,
          autofocus: true,
          decoration: InputDecoration(
              labelText: 'Nombre del producto', errorText: _errorNombre),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('campo_precio_producto'),
          controller: _precioController,
          keyboardType: TextInputType.number,
          decoration:
              InputDecoration(labelText: 'Precio', errorText: _errorPrecio),
        ),
        const SizedBox(height: 16),
        BotonPrincipal(
          key: const Key('boton_crear_producto'),
          texto: 'Guardar producto',
          onPressed: _guardando ? null : _guardar,
        ),
      ],
    );
  }
}
