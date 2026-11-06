import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../providers/repository_providers.dart';
import '../../sincronizacion/sincronizacion_provider.dart';
import '../../util/pin_hash.dart';
import 'usuarios_screen.dart' show mensajeErrorPin;

/// Pide un PIN nuevo para [usuario]. Se cierra con `true` si lo guardó.
class ResetearPinDialog extends ConsumerStatefulWidget {
  const ResetearPinDialog({
    super.key,
    required this.usuario,
    this.activar = false,
  });

  final Usuario usuario;

  /// Para volver a dejar entrar a un vendedor desactivado: con un PIN nuevo,
  /// porque el viejo pudo quedar en manos de otro.
  final bool activar;

  @override
  ConsumerState<ResetearPinDialog> createState() => _ResetearPinDialogState();
}

class _ResetearPinDialogState extends ConsumerState<ResetearPinDialog> {
  final _pinController = TextEditingController();
  String? _error;

  /// True mientras se guarda; un segundo toque no debe volver a hacer pop,
  /// porque cerraría también la pantalla de Usuarios.
  bool _guardando = false;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_guardando) return;
    final pin = _pinController.text.trim();
    if (!esPinValido(pin)) {
      setState(() => _error = 'El PIN debe tener 4 dígitos');
      return;
    }
    setState(() => _guardando = true);
    try {
      final repo = ref.read(usuarioRepositoryProvider);
      final sincronizacion = ref.read(sincronizacionProvider.notifier);
      final usuario = await repo.buscar(widget.usuario.id) ?? widget.usuario;
      // En la tienda compartida el PIN nuevo debe llegar a la nube primero:
      // la versión siguiente hace que los otros celulares olviden el viejo.
      if (await sincronizacion.esCompartida()) {
        try {
          await sincronizacion.guardarPinEnTienda(
            idGlobal: usuario.idGlobal,
            pin: pin,
            version: usuario.versionPin + 1,
          );
        } catch (error) {
          if (mounted) setState(() => _error = mensajeErrorPin(error));
          return;
        }
      }
      await repo.resetearPin(usuario.id, pin);
      if (widget.activar) await repo.activar(usuario.id);
      if (mounted) Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.activar
            ? 'Activar a ${widget.usuario.nombre} con un PIN nuevo'
            : 'Resetear PIN de ${widget.usuario.nombre}',
      ),
      content: TextField(
        key: const Key('campo_nuevo_pin'),
        controller: _pinController,
        decoration: InputDecoration(
          labelText: 'Nuevo PIN de 4 dígitos',
          errorText: _error,
          errorMaxLines: 3,
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
          onPressed: _guardando ? null : _guardar,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
