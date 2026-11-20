import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../providers/repository_providers.dart';
import '../../providers/sesion_provider.dart';
import '../../ui/boton_principal.dart';

/// Lo que pasó en la hoja "Editar usuario".
enum ResultadoEdicionUsuario { guardado, cambiarPin }

/// Texto del interruptor que convierte a un vendedor en super vendedor.
const textoPermisoCatalogo = 'Puede manejar productos, proveedores y pedidos';

/// Interruptor del permiso de catálogo, igual al crear y al editar.
class InterruptorPermisoCatalogo extends StatelessWidget {
  const InterruptorPermisoCatalogo({
    super.key,
    required this.valor,
    required this.onCambio,
  });

  final bool valor;
  final ValueChanged<bool> onCambio;

  @override
  Widget build(BuildContext context) => SwitchListTile(
    key: const Key('interruptor_maneja_catalogo'),
    contentPadding: EdgeInsets.zero,
    title: const Text(textoPermisoCatalogo),
    subtitle: const Text('No ve reportes ni ganancias'),
    value: valor,
    onChanged: onCambio,
  );
}

/// Nombre y permiso de catálogo de [usuario]; el PIN se cambia aparte.
class EditarUsuarioSheet extends ConsumerStatefulWidget {
  const EditarUsuarioSheet({super.key, required this.usuario});

  final Usuario usuario;

  @override
  ConsumerState<EditarUsuarioSheet> createState() => _EditarUsuarioSheetState();
}

class _EditarUsuarioSheetState extends ConsumerState<EditarUsuarioSheet> {
  late final _nombreController = TextEditingController(
    text: widget.usuario.nombre,
  );
  late bool _manejaCatalogo = widget.usuario.manejaCatalogo;
  String? _errorNombre;
  bool _guardando = false;

  @override
  void dispose() {
    _nombreController.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_guardando) return;
    final nombre = _nombreController.text.trim();
    if (nombre.isEmpty) {
      setState(() => _errorNombre = 'Escribe un nombre');
      return;
    }
    setState(() => _guardando = true);
    final repo = ref.read(usuarioRepositoryProvider);
    try {
      await repo.editarUsuario(
        widget.usuario.id,
        nombre: nombre,
        manejaCatalogo: _manejaCatalogo,
      );
      final actualizado = await repo.buscar(widget.usuario.id);
      if (actualizado != null) {
        ref.read(sesionProvider.notifier).refrescarUsuario(actualizado);
      }
      if (mounted) Navigator.of(context).pop(ResultadoEdicionUsuario.guardado);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('campo_nombre_editar'),
          controller: _nombreController,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: 'Nombre',
            errorText: _errorNombre,
          ),
        ),
        if (widget.usuario.rol == 'vendedor') ...[
          const SizedBox(height: 8),
          InterruptorPermisoCatalogo(
            valor: _manejaCatalogo,
            onCambio: (valor) => setState(() => _manejaCatalogo = valor),
          ),
        ],
        const SizedBox(height: 16),
        BotonPrincipal(
          key: const Key('boton_guardar_usuario'),
          texto: 'Guardar',
          onPressed: _guardando ? null : _guardar,
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          key: const Key('boton_cambiar_pin'),
          onPressed: () =>
              Navigator.of(context).pop(ResultadoEdicionUsuario.cambiarPin),
          icon: const Icon(Icons.lock_reset_rounded),
          label: const Text('Cambiar PIN'),
        ),
      ],
    );
  }
}
