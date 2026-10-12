import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../providers/inventario_providers.dart';
import '../../providers/productos_providers.dart';
import '../../providers/proveedores_providers.dart';
import '../../providers/repository_providers.dart';
import '../../providers/sesion_provider.dart';
import '../../repositories/catalogo_repository.dart';
import '../../repositories/producto_repository.dart';
import '../../servicios/lector_codigo.dart';
import '../../servicios/open_food_facts.dart';
import '../../ui/avisos.dart';
import '../../ui/avatar_inicial.dart';
import '../../ui/boton_principal.dart';
import '../../ui/colores_app.dart';
import '../../ui/hoja_inferior.dart';
import '../../ui/monto.dart';
import '../../ui/titulo_seccion.dart';
import '../../util/formato_moneda.dart';
import '../../util/texto_util.dart';
import '../inventario/hoja_ajuste_conteo.dart';
import 'campos_detalle_producto.dart';

/// Un proveedor en edición dentro del formulario.
class _Fila {
  _Fila({
    required this.proveedorId,
    required this.nombre,
    required this.activo,
    required this.precioCompra,
    required this.preferido,
  });

  /// Null = proveedor nuevo, se crea al guardar el producto.
  final int? proveedorId;
  final String nombre;
  final bool activo;
  int precioCompra;
  bool preferido;

  /// Identifica la fila en las claves y al excluir repetidos.
  String get clave =>
      proveedorId?.toString() ?? 'nuevo_${claveNombre(nombre)}';
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
  late final _pedirHasta = TextEditingController(
    text: widget.producto?.pedirHasta?.toString() ?? '',
  );
  String? _errorPedirHasta;
  String? _errorHay;
  String? _errorMinimo;
  String? _errorNombre;
  String? _errorPrecio;
  String? _error;
  bool _guardando = false;
  late final _codigo =
      TextEditingController(text: widget.producto?.codigoBarras ?? '');
  late final _marca = TextEditingController(text: widget.producto?.marca ?? '');
  late final _tamano =
      TextEditingController(text: widget.producto?.tamano ?? '');
  late String? _envase = widget.producto?.envase;
  late String? _tipo = widget.producto?.tipo;
  String? _errorCodigo;
  bool _buscando = false;

  /// Al editar, true hasta que llegan los proveedores del producto: guardar o
  /// agregar antes reemplazaría la lista con una incompleta.
  late bool _cargando = widget.producto != null;

  @override
  void initState() {
    super.initState();
    final id = widget.producto?.id;
    if (id != null) _cargar(id);
    // La vista previa muestra "Marca · Tamaño" mientras se escribe.
    _marca.addListener(_refrescar);
    _tamano.addListener(_refrescar);
  }

  void _refrescar() {
    if (mounted) setState(() {});
  }

  Future<void> _escanear() async {
    final codigo = await ref.read(lectorCodigoProvider).leer(context);
    if (codigo == null || !mounted) return;
    setState(() {
      _codigo.text = codigo;
      _errorCodigo = null;
    });
    await _autocompletar(codigo);
  }

  /// Llena desde Open Food Facts solo los campos que sigan vacíos.
  Future<void> _autocompletar(String codigo) async {
    if (widget.producto != null && _nombre.text.trim().isNotEmpty) return;
    setState(() => _buscando = true);
    final datos = await ref.read(consultaProductoProvider).buscar(codigo);
    if (!mounted) return;
    setState(() {
      _buscando = false;
      if (datos == null) return;
      void llenar(TextEditingController c, String? valor) {
        if (c.text.trim().isEmpty && valor != null) c.text = valor;
      }

      llenar(_nombre, datos.nombre);
      llenar(_marca, datos.marca);
      llenar(_tamano, datos.tamano);
      _envase ??= datos.envase;
      _tipo ??= datos.tipo;
    });
    if (datos == null && mounted) {
      avisar(context, 'No lo encontramos, llénalo a mano');
    }
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
    _pedirHasta.dispose();
    _codigo.dispose();
    _marca.dispose();
    _tamano.dispose();
    super.dispose();
  }

  Future<void> _agregarProveedor() async {
    final elegido = await mostrarHojaInferior<_Fila>(
      context,
      titulo: 'Agregar proveedor',
      builder: (_) => _HojaAgregarProveedor(
        excluir: {
          for (final f in _filas)
            if (f.proveedorId != null) f.proveedorId!,
        },
        excluirNombres: {for (final f in _filas) claveNombre(f.nombre)},
      ),
    );
    if (elegido == null) return;
    setState(() {
      elegido.preferido = _filas.isEmpty;
      _filas.add(elegido);
    });
  }

  Future<void> _editarPrecio(_Fila fila) async {
    final precio = await mostrarHojaInferior<int>(
      context,
      titulo: fila.nombre,
      builder: (_) => _HojaPrecioCompra(precio: fila.precioCompra),
    );
    if (precio != null) setState(() => fila.precioCompra = precio);
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
    final textoPedirHasta = _pedirHasta.text.trim();
    final pedirHasta = textoPedirHasta.isEmpty
        ? null
        : int.tryParse(textoPedirHasta);
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
      _errorPedirHasta = !_controla || textoPedirHasta.isEmpty
          ? null
          : pedirHasta == null || pedirHasta < 0
          ? 'Escribe un número válido'
          : minimo != null && pedirHasta < minimo
          ? 'Debe ser mayor o igual que el mínimo'
          : null;
      _error = null;
      _errorCodigo = null;
    });
    if (_errorNombre != null ||
        _errorPrecio != null ||
        _errorHay != null ||
        _errorMinimo != null ||
        _errorPedirHasta != null) {
      return;
    }
    setState(() => _guardando = true);
    try {
      await ref.read(catalogoRepositoryProvider).guardarProductoCompleto(
            id: widget.producto?.id,
            nombre: nombre,
            precio: precio!,
            proveedores: [
              for (final f in _filas)
                ProveedorEnFormulario(
                  proveedorId: f.proveedorId,
                  nombre: f.nombre,
                  precioCompra: f.precioCompra,
                  preferido: f.preferido,
                ),
            ],
            control: _controla
                ? ControlEnFormulario(
                    hayAhora: hay,
                    minimo: minimo!,
                    pedirHasta: pedirHasta,
                  )
                : null,
            controlabaAntes: _controlabaAlAbrir,
            detalles: DetallesProducto(
              codigoBarras: _codigo.text,
              marca: _marca.text,
              tamano: _tamano.text,
              envase: _envase,
              tipo: _tipo,
            ),
            por: ref.read(sesionProvider).usuarioActivo!,
          );
      if (mounted) Navigator.of(context).pop(true);
    } on CodigoRepetido catch (e) {
      if (mounted) {
        setState(() {
          _errorCodigo = 'Ese código ya es de ${e.nombre}';
          // Junto a Guardar, porque el campo del código queda arriba.
          _error = 'Revisa el código de barras: ya es de ${e.nombre}';
        });
      }
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
            FilledButton(
              key: const Key('confirmar_dejar_de_controlar'),
              style: FilledButton.styleFrom(
                backgroundColor: ColoresApp.of(context).sale,
                foregroundColor: ColoresApp.of(context).sobreSale,
              ),
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
      return Text(
        'Sin costo: agrega un proveedor para ver la ganancia',
        key: Key('texto_resumen_costo'),
        style: TextStyle(color: ColoresApp.of(context).textoSecundario),
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
      return Text(
        'Este producto se vende con pérdida',
        key: Key('texto_resumen_costo'),
        style: TextStyle(color: ColoresApp.of(context).sale, fontWeight: FontWeight.w600),
      );
    }
    final porcentaje = (ganancia * 100 / precio).round();
    return Text(
      'Costo ${formatoMoneda(costo)} · Ganas ${formatoMoneda(ganancia)} '
      'por unidad ($porcentaje %)',
      key: const Key('texto_resumen_costo'),
    );
  }

  Widget _tarjeta(String titulo, List<Widget> hijos) => Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TituloSeccion(titulo),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: hijos,
                ),
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.producto == null ? 'Nuevo producto' : 'Editar producto',
        ),
      ),
      body: SingleChildScrollView(
        // Abajo queda espacio para que un aviso no tape Guardar.
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            key: const Key('vista_previa_producto'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  AvatarInicial(
                    id: widget.producto?.id ?? 0,
                    nombre: _nombre.text,
                    radio: 26,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _nombre.text.trim().isEmpty
                              ? 'Sin nombre'
                              : _nombre.text.trim(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                        if ([_marca.text.trim(), _tamano.text.trim()]
                            .where((t) => t.isNotEmpty)
                            .join(' · ')
                            case final detalle when detalle.isNotEmpty)
                          Text(
                            detalle,
                            key: const Key('detalle_vista_previa'),
                            style: TextStyle(
                                fontSize: 13,
                                color: ColoresApp.of(context).textoSecundario),
                          ),
                        const SizedBox(height: 4),
                        Monto(parsearMonto(_precio.text) ?? 0,
                            tamano: 20, tono: TonoMonto.entra),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          _tarjeta('DATOS', [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('campo_codigo_producto'),
                    controller: _codigo,
                    keyboardType: TextInputType.number,
                    onSubmitted: (t) {
                      if (t.trim().isNotEmpty) _autocompletar(t.trim());
                    },
                    decoration: InputDecoration(
                      labelText: 'Código de barras',
                      errorText: _errorCodigo,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  key: const Key('boton_escanear_producto'),
                  tooltip: 'Escanear',
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  onPressed: _escanear,
                ),
              ],
            ),
            if (_buscando)
              Padding(
                key: const Key('texto_buscando_producto'),
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Buscando…',
                      style: TextStyle(
                          color: ColoresApp.of(context).textoSecundario),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('campo_nombre_producto'),
              controller: _nombre,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
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
            const SizedBox(height: 12),
            CamposDetalleProducto(
              marca: _marca,
              tamano: _tamano,
              envase: _envase,
              tipo: _tipo,
              onEnvase: (v) => setState(() => _envase = v),
              onTipo: (v) => setState(() => _tipo = v),
              marcas: ref.watch(marcasUsadasProvider).valueOrNull ?? const [],
            ),
          ]),
          _tarjeta('PROVEEDORES Y COSTO', [
            for (final f in _filas)
              Row(
                key: Key('fila_proveedor_${f.clave}'),
                children: [
                  Expanded(
                    child: InkWell(
                      key: Key('editar_proveedor_${f.clave}'),
                      onTap: () => _editarPrecio(f),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                f.nombre,
                                style: TextStyle(
                                  color: f.activo
                                      ? null
                                      : ColoresApp.of(context).textoSecundario,
                                ),
                              ),
                            ),
                            Text(formatoMoneda(f.precioCompra)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    key: Key('preferido_${f.clave}'),
                    tooltip: 'Preferido',
                    icon: Icon(
                      f.preferido
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: f.preferido ? ColoresApp.of(context).fiado : null,
                    ),
                    onPressed: () => _marcarPreferido(f),
                  ),
                  IconButton(
                    key: Key('quitar_proveedor_${f.clave}'),
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
          ]),
          _tarjeta('EXISTENCIAS', [
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
            if (_controla && !_controlabaAlAbrir) const SizedBox(height: 12),
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
            if (_controla) const SizedBox(height: 12),
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
            if (_controla) const SizedBox(height: 12),
            if (_controla)
              TextField(
                key: const Key('campo_pedir_hasta'),
                controller: _pedirHasta,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Pedir hasta',
                  errorText: _errorPedirHasta,
                ),
              ),
          ]),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: TextStyle(color: ColoresApp.of(context).sale),
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
      ),
    );
  }
}

/// Elige un proveedor activo que el producto no tenga (o crea uno nuevo) y
/// su precio de compra. Devuelve la fila a agregar.
class _HojaAgregarProveedor extends ConsumerStatefulWidget {
  const _HojaAgregarProveedor({
    required this.excluir,
    required this.excluirNombres,
  });

  final Set<int> excluir;

  /// [claveNombre] de los proveedores que ya tiene el producto.
  final Set<String> excluirNombres;

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
        proveedor = await ref
            .read(proveedorRepositoryProvider)
            .buscarPorNombre(nombreNuevo);
        final repetido = proveedor == null
            ? widget.excluirNombres.contains(claveNombre(nombreNuevo))
            : widget.excluir.contains(proveedor.id);
        if (repetido) {
          if (mounted) {
            setState(() => _error = 'Ese proveedor ya está en el producto');
          }
          return;
        }
        if (proveedor != null && !proveedor.activo) {
          final nombre = proveedor.nombre;
          if (mounted) {
            setState(() => _error =
                '$nombre está desactivado: reactívalo en Proveedores');
          }
          return;
        }
      }
      if (!mounted) return;
      Navigator.of(context).pop(
        _Fila(
          proveedorId: proveedor?.id,
          nombre: proveedor?.nombre ?? nombreNuevo,
          activo: proveedor?.activo ?? true,
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

/// Cambia el precio de compra de un proveedor ya agregado. Devuelve el precio.
class _HojaPrecioCompra extends StatefulWidget {
  const _HojaPrecioCompra({required this.precio});

  final int precio;

  @override
  State<_HojaPrecioCompra> createState() => _HojaPrecioCompraState();
}

class _HojaPrecioCompraState extends State<_HojaPrecioCompra> {
  late final _precio = TextEditingController(text: '${widget.precio}');
  String? _error;

  @override
  void dispose() {
    _precio.dispose();
    super.dispose();
  }

  void _guardar() {
    final precio = parsearMonto(_precio.text);
    if (precio == null || precio <= 0) {
      setState(() => _error = 'Escribe un precio válido');
      return;
    }
    Navigator.of(context).pop(precio);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('campo_precio_compra'),
          controller: _precio,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Precio de compra',
            errorText: _error,
          ),
        ),
        const SizedBox(height: 16),
        BotonPrincipal(
          key: const Key('boton_guardar_precio_compra'),
          texto: 'Guardar',
          onPressed: _guardar,
        ),
      ],
    );
  }
}
