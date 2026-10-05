import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../providers/repository_providers.dart';
import '../../util/formato_moneda.dart';

/// Edita nombre y precio de [producto]. Se cierra con `true` si guardó.
/// Cambiar el precio no afecta ventas ya registradas: cada venta guarda su
/// propio monto.
class EditarProductoDialog extends ConsumerStatefulWidget {
  const EditarProductoDialog({super.key, required this.producto});

  final Producto producto;

  @override
  ConsumerState<EditarProductoDialog> createState() =>
      _EditarProductoDialogState();
}

class _EditarProductoDialogState extends ConsumerState<EditarProductoDialog> {
  late final _nombreController =
      TextEditingController(text: widget.producto.nombre);
  late final _precioController =
      TextEditingController(text: widget.producto.precio.toString());
  String? _errorNombre;
  String? _errorPrecio;

  /// True mientras se guarda; un segundo toque no debe volver a hacer pop,
  /// porque cerraría también la pantalla de Productos.
  bool _guardando = false;

  @override
  void dispose() {
    _nombreController.dispose();
    _precioController.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_guardando) return;
    final nombre = _nombreController.text.trim();
    final precio = parsearMonto(_precioController.text);
    setState(() {
      _errorNombre = nombre.isEmpty ? 'Escribe un nombre' : null;
      _errorPrecio =
          (precio == null || precio <= 0) ? 'Escribe un precio válido' : null;
    });
    if (_errorNombre != null || _errorPrecio != null) return;

    setState(() => _guardando = true);
    try {
      await ref.read(productoRepositoryProvider).actualizarProducto(
            widget.producto.id,
            nombre: nombre,
            precio: precio,
          );
      if (mounted) Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar producto'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const Key('campo_editar_nombre'),
            controller: _nombreController,
            decoration:
                InputDecoration(labelText: 'Nombre', errorText: _errorNombre),
          ),
          TextField(
            key: const Key('campo_editar_precio'),
            controller: _precioController,
            decoration:
                InputDecoration(labelText: 'Precio', errorText: _errorPrecio),
            keyboardType: TextInputType.number,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const Key('boton_guardar_producto'),
          onPressed: _guardando ? null : _guardar,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
