import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../providers/proveedores_providers.dart';
import '../../providers/repository_providers.dart';
import '../../ui/avisos.dart';
import '../../ui/boton_principal.dart';
import '../../ui/colores_app.dart';
import '../../ui/estado_vacio.dart';
import '../../ui/hoja_inferior.dart';
import '../../util/formato_moneda.dart';
import '../../util/texto_util.dart';

/// Proveedores de la tienda: crear, editar, desactivar y reactivar.
class ProveedoresScreen extends ConsumerWidget {
  const ProveedoresScreen({super.key});

  Future<void> _abrir(BuildContext context, {Proveedor? proveedor}) async {
    final guardado = await mostrarHojaInferior<bool>(
      context,
      titulo: proveedor == null ? 'Nuevo proveedor' : 'Editar proveedor',
      builder: (_) => _FormularioProveedor(proveedor: proveedor),
    );
    if (guardado == true && context.mounted) {
      avisar(context, 'Proveedor guardado');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activosAsync = ref.watch(proveedoresActivosProvider);
    final inactivos =
        ref.watch(proveedoresInactivosProvider).valueOrNull ??
        const <Proveedor>[];
    final conteo =
        ref.watch(cantidadProductosPorProveedorProvider).valueOrNull ??
        const {};
    final repo = ref.read(proveedorRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Proveedores')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('boton_agregar_proveedor_nuevo'),
        onPressed: () => _abrir(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Agregar'),
      ),
      body: activosAsync.when(
        data: (activos) {
          if (activos.isEmpty && inactivos.isEmpty) {
            return const EstadoVacio(
              icono: Icons.local_shipping_outlined,
              titulo: 'Aún no tienes proveedores',
              mensaje: 'Agrega a quién le compras para armar tus pedidos',
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              if (activos.isNotEmpty)
                Card(
                  child: Column(
                    children: [
                      for (final p in activos)
                        ListTile(
                          key: Key('proveedor_item_${p.id}'),
                          title: Text(
                            p.nombre,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            [
                              if (p.telefono != null) p.telefono!,
                              'Surte ${plural(conteo[p.id] ?? 0, 'producto', 'productos')}',
                            ].join(' · '),
                          ),
                          onTap: () => _abrir(context, proveedor: p),
                          trailing: IconButton(
                            key: Key('boton_desactivar_proveedor_${p.id}'),
                            tooltip: 'Desactivar',
                            icon: const Icon(Icons.visibility_off_outlined),
                            onPressed: () => repo.desactivar(p.id),
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
                          key: Key('proveedor_inactivo_${p.id}'),
                          title: Text(
                            p.nombre,
                            style: const TextStyle(
                              color: ColoresApp.textoSecundario,
                            ),
                          ),
                          trailing: TextButton(
                            key: Key('boton_reactivar_proveedor_${p.id}'),
                            onPressed: () => repo.reactivar(p.id),
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

class _FormularioProveedor extends ConsumerStatefulWidget {
  const _FormularioProveedor({this.proveedor});

  final Proveedor? proveedor;

  @override
  ConsumerState<_FormularioProveedor> createState() =>
      _FormularioProveedorState();
}

class _FormularioProveedorState extends ConsumerState<_FormularioProveedor> {
  late final _nombre = TextEditingController(text: widget.proveedor?.nombre);
  late final _telefono = TextEditingController(
    text: widget.proveedor?.telefono,
  );
  late final _notas = TextEditingController(text: widget.proveedor?.notas);
  String? _error;
  bool _guardando = false;

  @override
  void dispose() {
    _nombre.dispose();
    _telefono.dispose();
    _notas.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_guardando) return;
    if (_nombre.text.trim().isEmpty) {
      setState(() => _error = 'Escribe un nombre');
      return;
    }
    setState(() => _guardando = true);
    try {
      final repo = ref.read(proveedorRepositoryProvider);
      final id = widget.proveedor?.id;
      if (id == null) {
        await repo.crear(
          nombre: _nombre.text,
          telefono: _telefono.text,
          notas: _notas.text,
        );
      } else {
        await repo.actualizar(
          id,
          nombre: _nombre.text,
          telefono: _telefono.text,
          notas: _notas.text,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.proveedor?.id;
    final productos = id == null
        ? const <({Producto producto, int precioCompra})>[]
        : ref.watch(productosDeProveedorProvider(id)).valueOrNull ??
              const <({Producto producto, int precioCompra})>[];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('campo_nombre_proveedor'),
          controller: _nombre,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(labelText: 'Nombre', errorText: _error),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('campo_telefono_proveedor'),
          controller: _telefono,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'Teléfono'),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('campo_notas_proveedor'),
          controller: _notas,
          decoration: const InputDecoration(labelText: 'Notas'),
        ),
        if (productos.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            'Productos que surte',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          for (final p in productos)
            Text('${p.producto.nombre} · ${formatoMoneda(p.precioCompra)}'),
        ],
        const SizedBox(height: 16),
        BotonPrincipal(
          key: const Key('boton_guardar_proveedor'),
          texto: 'Guardar',
          onPressed: _guardando ? null : _guardar,
        ),
      ],
    );
  }
}
