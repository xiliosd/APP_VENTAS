import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../providers/proveedores_providers.dart';
import '../../providers/repository_providers.dart';
import '../../providers/sesion_provider.dart';
import '../../repositories/inventario_repository.dart';
import '../../respaldo/respaldo_provider.dart';
import '../../ui/barra_accion_fija.dart';
import '../../ui/boton_cantidad.dart';
import '../../ui/boton_principal.dart';
import '../../ui/colores_app.dart';
import '../../ui/dialogo_cantidad.dart';
import '../../ui/hoja_inferior.dart';
import '../../ui/pildora.dart';
import '../../util/diferencia_pedido.dart';
import '../../util/fecha_util.dart';
import '../../util/formato_moneda.dart';
import '../../util/texto_util.dart';
import 'hoja_productos.dart';

/// Preferencia: ya se avisó que la mercancía se anota sola como gasto.
const _claveAvisoGasto = 'aviso_mercancia_gasto';

const _pedidoCerradoTexto = 'Este pedido ya se recibió o se anuló';

class _Linea {
  _Linea(this.producto, String precio, {this.pedido, this.precioEsperado})
    : precio = TextEditingController(text: precio);

  final Producto producto;
  int cantidad = 1;
  final TextEditingController precio;

  /// Cantidad pedida; null si no estaba en el pedido (o no hay pedido).
  final int? pedido;

  /// Precio que se esperaba pagar según el pedido.
  final int? precioEsperado;

  /// El usuario escribió el precio: ya no se reemplaza con la sugerencia.
  bool editado = false;

  int? get precioValido {
    final p = parsearMonto(precio.text);
    return p == null || p <= 0 ? null : p;
  }
}

/// Un producto con el que arranca Recibir mercancía (p. ej. desde el pedido
/// sugerido).
class LineaInicial {
  const LineaInicial({
    required this.producto,
    required this.cantidad,
    this.precio,
  });

  final Producto producto;
  final int cantidad;
  final int? precio;
}

/// Registra la mercancía que trajo un proveedor. Al guardar se cierra
/// devolviendo el total.
class RecibirMercanciaScreen extends ConsumerStatefulWidget {
  const RecibirMercanciaScreen({
    super.key,
    this.proveedorInicial,
    this.lineasIniciales = const [],
    this.pedidoId,
  });

  final Proveedor? proveedorInicial;

  /// Pedido por llegar contra el que se recibe.
  final int? pedidoId;

  /// Sus precios son sugerencias: elegir o cambiar de proveedor los reemplaza.
  final List<LineaInicial> lineasIniciales;

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
  String? _error;

  /// Pedido contra el que se recibe; puede elegirse después del proveedor.
  int? _pedidoId;
  int _totalPedido = 0;
  bool _cargandoPedido = false;

  /// Proveedor del pedido cargado; con pedido no se cambia.
  Proveedor? _proveedorPedido;

  /// El pedido ya se recibió o se anuló (en otro toque o pantalla).
  bool _pedidoCerrado = false;
  bool _pagadoDeCaja = true;

  @override
  void initState() {
    super.initState();
    _proveedor = widget.proveedorInicial;
    if (widget.pedidoId != null) _cargarPedido(widget.pedidoId!);
    for (final l in widget.lineasIniciales) {
      _lineas.add(
        _Linea(l.producto, l.precio?.toString() ?? '')
          ..cantidad = l.cantidad,
      );
    }
  }

  @override
  void dispose() {
    for (final l in _lineas) {
      l.precio.dispose();
    }
    _nota.dispose();
    super.dispose();
  }

  /// Reemplaza las líneas por las del pedido: cada una arranca con lo
  /// pedido, para que el caso normal sea solo confirmar.
  Future<void> _cargarPedido(int pedidoId) async {
    setState(() => _cargandoPedido = true);
    final detalle = await ref
        .read(pedidoRepositoryProvider)
        .detallePedido(pedidoId);
    if (!mounted) return;
    setState(() {
      for (final l in _lineas) {
        l.precio.dispose();
      }
      _lineas
        ..clear()
        ..addAll([
          for (final l in detalle.lineas)
            _Linea(
              l.producto,
              l.linea.precioEsperado?.toString() ?? '',
              pedido: l.linea.cantidad,
              precioEsperado: l.linea.precioEsperado,
            )..cantidad = l.linea.cantidad,
        ]);
      final proveedor = detalle.resumen.proveedor;
      _proveedor = proveedor.activo ? proveedor : null;
      _proveedorPedido = proveedor;
      _pedidoId = pedidoId;
      _pedidoCerrado = detalle.resumen.pedido.estado != EstadoPedido.porLlegar;
      if (_pedidoCerrado) _error = _pedidoCerradoTexto;
      _totalPedido = detalle.resumen.totalEstimado;
      _cargandoPedido = false;
    });
  }

  /// Sin pedido elegido, si [proveedor] tiene pedidos por llegar pregunta si
  /// llegó uno: así no queda por llegar para siempre.
  Future<void> _preguntarPedido(Proveedor proveedor) async {
    final pedidos = await ref
        .read(pedidoRepositoryProvider)
        .pedidosPorLlegar(proveedorId: proveedor.id);
    if (pedidos.isEmpty || !mounted) return;
    final elegido = await mostrarHojaInferior<int>(
      context,
      titulo: '¿Llegó alguno de estos pedidos?',
      builder: (contexto) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final r in pedidos)
            ListTile(
              key: Key('elegir_pedido_${r.pedido.id}'),
              leading: const Icon(Icons.schedule_rounded),
              title: Text('Pedido del ${fechaCorta(r.pedido.fecha)}'),
              subtitle: Text(
                '${plural(r.productos, 'producto', 'productos')} · '
                '${formatoMoneda(r.totalEstimado)}',
              ),
              onTap: () => Navigator.of(contexto).pop(r.pedido.id),
            ),
          TextButton(
            key: const Key('otra_mercancia'),
            onPressed: () => Navigator.of(contexto).pop(),
            child: const Text('No, es otra mercancía'),
          ),
        ],
      ),
    );
    if (elegido != null && mounted) await _cargarPedido(elegido);
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

  /// Elige el proveedor y vuelve a sugerir los precios que el usuario no ha
  /// escrito, para no guardar en este proveedor el precio de otro.
  Future<void> _elegirProveedor(Proveedor proveedor) async {
    setState(() {
      _proveedor = proveedor;
      _error = null;
    });
    for (final l in _lineas.where((l) => !l.editado).toList()) {
      final precio = await _precioSugerido(l.producto.id);
      if (!mounted || _proveedor?.id != proveedor.id) return;
      setState(() => l.precio.text = precio);
    }
    if (_pedidoId == null && mounted) await _preguntarPedido(proveedor);
  }

  Future<void> _agregarProducto() async {
    final producto = await mostrarHojaInferior<Producto>(
      context,
      titulo: 'Agregar producto',
      builder: (_) =>
          HojaProductos(excluir: {for (final l in _lineas) l.producto.id}),
    );
    if (producto == null) return;
    final precio = await _precioSugerido(producto.id);
    if (!mounted) return;
    setState(() => _lineas.add(_Linea(producto, precio)));
  }

  int get _total =>
      _lineas.fold(0, (s, l) => s + l.cantidad * (l.precioValido ?? 0));

  /// Lo que llegó: las líneas en 0 (no llegaron) no se guardan.
  Iterable<_Linea> get _llegaron => _lineas.where((l) => l.cantidad > 0);

  bool get _puedeGuardar =>
      !_guardando &&
      !_cargandoPedido &&
      !_pedidoCerrado &&
      _proveedor != null &&
      _llegaron.isNotEmpty &&
      _llegaron.every((l) => l.precioValido != null);

  Future<void> _guardar() async {
    if (!_puedeGuardar) return;
    setState(() => _guardando = true);
    final total = _total;
    var guardado = false;
    try {
      await ref
          .read(inventarioRepositoryProvider)
          .recibirMercancia(
            proveedorId: _proveedor!.id,
            lineas: [
              for (final l in _llegaron)
                LineaRecibida(
                  productoId: l.producto.id,
                  cantidad: l.cantidad,
                  precioCompra: l.precioValido!,
                ),
            ],
            nota: _nota.text,
            por: ref.read(sesionProvider).usuarioActivo!,
            pedidoId: _pedidoId,
            pagadoDeCaja: _pagadoDeCaja,
          );
      guardado = true;
    } on ArgumentError catch (e) {
      if (mounted) {
        final cerrado = e.message == 'El pedido ya no está por llegar';
        setState(() {
          _pedidoCerrado = cerrado;
          _error = cerrado
              ? _pedidoCerradoTexto
              : 'No se pudo guardar, intenta de nuevo';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudo guardar, intenta de nuevo');
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
    if (!guardado) return;
    // Ya se guardó: si el aviso falla no se puede ofrecer reintentar, porque
    // duplicaría la entrada y el gasto.
    try {
      if (_pagadoDeCaja) await _avisarGastoUnaVez();
    } catch (_) {}
    if (mounted) Navigator.of(context).pop(total);
  }

  Future<void> _avisarGastoUnaVez() async {
    final preferencias = ref.read(preferenciasProvider);
    if (preferencias.getBool(_claveAvisoGasto) ?? false) return;
    await preferencias.setBool(_claveAvisoGasto, true);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('La mercancía ya es un gasto'),
        content: const Text(
          'Ya no registres la mercancía como gasto a mano; se anota sola',
        ),
        actions: [
          TextButton(
            key: const Key('entendido_aviso_gasto'),
            onPressed: () => Navigator.pop(contexto),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Future<void> _anularPedido() async {
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
            _pedidoId!,
            por: ref.read(sesionProvider).usuarioActivo!,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo anular el pedido');
    }
  }

  Color _colorEstado(EstadoLineaPedido estado, ColoresApp c) =>
      switch (estado) {
        EstadoLineaPedido.completo => c.entra,
        EstadoLineaPedido.noLlego => c.sale,
        EstadoLineaPedido.extra => c.primario,
        EstadoLineaPedido.faltan || EstadoLineaPedido.deMas => c.fiado,
      };

  /// "1 completo · 1 incompleto · …", sin las partes en cero.
  String get _conteoDiferencias {
    final estados = [
      for (final l in _lineas)
        estadoLineaPedido(pedido: l.pedido, llego: l.cantidad),
    ];
    int cuantos(EstadoLineaPedido e) => estados.where((x) => x == e).length;
    final precios = _lineas
        .where(
          (l) =>
              l.cantidad > 0 &&
              l.precioEsperado != null &&
              l.precioValido != null &&
              l.precioValido != l.precioEsperado,
        )
        .length;
    return [
      (cuantos(EstadoLineaPedido.completo), 'completo', 'completos'),
      (cuantos(EstadoLineaPedido.faltan), 'incompleto', 'incompletos'),
      (cuantos(EstadoLineaPedido.noLlego), 'no llegó', 'no llegaron'),
      (cuantos(EstadoLineaPedido.deMas), 'de más', 'de más'),
      (cuantos(EstadoLineaPedido.extra), 'extra', 'extras'),
      (precios, 'precio cambiado', 'precios cambiados'),
    ].where((x) => x.$1 > 0).map((x) => plural(x.$1, x.$2, x.$3)).join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final c = ColoresApp.of(context);
    final conPedido = _pedidoId != null;
    final proveedores =
        ref.watch(proveedoresActivosProvider).valueOrNull ??
        const <Proveedor>[];
    return Scaffold(
      appBar: AppBar(title: const Text('Recibir mercancía')),
      bottomNavigationBar: BarraAccionFija(
        // El error va junto al botón para que se vea aunque la lista sea larga.
        total: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  _error!,
                  key: const Key('error_recibir'),
                  style: TextStyle(color: ColoresApp.of(context).sale),
                ),
              ),
            Text(
              'Total ${formatoMoneda(_total)}',
              key: const Key('total_recibir'),
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        boton: BotonPrincipal(
          key: const Key('boton_guardar_recibir'),
          texto: 'Guardar',
          onPressed: _puedeGuardar ? _guardar : null,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Proveedor',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          // Con pedido el proveedor es el del pedido: cambiarlo dejaría la
          // entrada sin poder guardarse.
          if (conPedido)
            Column(
              key: const Key('proveedor_fijo_recibir'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _proveedorPedido?.nombre ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (_proveedorPedido != null && !_proveedorPedido!.activo)
                  Text(
                    'Proveedor inactivo: actívalo para recibir',
                    style: TextStyle(color: c.sale),
                  ),
              ],
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in proveedores)
                  ChoiceChip(
                    key: Key('opcion_proveedor_recibir_${p.id}'),
                    label: Text(p.nombre),
                    selected: _proveedor?.id == p.id,
                    onSelected: (_) => _elegirProveedor(p),
                  ),
              ],
            ),
          const SizedBox(height: 16),
          if (_cargandoPedido)
            const Center(child: CircularProgressIndicator()),
          if (conPedido) ...[
            Card(
              key: const Key('resumen_recepcion'),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pedido ${formatoMoneda(_totalPedido)} · '
                      'Llegó ${formatoMoneda(_total)}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      _conteoDiferencias,
                      style: TextStyle(color: c.textoSecundario),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          for (final l in _lineas)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
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
                        // Lo pedido no se quita: se deja en 0 si no llegó.
                        if (l.pedido == null)
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
                    if (conPedido)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              l.pedido == null
                                  ? 'no se pidió · llegó ${l.cantidad}'
                                  : 'pedido ${l.pedido} · llegó ${l.cantidad}',
                              style: TextStyle(color: c.textoSecundario),
                            ),
                            Builder(
                              builder: (_) {
                                final estado = estadoLineaPedido(
                                  pedido: l.pedido,
                                  llego: l.cantidad,
                                );
                                return Pildora(
                                  key: Key('estado_recibir_${l.producto.id}'),
                                  texto: textoEstadoLinea(
                                    estado,
                                    pedido: l.pedido,
                                    llego: l.cantidad,
                                  ),
                                  color: _colorEstado(estado, c),
                                );
                              },
                            ),
                            if (l.cantidad > 0 &&
                                l.precioEsperado != null &&
                                l.precioValido != null &&
                                l.precioValido != l.precioEsperado)
                              Text(
                                '${formatoMoneda(l.precioEsperado!)} → '
                                '${formatoMoneda(l.precioValido!)}',
                                key: Key('precio_cambiado_${l.producto.id}'),
                                style: TextStyle(
                                  color: c.fiado,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ),
                    Row(
                      children: [
                        BotonCantidad(
                          key: Key('restar_recibir_${l.producto.id}'),
                          icono: Icons.remove_rounded,
                          tooltip: 'Restar',
                          onPressed: l.cantidad > (l.pedido == null ? 1 : 0)
                              ? () => setState(() => l.cantidad--)
                              : null,
                        ),
                        InkWell(
                          onTap: () async {
                            final n = await pedirCantidad(
                              context,
                              actual: l.cantidad,
                              minimo: l.pedido == null ? 1 : 0,
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
                              key: Key('cantidad_recibir_${l.producto.id}'),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        BotonCantidad(
                          key: Key('sumar_recibir_${l.producto.id}'),
                          icono: Icons.add_rounded,
                          tooltip: 'Sumar',
                          onPressed: () => setState(() => l.cantidad++),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            key: Key('precio_recibir_${l.producto.id}'),
                            controller: l.precio,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() => l.editado = true),
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
                      style: TextStyle(color: ColoresApp.of(context).textoSecundario),
                    ),
                  ],
                ),
              ),
            ),
          TextButton.icon(
            key: const Key('boton_agregar_producto_recibir'),
            // Sin proveedor no hay precio que sugerir: se elige primero.
            onPressed: _proveedor == null ? null : _agregarProducto,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Agregar producto'),
          ),
          SwitchListTile(
            key: const Key('interruptor_caja'),
            contentPadding: EdgeInsets.zero,
            value: _pagadoDeCaja,
            onChanged: (v) => setState(() => _pagadoDeCaja = v),
            title: const Text('Lo pagué de la caja (efectivo)'),
            subtitle: Text(
              _pagadoDeCaja
                  ? 'Se registra gasto Mercancía · '
                        '${_proveedor?.nombre ?? '…'} por ${formatoMoneda(_total)}'
                  : 'No se registra gasto',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('campo_nota_recibir'),
            controller: _nota,
            decoration: const InputDecoration(labelText: 'Nota'),
          ),
          if (conPedido &&
              _llegaron.isEmpty &&
              !_cargandoPedido &&
              !_pedidoCerrado) ...[
            const SizedBox(height: 24),
            Text(
              'No llegó nada de este pedido',
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textoSecundario),
            ),
            const SizedBox(height: 8),
            BotonPrincipal(
              key: const Key('boton_anular_pedido_recibir'),
              texto: 'Anular pedido',
              variante: VarianteBoton.peligro,
              onPressed: _anularPedido,
            ),
          ],
        ],
      ),
    );
  }
}
