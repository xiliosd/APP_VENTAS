import 'package:flutter/material.dart';

import '../util/fecha_util.dart';

/// Selector de día: ‹ fecha ›. Tocar la fecha abre un calendario. No permite
/// elegir días posteriores a hoy. [onCambio] siempre recibe el día
/// normalizado a medianoche, listo para usarse como clave de provider.
class SelectorFecha extends StatelessWidget {
  const SelectorFecha({super.key, required this.dia, required this.onCambio});

  final DateTime dia;
  final ValueChanged<DateTime> onCambio;

  @override
  Widget build(BuildContext context) {
    final hoy = inicioDelDia(DateTime.now());
    final seleccionado = inicioDelDia(dia);
    final esHoy = seleccionado == hoy;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          key: const Key('boton_dia_anterior'),
          icon: const Icon(Icons.chevron_left),
          tooltip: 'Día anterior',
          onPressed: () => onCambio(DateTime(
              seleccionado.year, seleccionado.month, seleccionado.day - 1)),
        ),
        TextButton(
          key: const Key('boton_elegir_fecha'),
          onPressed: () async {
            final elegido = await showDatePicker(
              context: context,
              initialDate: seleccionado,
              firstDate: DateTime(2000),
              lastDate: hoy,
            );
            if (elegido != null) onCambio(inicioDelDia(elegido));
          },
          child: Text(
            esHoy ? 'Hoy' : formatoFecha(seleccionado),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        IconButton(
          key: const Key('boton_dia_siguiente'),
          icon: const Icon(Icons.chevron_right),
          tooltip: 'Día siguiente',
          onPressed: esHoy
              ? null
              : () => onCambio(DateTime(seleccionado.year, seleccionado.month,
                  seleccionado.day + 1)),
        ),
      ],
    );
  }
}
