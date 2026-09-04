import 'package:flutter/material.dart';

class TecladoNumerico extends StatelessWidget {
  const TecladoNumerico({
    super.key,
    required this.onDigito,
    required this.onBorrar,
  });

  final void Function(String digito) onDigito;
  final VoidCallback onBorrar;

  static const _filas = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
    ['', '0', '⌫'],
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: _filas.map((fila) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: fila.map((texto) {
            if (texto.isEmpty) {
              return const SizedBox(width: 72, height: 72);
            }
            return Padding(
              padding: const EdgeInsets.all(4),
              child: SizedBox(
                width: 64,
                height: 64,
                child: ElevatedButton(
                  key: Key('tecla_$texto'),
                  onPressed: () => texto == '⌫' ? onBorrar() : onDigito(texto),
                  child: Text(texto, style: const TextStyle(fontSize: 22)),
                ),
              ),
            );
          }).toList(),
        );
      }).toList(),
    );
  }
}
