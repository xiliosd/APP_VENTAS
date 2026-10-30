import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../providers/inventario_providers.dart';
import '../../providers/proveedores_providers.dart';
import '../../providers/repository_providers.dart';
import '../../providers/sesion_provider.dart';
import '../../repositories/inventario_repository.dart';
import '../../repositories/pedido_repository.dart';
import '../../ui/barra_accion_fija.dart';
import '../../ui/boton_cantidad.dart';
import '../../ui/boton_principal.dart';
import '../../ui/colores_app.dart';
import '../../ui/dialogo_cantidad.dart';
import '../../ui/estado_vacio.dart';
import '../../util/formato_moneda.dart';
import 'inventario_screen.dart';

/// Cuánto pedirle a [proveedor] (null = "Sin proveedor"). Las cantidades se
/// editan en pantalla; "Guardar pedido" lo deja por llegar y cierra con true.
class PedidoSugeridoScreen extends ConsumerStatefulWidget {
  const PedidoSugeridoScreen({super.key, required this.proveedor});

  final Proveedor? proveedor;

  @override
  ConsumerState<PedidoSugeridoScreen> createState() =>
      _PedidoSugeridoScreenState();
}

class _PedidoSugeridoScreenState extends ConsumerState<PedidoSugeridoScreen> {
  /// Cantidades cambiadas por id de producto.
  final Map<int, int> _cantidades = {};

  /// Proveedor elegido cuando el del grupo no sirve (sin proveedor o inactivo).
  Proveedor? _elegido;
  bool _guardando = false;
  String? _error;

  int _cantidad(LineaSugerida l) => _cantidades[l.producto.id] ?? l.sugerido;

  bool get _proveedorFijo => widget.proveedor?.activo ?? false;

  Proveedor? get _proveedor => _proveedorFijo ? widget.proveedor : _elegido;

  Future<void> _guardar(List<LineaSugerida> lineas) async {
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await ref
          .read(pedidoRepositoryProvider)
          .guardarPedido(
            proveedorId: _proveedor!.id,
            lineas: [
              for (final l in lineas)
                if (_cantidad(l) > 0)
                  LineaPedidoNueva(
                    productoId: l.producto.id,
                    cantidad: _cantidad(l),
                    // Sin proveedor fijo, el precio sugerido no es de este.
                    precioEsperado: _proveedorFijo ? l.precio : null,
                  ),
            ],
            por: ref.read(sesionProvider).usuarioActivo!,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudo guardar, intenta de nuevo');
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pedido = ref.watch(sugerenciaPedidoProvider(widget.proveedor?.id));
    final lineas = pedido.valueOrNull ?? const <LineaSugerida>[];
    final total = lineas.fold<int>(
      0,
      (s, l) => s + (l.precio == null ? 0 : _cantidad(l) * l.precio!),
    );
    final puedeGuardar =
        !_guardando &&
        _proveedor != null &&
        lineas.any((l) => _cantidad(l) > 0);
    final proveedores = _proveedorFijo
        ? const <Proveedor>[]
        : ref.watch(proveedoresActivosProvider).valueOrNull ??
              const <Proveedor>[];
    final gris = TextStyle(color: ColoresApp.of(context).textoSecundario);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Pedido sugerido · ${widget.proveedor?.nombre ?? 'Sin proveedor'}',
        ),
      ),
      bottomNavigationBar: pedido.hasValue && lineas.isNotEmpty
          ? BarraAccionFija(
              total: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_error != null)
                    Text(
                      _error!,
                      key: const Key('error_guardar_pedido'),
                      style: TextStyle(color: ColoresApp.of(context).sale),
                    ),
                  Text(
                    'Total estimado ${formatoMoneda(total)}',
                    key: const Key('total_pedido'),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              boton: BotonPrincipal(
                key: const Key('boton_guardar_pedido'),
                texto: 'Guardar pedido',
                onPressed: puedeGuardar ? () => _guardar(lineas) : null,
              ),
            )
          : null,
      body: !pedido.hasValue
          ? pedido.hasError
                ? const EstadoVacio(
                    icono: Icons.error_outline_rounded,
                    titulo: 'No se pudo cargar el pedido',
                  )
                : const Center(child: CircularProgressIndicator())
          : lineas.isEmpty
          ? EstadoVacio(
              icono: Icons.inventory_2_outlined,
              titulo: widget.proveedor == null
                  ? 'No hay nada por pedir'
                  : 'No hay nada por pedir a este proveedor',
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (!_proveedorFijo) ...[
                  const Text(
                    '¿A qué proveedor se lo pides?',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final p in proveedores)
                        ChoiceChip(
                          key: Key('opcion_proveedor_pedido_${p.id}'),
                          label: Text(p.nombre),
                          selected: _elegido?.id == p.id,
                          onSelected: (_) => setState(() => _elegido = p),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                for (final l in lineas)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
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
                                  'quedan ${numeroConSigno(l.existencias)} · '
                                  'mín. ${l.producto.minimo}'
                                  '${l.producto.pedirHasta == null ? '' : ' · hasta ${l.producto.pedirHasta}'}',
                                  style: gris,
                                ),
                                if (l.porLlegar > 0)
                                  Text(
                                    'ya pedido · llegan ${l.porLlegar}',
                                    key: Key('llegan_pedido_${l.producto.id}'),
                                    style: gris,
                                  ),
                                Text(
                                  l.precio == null
                                      ? 'Sin precio'
                                      : '${_cantidad(l)} × '
                                            '${formatoMoneda(l.precio!)} = '
                                            '${formatoMoneda(_cantidad(l) * l.precio!)}',
                                  key: Key('precio_pedido_${l.producto.id}'),
                                  style: gris,
                                ),
                              ],
                            ),
                          ),
                          BotonCantidad(
                            key: Key('restar_pedido_${l.producto.id}'),
                            icono: Icons.remove_rounded,
                            tooltip: 'Restar',
                            onPressed: _cantidad(l) > 0
                                ? () => setState(
                                    () => _cantidades[l.producto.id] =
                                        _cantidad(l) - 1,
                                  )
                                : null,
                          ),
                          InkWell(
                            onTap: () async {
                              final n = await pedirCantidad(
                                context,
                                actual: _cantidad(l),
                              );
                              if (n != null && mounted) {
                                setState(() => _cantidades[l.producto.id] = n);
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 12,
                              ),
                              child: Text(
                                '${_cantidad(l)}',
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
                            onPressed: () => setState(
                              () =>
                                  _cantidades[l.producto.id] = _cantidad(l) + 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
