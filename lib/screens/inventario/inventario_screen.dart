import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../providers/inventario_providers.dart';
import '../../providers/sesion_provider.dart';
import '../../ui/avisos.dart';
import '../../ui/avatar_inicial.dart';
import '../../ui/entrada_escalonada.dart';
import '../../ui/monto.dart';
import '../../ui/nivel_existencias.dart';
import '../../ui/boton_principal.dart';
import '../../ui/colores_app.dart';
import '../../ui/estado_vacio.dart';
import '../../ui/selector_segmentado.dart';
import '../../ui/titulo_seccion.dart';
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
    final c = ColoresApp.of(context);
    final controlados =
        ref.watch(productosConControlProvider).valueOrNull ?? const [];
    final grupos = ref.watch(porPedirProvider).valueOrNull ?? const [];
    final entradas =
        ref.watch(entradasRecientesProvider).valueOrNull ?? const [];
    final nPorPedir = grupos.fold<int>(0, (s, g) => s + g.productos.length);
    final agotados = controlados
        .where((x) =>
            nivelExistencias(x.existencias, x.producto.minimo) ==
            NivelExistencias.agotado)
        .length;
    final vista = _vista ?? (nPorPedir > 0 ? _Vista.porPedir : _Vista.todos);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (controlados.isNotEmpty) ...[
          EntradaEscalonada(
            indice: 0,
            child: Card(
              key: const Key('resumen_inventario'),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  children: [
                    _Cifra(
                        clave: 'resumen_controlados',
                        valor: controlados.length,
                        rotulo: 'Controlados'),
                    _Cifra(
                        clave: 'resumen_por_pedir',
                        valor: nPorPedir,
                        rotulo: 'Por pedir'),
                    _Cifra(
                        clave: 'resumen_agotados',
                        valor: agotados,
                        rotulo: 'Agotados',
                        color: agotados > 0 ? c.sale : null),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
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
            EntradaEscalonada(
              indice: 1,
              child: Card(
                child: Column(
                  children: [
                    for (final (i, x) in controlados.indexed) ...[
                      if (i > 0) const Divider(height: 1),
                      _FilaInventario(
                        producto: x.producto,
                        existencias: x.existencias,
                        onTap: () => _abrir(
                          DetalleInventarioScreen(productoId: x.producto.id),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            )
          else if (grupos.isEmpty)
            const EstadoVacio(
              key: Key('texto_nada_por_pedir'),
              icono: Icons.check_circle_rounded,
              titulo: 'Todo en orden',
              mensaje: 'Ningún producto está en su mínimo',
            )
          else
            for (final (i, g) in grupos.indexed)
              EntradaEscalonada(
                indice: i + 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 8, 0, 4),
                      // Si no caben, el botón baja a su propia línea.
                      child: OverflowBar(
                        alignment: MainAxisAlignment.spaceBetween,
                        overflowAlignment: OverflowBarAlignment.start,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.local_shipping_rounded,
                                  size: 18, color: c.textoSecundario),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  '${g.proveedor?.nombre ?? 'Sin proveedor'} · '
                                  '${plural(g.productos.length, 'producto', 'productos')}',
                                  key: Key(
                                      'grupo_por_pedir_${g.proveedor?.id ?? 'sin'}'),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                          FilledButton.tonal(
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
                              trailing: EtiquetaNivel(
                                nivel: nivelExistencias(
                                    p.existencias, p.producto.minimo),
                              ),
                              onTap: () => _abrir(
                                DetalleInventarioScreen(
                                    productoId: p.producto.id),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
        ],
        if (entradas.isNotEmpty) ...[
          const SizedBox(height: 24),
          const TituloSeccion('ENTRADAS RECIBIDAS'),
          Card(
            child: Column(
              children: [
                for (final e in entradas)
                  ListTile(
                    key: Key('entrada_${e.entrada.id}'),
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: (e.entrada.anulada ? c.textoSecundario : c.entra)
                            .withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.local_shipping_rounded,
                          size: 20,
                          color: e.entrada.anulada
                              ? c.textoSecundario
                              : c.entra),
                    ),
                    title: Text(
                      e.proveedor,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: e.entrada.anulada ? c.textoSecundario : null,
                      ),
                    ),
                    subtitle: Text(
                      '${formatoFechaHora(e.entrada.fecha)} · ${e.usuario}',
                    ),
                    trailing: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 120),
                      child: Monto(e.entrada.total,
                          tamano: 16, tachado: e.entrada.anulada),
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

/// Una cifra del resumen con su rótulo.
class _Cifra extends StatelessWidget {
  const _Cifra({
    required this.clave,
    required this.valor,
    required this.rotulo,
    this.color,
  });

  final String clave;
  final int valor;
  final String rotulo;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = ColoresApp.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(
            '$valor',
            key: Key(clave),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: color ?? c.texto,
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              rotulo,
              style: TextStyle(fontSize: 12, color: c.textoSecundario),
            ),
          ),
        ],
      ),
    );
  }
}

/// Producto en la vista "Todos": nombre, mínimo, barra y existencias.
class _FilaInventario extends StatelessWidget {
  const _FilaInventario({
    required this.producto,
    required this.existencias,
    required this.onTap,
  });

  final Producto producto;
  final int existencias;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = ColoresApp.of(context);
    final nivel = nivelExistencias(existencias, producto.minimo);
    return InkWell(
      key: Key('inventario_item_${producto.id}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            AvatarInicial(id: producto.id, nombre: producto.nombre),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(producto.nombre,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text('mín. ${producto.minimo}',
                      style: TextStyle(
                          fontSize: 12, color: c.textoSecundario)),
                  const SizedBox(height: 6),
                  BarraNivel(
                    key: Key('nivel_${producto.id}'),
                    fraccion: fraccionNivel(
                        existencias, producto.minimo, producto.pedirHasta),
                    nivel: nivel,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  textoExistencias(existencias),
                  key: Key('existencias_${producto.id}'),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: existencias <= producto.minimo ? c.sale : c.texto,
                  ),
                ),
                const SizedBox(height: 4),
                EtiquetaNivel(
                    key: Key('etiqueta_nivel_${producto.id}'), nivel: nivel),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
