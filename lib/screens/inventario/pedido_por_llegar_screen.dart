import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../providers/inventario_providers.dart';
import '../../providers/repository_providers.dart';
import '../../providers/sesion_provider.dart';
import '../../repositories/pedido_repository.dart';
import '../../ui/barra_accion_fija.dart';
import '../../ui/boton_cantidad.dart';
import '../../ui/boton_principal.dart';
import '../../ui/colores_app.dart';
import '../../ui/dialogo_cantidad.dart';
import '../../ui/hoja_inferior.dart';
import '../../util/fecha_util.dart';
import '../../util/formato_moneda.dart';
import 'hoja_productos.dart';

class _Linea {
  _Linea(this.producto, this.cantidad, this.precioEsperado);

  final Producto producto;
  int cantidad;
  final int? precioEsperado;
}

/// Un pedido que aún no llega: se pueden cambiar sus productos o anularlo.
/// Se cierra con el aviso que debe mostrar Inventario.
class PedidoPorLlegarScreen extends ConsumerStatefulWidget {
  const PedidoPorLlegarScreen({super.key, required this.pedidoId});

  final int pedidoId;

  @override
  ConsumerState<PedidoPorLlegarScreen> createState() =>
      _PedidoPorLlegarScreenState();
}

class _PedidoPorLlegarScreenState extends ConsumerState<PedidoPorLlegarScreen> {
  List<_Linea>? _lineas;
  bool _guardando = false;
  String? _error;

  Future<void> _agregarProducto() async {
    final producto = await mostrarHojaInferior<Producto>(
      context,
      titulo: 'Agregar producto',
      builder: (_) =>
          HojaProductos(excluir: {for (final l in _lineas!) l.producto.id}),
    );
    if (producto == null || !mounted) return;
    setState(() => _lineas!.add(_Linea(producto, 1, null)));
  }

  Future<void> _guardar() async {
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await ref
          .read(pedidoRepositoryProvider)
          .editarPedido(widget.pedidoId, [
            for (final l in _lineas!)
              LineaPedidoNueva(
                productoId: l.producto.id,
                cantidad: l.cantidad,
                precioEsperado: l.precioEsperado,
              ),
          ], por: ref.read(sesionProvider).usuarioActivo!);
      if (mounted) Navigator.of(context).pop('Pedido actualizado');
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudo guardar, intenta de nuevo');
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _anular() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('¿Anular este pedido?'),
        content: const Text('Deja de contar como mercancía por llegar.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(contexto, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            key: const Key('confirmar_anular_pedido'),
            style: TextButton.styleFrom(
              foregroundColor: ColoresApp.of(context).sale,
            ),
            onPressed: () => Navigator.pop(contexto, true),
            child: const Text('Anular'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;
    try {
      await ref
          .read(pedidoRepositoryProvider)
          .anularPedido(
            widget.pedidoId,
            por: ref.read(sesionProvider).usuarioActivo!,
          );
      if (mounted) Navigator.of(context).pop('Pedido anulado');
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo anular el pedido');
    }
  }

  @override
  Widget build(BuildContext context) {
    final detalle = ref.watch(detallePedidoProvider(widget.pedidoId)).valueOrNull;
    if (detalle == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final lineas = _lineas ??= [
      for (final l in detalle.lineas)
        _Linea(l.producto, l.linea.cantidad, l.linea.precioEsperado),
    ];
    final pedido = detalle.resumen.pedido;
    final usuario = ref.watch(sesionProvider).usuarioActivo;
    final puedeEditar =
        usuario != null &&
        (usuario.rol == 'admin' || usuario.id == pedido.usuarioId);
    final c = ColoresApp.of(context);
    final total = lineas.fold<int>(
      0,
      (s, l) => s + l.cantidad * (l.precioEsperado ?? 0),
    );

    return Scaffold(
      appBar: AppBar(title: Text('Pedido · ${detalle.resumen.proveedor.nombre}')),
      bottomNavigationBar: puedeEditar
          ? BarraAccionFija(
              total: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_error != null)
                    Text(_error!, style: TextStyle(color: c.sale)),
                  Text(
                    'Total estimado ${formatoMoneda(total)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              boton: BotonPrincipal(
                key: const Key('boton_guardar_cambios_pedido'),
                texto: 'Guardar cambios',
                onPressed: !_guardando && lineas.isNotEmpty ? _guardar : null,
              ),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'pedido el ${fechaCorta(pedido.fecha)} · por ${detalle.resumen.usuario}',
            style: TextStyle(color: c.textoSecundario),
          ),
          const SizedBox(height: 12),
          for (final l in lineas)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: puedeEditar
                    ? Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l.producto.nombre,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  l.precioEsperado == null
                                      ? 'Sin precio'
                                      : formatoMoneda(l.precioEsperado!),
                                  style: TextStyle(color: c.textoSecundario),
                                ),
                              ],
                            ),
                          ),
                          BotonCantidad(
                            key: Key('restar_pedido_${l.producto.id}'),
                            icono: Icons.remove_rounded,
                            tooltip: 'Restar',
                            onPressed: l.cantidad > 1
                                ? () => setState(() => l.cantidad--)
                                : null,
                          ),
                          InkWell(
                            onTap: () async {
                              final n = await pedirCantidad(
                                context,
                                actual: l.cantidad,
                                minimo: 1,
                              );
                              if (n != null && mounted) {
                                setState(() => l.cantidad = n);
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 12,
                              ),
                              child: Text(
                                '${l.cantidad}',
                                key: Key('cantidad_pedido_${l.producto.id}'),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          BotonCantidad(
                            key: Key('sumar_pedido_${l.producto.id}'),
                            icono: Icons.add_rounded,
                            tooltip: 'Sumar',
                            onPressed: () => setState(() => l.cantidad++),
                          ),
                          IconButton(
                            key: Key('quitar_pedido_${l.producto.id}'),
                            tooltip: 'Quitar',
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => setState(() => lineas.remove(l)),
                          ),
                        ],
                      )
                    : Text('${l.cantidad} × ${l.producto.nombre}'),
              ),
            ),
          if (puedeEditar) ...[
            TextButton.icon(
              key: const Key('boton_agregar_producto_pedido'),
              onPressed: _agregarProducto,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Agregar producto'),
            ),
            const SizedBox(height: 24),
            BotonPrincipal(
              key: const Key('boton_anular_pedido'),
              texto: 'Anular pedido',
              variante: VarianteBoton.peligro,
              onPressed: _anular,
            ),
          ],
        ],
      ),
    );
  }
}
