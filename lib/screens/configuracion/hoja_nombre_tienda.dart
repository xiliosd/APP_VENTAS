import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/configuracion_providers.dart';
import '../../repositories/configuracion_repository.dart';
import '../../ui/avisos.dart';
import '../../ui/boton_principal.dart';
import '../../ui/hoja_inferior.dart';

/// Pide o cambia el nombre de la tienda. Con [obligatoria] no se puede
/// cerrar sin guardar.
Future<void> mostrarHojaNombreTienda(
  BuildContext context, {
  bool obligatoria = false,
}) async {
  final guardado = await mostrarHojaInferior<bool>(
    context,
    titulo: '¿Cómo se llama tu tienda?',
    descartable: !obligatoria,
    builder: (_) => _HojaNombreTienda(obligatoria: obligatoria),
  );
  if (guardado == true && context.mounted) avisar(context, 'Nombre guardado');
}

class _HojaNombreTienda extends ConsumerStatefulWidget {
  const _HojaNombreTienda({required this.obligatoria});

  final bool obligatoria;

  @override
  ConsumerState<_HojaNombreTienda> createState() => _HojaNombreTiendaState();
}

class _HojaNombreTiendaState extends ConsumerState<_HojaNombreTienda> {
  late final _controller = TextEditingController(
      text: ref.read(nombreTiendaProvider).valueOrNull ?? '');
  String? _error;
  bool _guardando = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_guardando) return;
    final error = errorNombreTienda(_controller.text);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() => _guardando = true);
    try {
      await ref
          .read(configuracionRepositoryProvider)
          .guardarNombreTienda(_controller.text);
      if (mounted) Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.obligatoria,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const Key('campo_nombre_tienda_hoja'),
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
                labelText: 'Nombre de la tienda', errorText: _error),
          ),
          const SizedBox(height: 16),
          BotonPrincipal(
            key: const Key('boton_guardar_nombre_tienda'),
            texto: 'Guardar',
            onPressed: _guardando ? null : _guardar,
          ),
        ],
      ),
    );
  }
}
