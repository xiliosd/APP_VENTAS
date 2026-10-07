import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../providers/inventario_providers.dart';
import '../../providers/proveedores_providers.dart';
import '../../providers/repository_providers.dart';
import '../../providers/sesion_provider.dart';
import '../../repositories/producto_repository.dart';
import '../../ui/boton_principal.dart';
import '../../ui/colores_app.dart';
import '../../ui/hoja_inferior.dart';
import '../../util/formato_moneda.dart';
import '../inventario/hoja_ajuste_conteo.dart';

/// Un proveedor en edición dentro del formulario.
class _Fila {
  _Fila({
    required this.proveedorId,
    required this.nombre,
    required this.activo,
    required this.precioCompra,
    required this.preferido,
  });

  final int proveedorId;
  final String nombre;
  final bool activo;
  final int precioCompra;
  bool preferido;
}

/// Crea ([producto] null) o edita un producto con sus proveedores. Se cierra
/// con `true` si guardó.
class ProductoScreen extends ConsumerStatefulWidget {
  const ProductoScreen({super.key, this.producto});

  final Producto? producto;

  @override
  ConsumerState<ProductoScreen> createState() => _ProductoScreenState();
}

class _ProductoScreenState extends ConsumerState<ProductoScreen> {
  late final _nombre = TextEditingController(text: widget.producto?.nombre);
  late final _precio = TextEditingController(
    text: widget.producto?.precio.toString(),
  );
  final List<_Fila> _filas = [];
  late bool _controla = widget.producto?.controlaExistencias ?? false;
  late final bool _controlabaAlAbrir =
      widget.producto?.controlaExistencias ?? false;
  final _hayAhora = TextEditingController();
  late final _minimo = TextEditingController(
    text: '${widget.producto?.minimo ?? 0}',
  );
  String? _errorHay;
  String? _errorMinimo;
  String? _errorNombre;
  String? _errorPrecio;
  String? _error;
  bool _guardando = false;

  /// Id del producto nuevo ya creado en un intento anterior que falló después
  /// (al activar el control): reintentar lo actualiza en vez de duplicarlo.
  int? _productoIdGuardado;

  /// Al editar, true hasta que llegan los proveedores del producto: guardar o
  /// agregar antes reemplazaría la lista con una incompleta.
  late bool _cargando = widget.producto != null;

  @override
  void initState() {
    super.initState();
    final id = widget.producto?.id;
    if (id != null) _cargar(id);
  }

  Future<void> _cargar(int id) async {
    final vinculos = await ref
        .read(productoRepositoryProvider)
        .proveedoresDe(id);
    final proveedores = {
      for (final p in await ref.read(proveedorRepositoryProvider).todos())
        p.id: p,
    };
    if (!mounted) return;
    setState(() {
      _cargando = false;
      _filas.addAll([
        for (final v in vinculos)
          _Fila(
            proveedorId: v.proveedorId,
            nombre: proveedores[v.proveedorId]?.nombre ?? '',
            activo: proveedores[v.proveedorId]?.activo ?? false,
            precioCompra: v.precioCompra,
            preferido: v.preferido,
          ),
      ]);
    });
  }

  @override
  void dispose() {
    _nombre.dispose();
    _precio.dispose();
    _hayAhora.dispose();
    _minimo.dispose();
    super.dispose();
  }

  Future<void> _agregarProveedor() async {
    final elegido = await mostrarHojaInferior<_Fila>(
      context,
      titulo: 'Agregar proveedor',
      builder: (_) => _HojaAgregarProveedor(
        excluir: {for (final f in _filas) f.proveedorId},
      ),
    );
    if (elegido == null) return;
    setState(() {
      elegido.preferido = _filas.isEmpty;
      _filas.add(elegido);
    });
  }

  void _marcarPreferido(_Fila fila) => setState(() {
    for (final f in _filas) {
      f.preferido = identical(f, fila);
    }
  });

  void _quitar(_Fila fila) => setState(() {
    _filas.remove(fila);
    if (fila.preferido && _filas.isNotEmpty) _filas.first.preferido = true;
  });

  Future<void> _guardar() async {
    if (_guardando) return;
    final nombre = _nombre.text.trim();
    final precio = parsearMonto(_precio.text);
    final hay = int.tryParse(_hayAhora.text.trim());
    final minimo = int.tryParse(_minimo.text.trim());
    setState(() {
      _errorNombre = nombre.isEmpty ? 'Escribe un nombre' : null;
      _errorPrecio = (precio == null || precio <= 0)
          ? 'Escribe un precio válido'
          : null;
      _errorHay = _controla && !_controlabaAlAbrir && (hay == null || hay < 0)
          ? 'Escribe cuántas hay'
          : null;
      _errorMinimo = _controla && (minimo == null || minimo < 0)
          ? 'Escribe un mínimo válido'
          : null;
      _error = null;
    });
    if (_errorNombre != null ||
        _errorPrecio != null ||
        _errorHay != null ||
        _errorMinimo != null) {
      return;
    }
    setState(() => _guardando = true);
    try {
      final productoId = await ref
          .read(productoRepositoryProvider)
          .guardarProducto(
            id: _productoIdGuardado ?? widget.producto?.id,
            nombre: nombre,
            precio: precio!,
            proveedores: [
              for (final f in _filas)
                ProveedorDeProducto(
                  proveedorId: f.proveedorId,
                  precioCompra: f.precioCompra,
                  preferido: f.preferido,
                ),
            ],
          );
      _productoIdGuardado = productoId;
      final inventario = ref.read(inventarioRepositoryProvider);
      if (_controla && !_controlabaAlAbrir) {
        await inventario.activarControl(
          productoId,
          cantidad: hay!,
          minimo: minimo!,
          por: ref.read(sesionProvider).usuarioActivo!,
        );
      } else if (_controla) {
        await inventario.cambiarMinimo(productoId, minimo!);
      } else if (_controlabaAlAbrir) {
        await inventario.desactivarControl(productoId);
      }
      if (mounted) Navigator.of(context).pop(true);
    } on ArgumentError {
      if (mounted) {
        setState(() => _error = 'No se pudo guardar, revisa los proveedores');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudo guardar, intenta de nuevo');
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _cambiarControl(bool valor) async {
    if (!valor && _controlabaAlAbrir) {
      final confirmado = await showDialog<bool>(
        context: context,
        builder: (contexto) => AlertDialog(
          title: const Text('¿Dejar de controlar existencias?'),
          content: const Text('El historial se conserva.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(contexto, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              key: const Key('confirmar_dejar_de_controlar'),
              style: TextButton.styleFrom(foregroundColor: ColoresApp.sale),
              onPressed: () => Navigator.pop(contexto, true),
              child: const Text('Dejar de controlar'),
            ),
          ],
        ),
      );
      if (confirmado != true) return;
    }
    if (mounted) setState(() => _controla = valor);
  }

  Widget _resumen() {
    final precio = parsearMonto(_precio.text);
    final preferido = _filas.where((f) => f.preferido).firstOrNull;
    if (preferido == null) {
      return const Text(
        'Sin costo: agrega un proveedor para ver la ganancia',
        key: Key('texto_resumen_costo'),
        style: TextStyle(color: ColoresApp.textoSecundario),
      );
    }
    final costo = preferido.precioCompra;
    if (precio == null || precio <= 0) {
      return Text(
        'Costo ${formatoMoneda(costo)}',
        key: const Key('texto_resumen_costo'),
      );
    }
    final ganancia = precio - costo;
    if (ganancia < 0) {
      return const Text(
        'Este producto se vende con pérdida',
        key: Key('texto_resumen_costo'),
        style: TextStyle(color: ColoresApp.sale, fontWeight: FontWeight.w600),
      );
    }
    final porcentaje = (ganancia * 100 / precio).round();
    return Text(
      'Costo ${formatoMoneda(costo)} · Ganas ${formatoMoneda(ganancia)} '
      'por unidad ($porcentaje %)',
      key: const Key('texto_resumen_costo'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.producto == null ? 'Nuevo producto' : 'Editar producto',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            key: const Key('campo_nombre_producto'),
            controller: _nombre,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Nombre del producto',
              errorText: _errorNombre,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('campo_precio_producto'),
            controller: _precio,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Precio de venta',
              errorText: _errorPrecio,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Proveedores',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          for (final f in _filas)
            Row(
              key: Key('fila_proveedor_${f.proveedorId}'),
              children: [
                Expanded(
                  child: Text(
                    f.nombre,
                    style: TextStyle(
                      color: f.activo ? null : ColoresApp.textoSecundario,
                    ),
                  ),
                ),
                Text(formatoMoneda(f.precioCompra)),
                IconButton(
                  key: Key('preferido_${f.proveedorId}'),
                  tooltip: 'Preferido',
                  icon: Icon(
                    f.preferido
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: f.preferido ? ColoresApp.fiado : null,
                  ),
                  onPressed: () => _marcarPreferido(f),
                ),
                IconButton(
                  key: Key('quitar_proveedor_${f.proveedorId}'),
                  tooltip: 'Quitar',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => _quitar(f),
                ),
              ],
            ),
          TextButton.icon(
            key: const Key('boton_agregar_proveedor'),
            onPressed: _cargando ? null : _agregarProveedor,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Agregar proveedor'),
          ),
          const SizedBox(height: 12),
          _resumen(),
          const SizedBox(height: 24),
          const Text(
            'Existencias',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          SwitchListTile(
            key: const Key('interruptor_existencias'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Controlar existencias'),
            value: _controla,
            onChanged: _cargando ? null : _cambiarControl,
          ),
          if (_controla && _controlabaAlAbrir && widget.producto != null) ...[
            Text(
              'Hay ${ref.watch(existenciasProductoProvider(widget.producto!.id)).valueOrNull ?? 0} u',
              key: const Key('texto_existencias_producto'),
            ),
            TextButton(
              key: const Key('boton_ajustar_conteo_producto'),
              onPressed: () =>
                  mostrarHojaAjusteConteo(context, producto: widget.producto!),
              child: const Text('Ajustar conteo'),
            ),
          ],
          if (_controla && !_controlabaAlAbrir)
            TextField(
              key: const Key('campo_hay_ahora'),
              controller: _hayAhora,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Hay ahora',
                errorText: _errorHay,
              ),
            ),
          if (_controla)
            TextField(
              key: const Key('campo_minimo'),
              controller: _minimo,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Mínimo',
                errorText: _errorMinimo,
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: const TextStyle(color: ColoresApp.sale),
              ),
            ),
          const SizedBox(height: 24),
          BotonPrincipal(
            key: const Key('boton_guardar_producto'),
            texto: 'Guardar',
            onPressed: _guardando || _cargando ? null : _guardar,
          ),
        ],
      ),
    );
  }
}

/// Elige un proveedor activo que el producto no tenga (o crea uno nuevo) y
/// su precio de compra. Devuelve la fila a agregar.
class _HojaAgregarProveedor extends ConsumerStatefulWidget {
  const _HojaAgregarProveedor({required this.excluir});

  final Set<int> excluir;

  @override
  ConsumerState<_HojaAgregarProveedor> createState() =>
      _HojaAgregarProveedorState();
}

class _HojaAgregarProveedorState extends ConsumerState<_HojaAgregarProveedor> {
  final _nuevo = TextEditingController();
  final _precio = TextEditingController();
  Proveedor? _elegido;
  String? _error;
  bool _guardando = false;

  @override
  void dispose() {
    _nuevo.dispose();
    _precio.dispose();
    super.dispose();
  }

  Future<void> _agregar() async {
    if (_guardando) return;
    final precio = parsearMonto(_precio.text);
    final nombreNuevo = _nuevo.text.trim();
    if (_elegido == null && nombreNuevo.isEmpty) {
      setState(() => _error = 'Elige o escribe un proveedor');
      return;
    }
    if (precio == null || precio <= 0) {
      setState(() => _error = 'Escribe un precio válido');
      return;
    }
    setState(() => _guardando = true);
    try {
      var proveedor = _elegido;
      if (proveedor == null) {
        final repo = ref.read(proveedorRepositoryProvider);
        final id = await repo.crear(nombre: nombreNuevo);
        proveedor = (await repo.todos()).firstWhere((p) => p.id == id);
      }
      if (!mounted) return;
      Navigator.of(context).pop(
        _Fila(
          proveedorId: proveedor.id,
          nombre: proveedor.nombre,
          activo: true,
          precioCompra: precio,
          preferido: false,
        ),
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final disponibles =
        (ref.watch(proveedoresActivosProvider).valueOrNull ??
                const <Proveedor>[])
            .where((p) => !widget.excluir.contains(p.id))
            .toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (disponibles.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in disponibles)
                ChoiceChip(
                  key: Key('opcion_proveedor_${p.id}'),
                  label: Text(p.nombre),
                  selected: _elegido?.id == p.id,
                  onSelected: (_) => setState(() {
                    _elegido = p;
                    _nuevo.clear();
                    _error = null;
                  }),
                ),
            ],
          ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('campo_nuevo_proveedor'),
          controller: _nuevo,
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => setState(() => _elegido = null),
          decoration: const InputDecoration(labelText: 'Nuevo proveedor'),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('campo_precio_compra'),
          controller: _precio,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Precio de compra',
            errorText: _error,
          ),
        ),
        const SizedBox(height: 16),
        BotonPrincipal(
          key: const Key('boton_agregar_proveedor_producto'),
          texto: 'Agregar',
          onPressed: _guardando ? null : _agregar,
        ),
      ],
    );
  }
}
