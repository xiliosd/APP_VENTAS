import 'package:flutter/material.dart';

import '../../ui/colores_app.dart';
import '../../util/fecha_util.dart';

enum EleccionRespaldoExistente { restaurar, reemplazar, cancelar }

/// Pregunta qué hacer cuando el número ya tiene un respaldo en la nube, para
/// no pisar por accidente un respaldo bueno con los datos de este celular.
class DialogoRespaldoExistente extends StatelessWidget {
  const DialogoRespaldoExistente({super.key, required this.fecha});

  final DateTime fecha;

  @override
  Widget build(BuildContext context) {
    void elegir(EleccionRespaldoExistente eleccion) =>
        Navigator.of(context).pop(eleccion);
    return AlertDialog(
      title: const Text('Ya hay un respaldo'),
      content: Text(
        'Ya hay un respaldo de esta tienda del ${formatoFechaHora(fecha)}. '
        '¿Qué quieres hacer?',
      ),
      actionsOverflowDirection: VerticalDirection.down,
      actionsOverflowButtonSpacing: 4,
      actions: [
        FilledButton(
          key: const Key('boton_restaurar_existente'),
          onPressed: () => elegir(EleccionRespaldoExistente.restaurar),
          child: const Text('Restaurarlo en este celular'),
        ),
        OutlinedButton(
          key: const Key('boton_reemplazar_existente'),
          onPressed: () => elegir(EleccionRespaldoExistente.reemplazar),
          child: const Text('Reemplazarlo con los datos de este celular'),
        ),
        TextButton(
          key: const Key('boton_cancelar_existente'),
          style: TextButton.styleFrom(foregroundColor: ColoresApp.sale),
          onPressed: () => elegir(EleccionRespaldoExistente.cancelar),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}
