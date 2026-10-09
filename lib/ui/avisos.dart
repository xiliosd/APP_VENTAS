import 'package:flutter/material.dart';

import 'movimiento.dart';
import 'vibracion.dart';

/// Aviso abajo de la pantalla. Con [onDeshacer] agrega la acción "Deshacer"
/// y dura 5 s; sin ella dura 3 s. Con [error] vibra como error, no como éxito.
void avisar(BuildContext context, String texto,
    {VoidCallback? onDeshacer, bool error = false}) {
  final messenger = ScaffoldMessenger.of(context);
  error ? Vibracion.error() : Vibracion.exito();
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(texto),
      duration: Duration(seconds: onDeshacer == null ? 3 : 5),
      // En Flutter 3.47 un SnackBar con acción persiste por defecto; el
      // Deshacer debe desaparecer solo a los 5 s.
      persist: false,
      action: onDeshacer == null
          ? null
          : SnackBarAction(label: 'Deshacer', onPressed: onDeshacer),
    ),
    snackBarAnimationStyle: const AnimationStyle(duration: Movimiento.larga),
  );
}
