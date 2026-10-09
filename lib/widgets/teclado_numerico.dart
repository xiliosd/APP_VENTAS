import 'package:flutter/material.dart';

import '../ui/colores_app.dart';

/// Teclado del PIN: botones circulares grandes.
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
              return const SizedBox(width: 88, height: 80);
            }
            return Padding(
              padding: const EdgeInsets.all(8),
              child: SizedBox(
                width: 72,
                height: 72,
                child: ElevatedButton(
                  key: Key('tecla_$texto'),
                  onPressed: () => texto == '⌫' ? onBorrar() : onDigito(texto),
                  style: ElevatedButton.styleFrom(
                    shape: const CircleBorder(),
                    padding: EdgeInsets.zero,
                    foregroundColor: ColoresApp.of(context).texto,
                  ),
                  child: texto == '⌫'
                      ? const Icon(Icons.backspace_outlined,
                          semanticLabel: 'Borrar')
                      : Text(texto,
                          style: const TextStyle(
                              fontSize: 26, fontWeight: FontWeight.w600)),
                ),
              ),
            );
          }).toList(),
        );
      }).toList(),
    );
  }
}
