import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../providers/productos_providers.dart';

/// Buscador de productos activos que aún no están en la lista (entrada o pedido).
class HojaProductos extends ConsumerStatefulWidget {
  const HojaProductos({super.key, required this.excluir});

  final Set<int> excluir;

  @override
  ConsumerState<HojaProductos> createState() => _HojaProductosState();
}

class _HojaProductosState extends ConsumerState<HojaProductos> {
  String _busqueda = '';

  @override
  Widget build(BuildContext context) {
    final buscado = _busqueda.trim().toLowerCase();
    final productos =
        (ref.watch(productosActivosProvider).valueOrNull ?? const <Producto>[])
            .where(
              (p) =>
                  !widget.excluir.contains(p.id) &&
                  p.nombre.toLowerCase().contains(buscado),
            )
            .toList()
          ..sort((a, b) => a.nombre.compareTo(b.nombre));
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('campo_buscar_producto'),
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Buscar producto',
            prefixIcon: Icon(Icons.search_rounded),
          ),
          onChanged: (v) => setState(() => _busqueda = v),
        ),
        const SizedBox(height: 8),
        for (final p in productos.take(20))
          ListTile(
            key: Key('opcion_producto_recibir_${p.id}'),
            title: Text(p.nombre),
            onTap: () => Navigator.of(context).pop(p),
          ),
      ],
    );
  }
}
