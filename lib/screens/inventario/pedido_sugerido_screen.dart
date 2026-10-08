import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../providers/inventario_providers.dart';
import '../../repositories/inventario_repository.dart';
import '../../ui/boton_principal.dart';
import '../../ui/colores_app.dart';
import '../../ui/dialogo_cantidad.dart';
import '../../util/formato_moneda.dart';
import 'inventario_screen.dart';
import 'recibir_mercancia_screen.dart';

/// Cuánto pedirle a [proveedor] (null = "Sin proveedor"). Las cantidades se
/// editan en pantalla y no se guardan. Si se recibe, se cierra con el total.
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

  int _cantidad(LineaSugerida l) => _cantidades[l.producto.id] ?? l.sugerido;

  Future<void> _recibir(List<LineaSugerida> lineas) async {
    final total = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (_) => RecibirMercanciaScreen(
          proveedorInicial: (widget.proveedor?.activo ?? false)
              ? widget.proveedor
              : null,
          lineasIniciales: [
            for (final l in lineas)
              if (_cantidad(l) > 0)
                LineaInicial(
                  producto: l.producto,
                  cantidad: _cantidad(l),
                  precio: l.precio,
                ),
          ],
        ),
      ),
    );
    if (total != null && mounted) Navigator.of(context).pop(total);
  }

  @override
  Widget build(BuildContext context) {
    final lineas =
        ref.watch(sugerenciaPedidoProvider(widget.proveedor?.id)).valueOrNull ??
        const <LineaSugerida>[];
    final total = lineas.fold<int>(
      0,
      (s, l) => s + (l.precio == null ? 0 : _cantidad(l) * l.precio!),
    );
    final hayAlgo = lineas.any((l) => _cantidad(l) > 0);
    const gris = TextStyle(color: ColoresApp.textoSecundario);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Pedido sugerido · ${widget.proveedor?.nombre ?? 'Sin proveedor'}',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final l in lineas)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.producto.nombre,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            'quedan ${numeroConSigno(l.existencias)} · '
                            'mín. ${l.producto.minimo}'
                            '${l.producto.pedirHasta == null ? '' : ' · hasta ${l.producto.pedirHasta}'}',
                            style: gris,
                          ),
                          Text(
                            l.precio == null
                                ? 'Sin precio'
                                : '${formatoMoneda(l.precio!)} c/u',
                            key: Key('precio_pedido_${l.producto.id}'),
                            style: gris,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      key: Key('restar_pedido_${l.producto.id}'),
                      tooltip: 'Restar',
                      icon: const Icon(Icons.remove_rounded),
                      onPressed: _cantidad(l) > 0
                          ? () => setState(
                              () =>
                                  _cantidades[l.producto.id] = _cantidad(l) - 1,
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
                    IconButton(
                      key: Key('sumar_pedido_${l.producto.id}'),
                      tooltip: 'Sumar',
                      icon: const Icon(Icons.add_rounded),
                      onPressed: () => setState(
                        () => _cantidades[l.producto.id] = _cantidad(l) + 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          Text(
            'Total estimado ${formatoMoneda(total)}',
            key: const Key('total_pedido'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 24),
          BotonPrincipal(
            key: const Key('boton_recibir_pedido'),
            texto: 'Recibir este pedido',
            onPressed: hayAlgo ? () => _recibir(lineas) : null,
          ),
        ],
      ),
    );
  }
}
