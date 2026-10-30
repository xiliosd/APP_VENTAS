import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../providers/productos_providers.dart';
import '../../providers/repository_providers.dart';
import '../../repositories/producto_repository.dart';
import '../../servicios/open_food_facts.dart';
import '../../ui/boton_principal.dart';
import '../../ui/colores_app.dart';
import '../../ui/hoja_inferior.dart';
import '../../util/formato_moneda.dart';
import '../configuracion/campos_detalle_producto.dart';

/// Crea un producto para [codigo] (autocompletado desde Open Food Facts) y
/// lo devuelve; null si se cerró sin guardar. [textoGuardar] cambia cuando
/// el producto no va a un ticket (p. ej. en el recorrido).
Future<Producto?> mostrarHojaProductoRapido(
  BuildContext context, {
  required String codigo,
  String textoGuardar = 'Guardar y agregar',
}) => mostrarHojaInferior<Producto>(
  context,
  titulo: 'Nuevo producto',
  builder: (_) =>
      _HojaProductoRapido(codigo: codigo, textoGuardar: textoGuardar),
);

class _HojaProductoRapido extends ConsumerStatefulWidget {
  const _HojaProductoRapido({required this.codigo, required this.textoGuardar});

  final String codigo;
  final String textoGuardar;

  @override
  ConsumerState<_HojaProductoRapido> createState() =>
      _HojaProductoRapidoState();
}

class _HojaProductoRapidoState extends ConsumerState<_HojaProductoRapido> {
  final _nombre = TextEditingController();
  final _precio = TextEditingController();
  final _marca = TextEditingController();
  final _tamano = TextEditingController();
  String? _envase;
  String? _tipo;
  String? _errorNombre;
  String? _errorPrecio;
  String? _error;
  bool _buscando = true;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _autocompletar();
  }

  @override
  void dispose() {
    for (final c in [_nombre, _precio, _marca, _tamano]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _autocompletar() async {
    final datos = await ref
        .read(consultaProductoProvider)
        .buscar(widget.codigo);
    if (!mounted) return;
    setState(() {
      _buscando = false;
      if (datos == null) return;
      void llenar(TextEditingController c, String? v) {
        if (c.text.trim().isEmpty && v != null) c.text = v;
      }

      llenar(_nombre, datos.nombre);
      llenar(_marca, datos.marca);
      llenar(_tamano, datos.tamano);
      _envase ??= datos.envase;
      _tipo ??= datos.tipo;
    });
  }

  Future<void> _guardar() async {
    if (_guardando) return;
    final nombre = _nombre.text.trim();
    final precio = parsearMonto(_precio.text);
    setState(() {
      _errorNombre = nombre.isEmpty ? 'Escribe un nombre' : null;
      _errorPrecio = precio == null || precio <= 0
          ? 'Escribe un precio válido'
          : null;
      _error = null;
    });
    if (_errorNombre != null || _errorPrecio != null) return;
    setState(() => _guardando = true);
    try {
      final repo = ref.read(productoRepositoryProvider);
      final id = await repo.guardarProducto(
        nombre: nombre,
        precio: precio!,
        detalles: DetallesProducto(
          codigoBarras: widget.codigo,
          marca: _marca.text,
          tamano: _tamano.text,
          envase: _envase,
          tipo: _tipo,
        ),
      );
      final producto = await repo.productoPorCodigo(widget.codigo);
      if (mounted) {
        Navigator.of(context).pop(producto?.id == id ? producto : null);
      }
    } on CodigoRepetido catch (e) {
      if (mounted) setState(() => _error = 'Ese código ya es de ${e.nombre}');
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
    final c = ColoresApp.of(context);
    return Column(
      key: const Key('hoja_producto_rapido'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Código ${widget.codigo}',
          style: TextStyle(color: c.textoSecundario),
        ),
        if (_buscando)
          Padding(
            key: const Key('texto_buscando_rapido'),
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Buscando…',
              style: TextStyle(color: c.textoSecundario),
            ),
          ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('campo_nombre_rapido'),
          controller: _nombre,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: 'Nombre',
            errorText: _errorNombre,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('campo_precio_rapido'),
          controller: _precio,
          autofocus: true,
          keyboardType: TextInputType.number,
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
          sufijo: '_rapido',
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_error!, style: TextStyle(color: c.sale)),
          ),
        const SizedBox(height: 16),
        BotonPrincipal(
          key: const Key('boton_guardar_producto_rapido'),
          texto: widget.textoGuardar,
          onPressed: _guardando ? null : _guardar,
        ),
      ],
    );
  }
}
