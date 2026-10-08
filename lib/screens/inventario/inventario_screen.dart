import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../providers/inventario_providers.dart';
import '../../providers/sesion_provider.dart';
import '../../ui/avisos.dart';
import '../../ui/boton_principal.dart';
import '../../ui/colores_app.dart';
import '../../ui/estado_vacio.dart';
import '../../ui/selector_segmentado.dart';
import '../../util/fecha_util.dart';
import '../../util/formato_moneda.dart';
import '../../util/texto_util.dart';
import 'detalle_entrada_screen.dart';
import 'detalle_inventario_screen.dart';
import 'pedido_sugerido_screen.dart';
import 'recibir_mercancia_screen.dart';

/// "5" o "−2" (signo menos tipográfico).
String numeroConSigno(int n) => n < 0 ? '−${-n}' : '$n';

/// "12 u" o "−2 u".
String textoExistencias(int existencias) => '${numeroConSigno(existencias)} u';

enum _Vista { porPedir, todos }

/// Existencias de los productos con control, lo que hay que pedir y las
/// entradas de mercancía.
class InventarioScreen extends ConsumerStatefulWidget {
  const InventarioScreen({super.key});

  @override
  ConsumerState<InventarioScreen> createState() => _InventarioScreenState();
}

class _InventarioScreenState extends ConsumerState<InventarioScreen> {
  _Vista? _vista;

  Future<void> _recibir() async {
    final total = await Navigator.of(context).push<int>(
      MaterialPageRoute(builder: (_) => const RecibirMercanciaScreen()),
    );
    if (total != null && mounted) {
      avisar(context, 'Mercancía recibida · ${formatoMoneda(total)}');
    }
  }

  Future<void> _verPedido(Proveedor? proveedor) async {
    final total = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (_) => PedidoSugeridoScreen(proveedor: proveedor),
      ),
    );
    if (total != null && mounted) {
      avisar(context, 'Mercancía recibida · ${formatoMoneda(total)}');
    }
  }

  void _abrir(Widget pantalla) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => pantalla));

  @override
  Widget build(BuildContext context) {
    final controlados =
        ref.watch(productosConControlProvider).valueOrNull ?? const [];
    final grupos = ref.watch(porPedirProvider).valueOrNull ?? const [];
    final entradas =
        ref.watch(entradasRecientesProvider).valueOrNull ?? const [];
    final nPorPedir = grupos.fold<int>(0, (s, g) => s + g.productos.length);
    final vista = _vista ?? (nPorPedir > 0 ? _Vista.porPedir : _Vista.todos);
    const gris = TextStyle(color: ColoresApp.textoSecundario);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        BotonPrincipal(
          key: const Key('boton_recibir_mercancia'),
          texto: 'Recibir mercancía',
          icono: Icons.local_shipping_outlined,
          onPressed: _recibir,
        ),
        const SizedBox(height: 12),
        if (controlados.isEmpty)
          EstadoVacio(
            icono: Icons.inventory_2_outlined,
            titulo: 'Aún no controlas existencias',
            mensaje: ref.watch(sesionProvider).esAdmin
                ? 'Actívalo en Ajustes → Productos'
                : 'Pídele al administrador que lo active',
          )
        else ...[
          SelectorSegmentado<_Vista>(
            key: const Key('selector_inventario'),
            opciones: {
              _Vista.porPedir: 'Por pedir ($nPorPedir)',
              _Vista.todos: 'Todos',
            },
            valor: vista,
            onCambio: (v) => setState(() => _vista = v),
          ),
          const SizedBox(height: 12),
          if (vista == _Vista.todos)
            Card(
              child: Column(
                children: [
                  for (final c in controlados)
                    ListTile(
                      key: Key('inventario_item_${c.producto.id}'),
                      title: Text(
                        c.producto.nombre,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text('mín. ${c.producto.minimo}'),
                      trailing: Text(
                        textoExistencias(c.existencias),
                        key: Key('existencias_${c.producto.id}'),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: c.existencias <= c.producto.minimo
                              ? ColoresApp.sale
                              : ColoresApp.texto,
                        ),
                      ),
                      onTap: () => _abrir(
                        DetalleInventarioScreen(productoId: c.producto.id),
                      ),
                    ),
                ],
              ),
            )
          else if (grupos.isEmpty)
            const Text(
              'Nada por pedir',
              key: Key('texto_nada_por_pedir'),
              style: gris,
            )
          else
            for (final g in grupos) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 0, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${g.proveedor?.nombre ?? 'Sin proveedor'} · '
                        '${plural(g.productos.length, 'producto', 'productos')}',
                        key: Key('grupo_por_pedir_${g.proveedor?.id ?? 'sin'}'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    TextButton(
                      key: Key('ver_pedido_${g.proveedor?.id ?? 'sin'}'),
                      onPressed: () => _verPedido(g.proveedor),
                      child: const Text('Ver pedido sugerido'),
                    ),
                  ],
                ),
              ),
              Card(
                child: Column(
                  children: [
                    for (final p in g.productos)
                      ListTile(
                        key: Key('por_pedir_${p.producto.id}'),
                        title: Text(p.producto.nombre),
                        subtitle: Text(
                          'quedan ${numeroConSigno(p.existencias)} · '
                          'mín. ${p.producto.minimo}',
                        ),
                        onTap: () => _abrir(
                          DetalleInventarioScreen(productoId: p.producto.id),
                        ),
                      ),
                  ],
                ),
              ),
            ],
        ],
        if (entradas.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 24, 4, 8),
            child: Text(
              'Entradas recibidas',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
          Card(
            child: Column(
              children: [
                for (final e in entradas)
                  ListTile(
                    key: Key('entrada_${e.entrada.id}'),
                    title: Text(
                      '${e.proveedor} · ${formatoMoneda(e.entrada.total)}',
                      style: TextStyle(
                        decoration: e.entrada.anulada
                            ? TextDecoration.lineThrough
                            : null,
                        color: e.entrada.anulada
                            ? ColoresApp.textoSecundario
                            : null,
                      ),
                    ),
                    subtitle: Text(
                      '${formatoFechaHora(e.entrada.fecha)} · ${e.usuario}',
                    ),
                    onTap: () =>
                        _abrir(DetalleEntradaScreen(entradaId: e.entrada.id)),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
