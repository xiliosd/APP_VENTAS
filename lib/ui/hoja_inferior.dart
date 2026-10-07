import 'package:flutter/material.dart';

/// Abre un panel desde abajo con [titulo] y el contenido de [builder]. Se
/// desplaza con el teclado. Devuelve lo que el contenido pase a `pop`.
/// Con [descartable] en false no se cierra tocando afuera ni arrastrando.
Future<T?> mostrarHojaInferior<T>(
  BuildContext context, {
  required String titulo,
  required WidgetBuilder builder,
  bool descartable = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: descartable,
    enableDrag: descartable,
    builder: (contexto) => Padding(
      padding: EdgeInsets.fromLTRB(
          16, 0, 16, MediaQuery.viewInsetsOf(contexto).bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(titulo,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            builder(contexto),
          ],
        ),
      ),
    ),
  );
}
