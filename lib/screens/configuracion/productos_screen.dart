import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../providers/orden_productos_provider.dart';
import '../../providers/productos_providers.dart';
import '../../providers/repository_providers.dart';
import '../../ui/error_carga.dart';
import '../../ui/avatar_inicial.dart';
import '../../ui/avisos.dart';
import '../../ui/colores_app.dart';
import '../../ui/entrada_escalonada.dart';
import '../../ui/estado_vacio.dart';
import '../../ui/monto.dart';
import '../../ui/pildora.dart';
import '../../ui/titulo_seccion.dart';
import '../../util/busqueda_producto.dart';
import '../../util/catalogo_producto.dart';
import '../../util/formato_moneda.dart';
import '../../util/orden_productos.dart';
import '../../widgets/hoja_orden_productos.dart';
import 'producto_screen.dart';

class ProductosScreen extends ConsumerStatefulWidget {
  const ProductosScreen({super.key});

  @override
  ConsumerState<ProductosScreen> createState() => _ProductosScreenState();
}

class _ProductosScreenState extends ConsumerState<ProductosScreen> {
  final _buscar = TextEditingController();
  String _busqueda = '';

  @override
  void dispose() {
    _buscar.dispose();
    super.dispose();
  }

  String? _tipo;

  bool _coincide(Producto p, String? tipo) =>
      coincideBusqueda(p, _busqueda) && (tipo == null || p.tipo == tipo);

  Future<void> _abrir({Producto? producto}) async {
    final guardado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ProductoScreen(producto: producto)),
    );
    if (guardado == true && mounted) avisar(context, 'Producto guardado');
  }

  @override
  Widget build(BuildContext context) {
    final productosAsync = ref.watch(productosActivosProvider);
    final inactivos =
        ref.watch(productosInactivosProvider).valueOrNull ?? const <Producto>[];
    final costos =
        ref.watch(costosProductosProvider).valueOrNull ?? const <int, int>{};
    return Scaffold(
      appBar: AppBar(
        title: const Text('Productos'),
        actions: const [
          BotonOrdenProductos(
            key: Key('boton_orden_productos'),
            listado: ListadoProductos.ajustes,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('boton_agregar_producto'),
        onPressed: () => _abrir(),
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
          final c = ColoresApp.of(context);
          final tiposEnUso = [
            for (final t in tiposProducto.keys)
              if ([...productos, ...inactivos].any((p) => p.tipo == t)) t,
          ];
          // El tipo elegido solo filtra mientras sus chips se ven.
          final tipoActivo = tiposEnUso.length >= 2 ? _tipo : null;
          final visibles = ordenarProductos(
            productos,
            ref.watch(ordenProductosProvider(ListadoProductos.ajustes)),
          ).where((p) => _coincide(p, tipoActivo)).toList();
          final inactivosVisibles = inactivos
              .where((p) => _coincide(p, tipoActivo))
              .toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              TextField(
                key: const Key('campo_buscar_productos'),
                controller: _buscar,
                onChanged: (v) => setState(() => _busqueda = v),
                decoration: InputDecoration(
                  hintText: 'Buscar producto',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _busqueda.isEmpty
                      ? null
                      : IconButton(
                          key: const Key('borrar_busqueda_productos'),
                          tooltip: 'Borrar',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            _buscar.clear();
                            setState(() => _busqueda = '');
                          },
                        ),
                ),
              ),
              const SizedBox(height: 12),
              if (tiposEnUso.length >= 2) ...[
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          key: const Key('filtro_tipo_producto_todos'),
                          label: const Text('Todos'),
                          selected: _tipo == null,
                          onSelected: (_) => setState(() => _tipo = null),
                        ),
                      ),
                      for (final t in tiposEnUso)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            key: Key('filtro_tipo_producto_$t'),
                            label: Text(nombreTipo(t)),
                            selected: _tipo == t,
                            onSelected: (_) => setState(() => _tipo = t),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (visibles.isEmpty && inactivosVisibles.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Ningún producto coincide',
                    key: const Key('texto_sin_coincidencias'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: c.textoSecundario),
                  ),
                ),
              if (visibles.isNotEmpty)
                Card(
                  child: Column(
                    children: [
                      for (final (i, p) in visibles.indexed)
                        EntradaEscalonada(
                          indice: i,
                          child: ListTile(
                            key: Key('producto_item_${p.id}'),
                            leading: AvatarInicial(id: p.id, nombre: p.nombre),
                            title: Text(
                              p.nombre,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  if (detalleProducto(p) case final d?)
                                    Text(
                                      d,
                                      key: Key('detalle_producto_${p.id}'),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: c.textoSecundario,
                                      ),
                                    ),
                                  Monto(p.precio, tamano: 15),
                                  _margen(c, p, costos[p.id]),
                                ],
                              ),
                            ),
                            onTap: () => _abrir(producto: p),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  key: Key('boton_editar_${p.id}'),
                                  tooltip: 'Editar',
                                  icon: const Icon(Icons.edit_outlined),
                                  onPressed: () => _abrir(producto: p),
                                ),
                                IconButton(
                                  key: Key('boton_desactivar_${p.id}'),
                                  tooltip: 'Desactivar',
                                  icon: const Icon(
                                    Icons.visibility_off_outlined,
                                  ),
                                  onPressed: () => ref
                                      .read(productoRepositoryProvider)
                                      .desactivarProducto(p.id),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              if (inactivosVisibles.isNotEmpty) ...[
                const SizedBox(height: 24),
                const TituloSeccion('INACTIVOS'),
                Card(
                  child: Column(
                    children: [
                      for (final p in inactivosVisibles)
                        ListTile(
                          key: Key('producto_inactivo_${p.id}'),
                          leading: Opacity(
                            opacity: 0.5,
                            child: AvatarInicial(id: p.id, nombre: p.nombre),
                          ),
                          title: Text(
                            p.nombre,
                            style: TextStyle(color: c.textoSecundario),
                          ),
                          subtitle: Text(formatoMoneda(p.precio)),
                          trailing: TextButton(
                            key: Key('boton_reactivar_${p.id}'),
                            onPressed: () async {
                              final otro = await ref
                                  .read(productoRepositoryProvider)
                                  .reactivarProducto(p.id);
                              if (otro != null && context.mounted) {
                                avisar(
                                  context,
                                  'Se reactivó sin código: ese código ya es '
                                  'de $otro',
                                );
                              }
                            },
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
        error: (_, _) => const ErrorCarga(),
      ),
    );
  }

  Widget _margen(ColoresApp c, Producto p, int? costo) {
    final key = Key('margen_${p.id}');
    if (costo == null) {
      return Pildora(key: key, texto: 'sin costo', color: c.textoSecundario);
    }
    final m = p.precio - costo;
    return m >= 0
        ? Pildora(key: key, texto: 'gana ${formatoMoneda(m)}', color: c.entra)
        : Pildora(
            key: key,
            texto: 'pierde ${formatoMoneda(-m)}',
            color: c.sale,
          );
  }
}
