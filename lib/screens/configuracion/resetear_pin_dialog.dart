import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../providers/repository_providers.dart';
import '../../util/pin_hash.dart';

/// Pide un PIN nuevo para [usuario]. Se cierra con `true` si lo guardó.
class ResetearPinDialog extends ConsumerStatefulWidget {
  const ResetearPinDialog({super.key, required this.usuario});

  final Usuario usuario;

  @override
  ConsumerState<ResetearPinDialog> createState() => _ResetearPinDialogState();
}

class _ResetearPinDialogState extends ConsumerState<ResetearPinDialog> {
  final _pinController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final pin = _pinController.text.trim();
    if (!esPinValido(pin)) {
      setState(() => _error = 'El PIN debe tener 4 dígitos');
      return;
    }
    await ref
        .read(usuarioRepositoryProvider)
        .resetearPin(widget.usuario.id, pin);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Resetear PIN de ${widget.usuario.nombre}'),
      content: TextField(
        key: const Key('campo_nuevo_pin'),
        controller: _pinController,
        decoration: InputDecoration(
          labelText: 'Nuevo PIN de 4 dígitos',
          errorText: _error,
        ),
        keyboardType: TextInputType.number,
        obscureText: true,
        maxLength: 4,
        autofocus: true,
      ),
      actions: [
        TextButton(
          key: const Key('boton_cancelar_pin'),
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const Key('boton_guardar_pin'),
          onPressed: _guardar,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
