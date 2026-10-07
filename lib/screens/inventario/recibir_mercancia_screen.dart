import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../providers/productos_providers.dart';
import '../../providers/proveedores_providers.dart';
import '../../providers/repository_providers.dart';
import '../../providers/sesion_provider.dart';
import '../../repositories/inventario_repository.dart';
import '../../ui/boton_principal.dart';
import '../../ui/colores_app.dart';
import '../../ui/hoja_inferior.dart';
import '../../util/formato_moneda.dart';

class _Linea {
  _Linea(this.producto, String precio)
    : precio = TextEditingController(text: precio);

  final Producto producto;
  int cantidad = 1;
  final TextEditingController precio;

  int? get precioValido {
    final p = parsearMonto(precio.text);
    return p == null || p <= 0 ? null : p;
  }
}

/// Registra la mercancía que trajo un proveedor. Al guardar se cierra
/// devolviendo el total.
class RecibirMercanciaScreen extends ConsumerStatefulWidget {
  const RecibirMercanciaScreen({super.key});

  @override
  ConsumerState<RecibirMercanciaScreen> createState() =>
      _RecibirMercanciaScreenState();
}

class _RecibirMercanciaScreenState
    extends ConsumerState<RecibirMercanciaScreen> {
  Proveedor? _proveedor;
  final List<_Linea> _lineas = [];
  final _nota = TextEditingController();
  bool _guardando = false;

  @override
  void dispose() {
    for (final l in _lineas) {
      l.precio.dispose();
    }
    _nota.dispose();
    super.dispose();
  }

  Future<String> _precioSugerido(int productoId) async {
    final repo = ref.read(productoRepositoryProvider);
    final proveedor = _proveedor;
    if (proveedor != null) {
      final vinculo = (await repo.proveedoresDe(productoId))
          .where((v) => v.proveedorId == proveedor.id)
          .firstOrNull;
      if (vinculo != null) return '${vinculo.precioCompra}';
    }
    final costo = await repo.costoDe(productoId);
    return costo == null ? '' : '$costo';
  }

  Future<void> _agregarProducto() async {
    final producto = await mostrarHojaInferior<Producto>(
      context,
      titulo: 'Agregar producto',
      builder: (_) =>
          _HojaProductos(excluir: {for (final l in _lineas) l.producto.id}),
    );
    if (producto == null) return;
    final precio = await _precioSugerido(producto.id);
    if (!mounted) return;
    setState(() => _lineas.add(_Linea(producto, precio)));
  }

  int get _total =>
      _lineas.fold(0, (s, l) => s + l.cantidad * (l.precioValido ?? 0));

  bool get _puedeGuardar =>
      !_guardando &&
      _proveedor != null &&
      _lineas.isNotEmpty &&
      _lineas.every((l) => l.precioValido != null);

  Future<void> _guardar() async {
    if (!_puedeGuardar) return;
    setState(() => _guardando = true);
    try {
      final total = _total;
      await ref
          .read(inventarioRepositoryProvider)
          .recibirMercancia(
            proveedorId: _proveedor!.id,
            lineas: [
              for (final l in _lineas)
                LineaRecibida(
                  productoId: l.producto.id,
                  cantidad: l.cantidad,
                  precioCompra: l.precioValido!,
                ),
            ],
            nota: _nota.text,
            por: ref.read(sesionProvider).usuarioActivo!,
          );
      if (mounted) Navigator.of(context).pop(total);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final proveedores =
        ref.watch(proveedoresActivosProvider).valueOrNull ??
        const <Proveedor>[];
    return Scaffold(
      appBar: AppBar(title: const Text('Recibir mercancía')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Proveedor',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in proveedores)
                ChoiceChip(
                  key: Key('opcion_proveedor_recibir_${p.id}'),
                  label: Text(p.nombre),
                  selected: _proveedor?.id == p.id,
                  onSelected: (_) => setState(() => _proveedor = p),
                ),
            ],
          ),
          const SizedBox(height: 16),
          for (final l in _lineas)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            l.producto.nombre,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        IconButton(
                          key: Key('quitar_recibir_${l.producto.id}'),
                          tooltip: 'Quitar',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => setState(() {
                            _lineas.remove(l);
                            l.precio.dispose();
                          }),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          key: Key('restar_recibir_${l.producto.id}'),
                          tooltip: 'Restar',
                          icon: const Icon(Icons.remove_rounded),
                          onPressed: l.cantidad > 1
                              ? () => setState(() => l.cantidad--)
                              : null,
                        ),
                        Text(
                          '${l.cantidad}',
                          key: Key('cantidad_recibir_${l.producto.id}'),
                        ),
                        IconButton(
                          key: Key('sumar_recibir_${l.producto.id}'),
                          tooltip: 'Sumar',
                          icon: const Icon(Icons.add_rounded),
                          onPressed: () => setState(() => l.cantidad++),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            key: Key('precio_recibir_${l.producto.id}'),
                            controller: l.precio,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              labelText: 'Precio de compra',
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      formatoMoneda(l.cantidad * (l.precioValido ?? 0)),
                      textAlign: TextAlign.right,
                      style: const TextStyle(color: ColoresApp.textoSecundario),
                    ),
                  ],
                ),
              ),
            ),
          TextButton.icon(
            key: const Key('boton_agregar_producto_recibir'),
            onPressed: _agregarProducto,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Agregar producto'),
          ),
          const SizedBox(height: 12),
          Text(
            'Total ${formatoMoneda(_total)}',
            key: const Key('total_recibir'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('campo_nota_recibir'),
            controller: _nota,
            decoration: const InputDecoration(labelText: 'Nota'),
          ),
          const SizedBox(height: 24),
          BotonPrincipal(
            key: const Key('boton_guardar_recibir'),
            texto: 'Guardar',
            onPressed: _puedeGuardar ? _guardar : null,
          ),
        ],
      ),
    );
  }
}

/// Buscador de productos activos que aún no están en la entrada.
class _HojaProductos extends ConsumerStatefulWidget {
  const _HojaProductos({required this.excluir});

  final Set<int> excluir;

  @override
  ConsumerState<_HojaProductos> createState() => _HojaProductosState();
}

class _HojaProductosState extends ConsumerState<_HojaProductos> {
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
