import 'package:flutter/material.dart';

/// Pregunta si usar en este celular la tienda compartida que ya tiene el
/// correo (reemplazando los datos de aquí). True si el usuario acepta.
Future<bool> preguntarUsarTiendaCompartida(BuildContext context) async {
  final usar = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (contexto) => AlertDialog(
      title: const Text('Este correo ya tiene una tienda compartida'),
      content: const Text(
        'Puedes usar esa tienda en este celular. Los datos que hay aquí se '
        'reemplazan por los de la tienda compartida.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(contexto).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(contexto).pop(true),
          child: const Text('Usar la tienda compartida en este celular'),
        ),
      ],
    ),
  );
  return usar == true;
}

/// Confirma la descarga de la tienda compartida con [mensaje].
Future<bool> confirmarDescargaTienda(
  BuildContext context,
  String mensaje,
) async {
  final confirmado = await showDialog<bool>(
    context: context,
    builder: (contexto) => AlertDialog(
      title: const Text('¿Descargar la tienda?'),
      content: Text(mensaje),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(contexto).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const Key('confirmar_descargar_tienda'),
          onPressed: () => Navigator.of(contexto).pop(true),
          child: const Text('Descargar'),
        ),
      ],
    ),
  );
  return confirmado == true;
}

const mensajeReemplazarPorTiendaCompartida =
    'Se reemplazarán los datos de este celular por los de la tienda '
    'compartida.';
