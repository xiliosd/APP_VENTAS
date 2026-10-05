import 'package:flutter/material.dart';

import 'colores_app.dart';

/// Tope de 9 dígitos ($999.999.999).
const montoMaximo = 999999999;

/// Aplica una tecla del [TecladoMonto] a un monto entero.
int aplicarTecla(int actual, String tecla) {
  if (tecla == 'borrar') return actual ~/ 10;
  final siguiente =
      tecla == '000' ? actual * 1000 : actual * 10 + int.parse(tecla);
  return siguiente > montoMaximo ? actual : siguiente;
}

/// Teclado numérico grande para montos: 1–9, 000, 0 y borrar.
class TecladoMonto extends StatelessWidget {
  const TecladoMonto({super.key, required this.onTecla});

  final ValueChanged<String> onTecla;

  static const _filas = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
    ['000', '0', 'borrar'],
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final fila in _filas)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                for (final tecla in fila)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: SizedBox(
                        height: 56,
                        child: ElevatedButton(
                          key: Key('tecla_monto_$tecla'),
                          onPressed: () => onTecla(tecla),
                          style: ElevatedButton.styleFrom(
                            foregroundColor: ColoresApp.texto,
                          ),
                          child: tecla == 'borrar'
                              ? const Icon(Icons.backspace_outlined,
                                  semanticLabel: 'Borrar')
                              : Text(tecla,
                                  style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
