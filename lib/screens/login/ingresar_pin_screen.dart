import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../providers/sesion_provider.dart';
import '../../widgets/teclado_numerico.dart';

class IngresarPinScreen extends ConsumerStatefulWidget {
  const IngresarPinScreen({super.key, required this.usuario});

  final Usuario usuario;

  @override
  ConsumerState<IngresarPinScreen> createState() => _IngresarPinScreenState();
}

class _IngresarPinScreenState extends ConsumerState<IngresarPinScreen> {
  String _pin = '';
  String? _error;

  Future<void> _validar() async {
    final ok = await ref
        .read(sesionProvider.notifier)
        .iniciarSesion(widget.usuario.id, _pin);
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _error = 'PIN incorrecto';
        _pin = '';
      });
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  void _presionarDigito(String digito) {
    if (_pin.length >= 4) return;
    setState(() {
      _pin += digito;
      _error = null;
    });
    if (_pin.length == 4) _validar();
  }

  void _borrar() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Hola, ${widget.usuario.nombre}')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${'●' * _pin.length}${'○' * (4 - _pin.length)}',
              style: const TextStyle(fontSize: 32, letterSpacing: 8),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            const SizedBox(height: 24),
            TecladoNumerico(onDigito: _presionarDigito, onBorrar: _borrar),
          ],
        ),
      ),
    );
  }
}
