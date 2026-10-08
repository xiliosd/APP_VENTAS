import 'package:flutter/material.dart';

/// Pide una cantidad entera ≥ [minimo], empezando en [actual]. Null si se
/// cancela.
Future<int?> pedirCantidad(
  BuildContext context, {
  required int actual,
  int minimo = 0,
}) =>
    showDialog<int>(
      context: context,
      builder: (_) => _DialogoCantidad(actual: actual, minimo: minimo),
    );

class _DialogoCantidad extends StatefulWidget {
  const _DialogoCantidad({required this.actual, required this.minimo});

  final int actual;
  final int minimo;

  @override
  State<_DialogoCantidad> createState() => _DialogoCantidadState();
}

class _DialogoCantidadState extends State<_DialogoCantidad> {
  late final _campo = TextEditingController(text: '${widget.actual}');
  String? _error;

  @override
  void dispose() {
    _campo.dispose();
    super.dispose();
  }

  void _aceptar() {
    final n = int.tryParse(_campo.text.trim());
    if (n == null || n < widget.minimo) {
      setState(() => _error = 'Escribe un número desde ${widget.minimo}');
      return;
    }
    Navigator.of(context).pop(n);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cantidad'),
      content: TextField(
        key: const Key('campo_cantidad'),
        controller: _campo,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(errorText: _error),
        onSubmitted: (_) => _aceptar(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        TextButton(
          key: const Key('aceptar_cantidad'),
          onPressed: _aceptar,
          child: const Text('Aceptar'),
        ),
      ],
    );
  }
}
