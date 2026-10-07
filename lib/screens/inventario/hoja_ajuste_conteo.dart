import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../providers/inventario_providers.dart';
import '../../providers/repository_providers.dart';
import '../../providers/sesion_provider.dart';
import '../../ui/avisos.dart';
import '../../ui/boton_principal.dart';
import '../../ui/hoja_inferior.dart';

/// Pide cuántas unidades hay de verdad y guarda el ajuste.
Future<void> mostrarHojaAjusteConteo(
  BuildContext context, {
  required Producto producto,
}) async {
  final guardado = await mostrarHojaInferior<bool>(
    context,
    titulo: 'Ajustar conteo · ${producto.nombre}',
    builder: (_) => _HojaAjusteConteo(producto: producto),
  );
  if (guardado == true && context.mounted) avisar(context, 'Conteo guardado');
}

class _HojaAjusteConteo extends ConsumerStatefulWidget {
  const _HojaAjusteConteo({required this.producto});

  final Producto producto;

  @override
  ConsumerState<_HojaAjusteConteo> createState() => _HojaAjusteConteoState();
}

class _HojaAjusteConteoState extends ConsumerState<_HojaAjusteConteo> {
  final _cantidad = TextEditingController();
  final _nota = TextEditingController();
  String? _error;
  bool _guardando = false;

  @override
  void dispose() {
    _cantidad.dispose();
    _nota.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_guardando) return;
    final cantidad = int.tryParse(_cantidad.text.trim());
    if (cantidad == null || cantidad < 0) {
      setState(() => _error = 'Escribe cuántas hay');
      return;
    }
    setState(() => _guardando = true);
    try {
      await ref.read(inventarioRepositoryProvider).ajustarConteo(
            widget.producto.id,
            cantidad: cantidad,
            nota: _nota.text,
            por: ref.read(sesionProvider).usuarioActivo!,
          );
      if (mounted) Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hay =
        ref.watch(existenciasProductoProvider(widget.producto.id)).valueOrNull;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hay != null)
          Text('Según la app hay $hay. ¿Cuántas hay?',
              key: const Key('texto_segun_app')),
        const SizedBox(height: 12),
        TextField(
          key: const Key('campo_conteo'),
          controller: _cantidad,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: 'Hay', errorText: _error),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('campo_nota_conteo'),
          controller: _nota,
          decoration: const InputDecoration(labelText: 'Nota'),
        ),
        const SizedBox(height: 16),
        BotonPrincipal(
          key: const Key('boton_guardar_conteo'),
          texto: 'Guardar',
          onPressed: _guardando ? null : _guardar,
        ),
      ],
    );
  }
}
