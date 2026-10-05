import 'package:flutter/material.dart';

/// Aviso de confirmación abajo de la pantalla. Con [onDeshacer] agrega la
/// acción "Deshacer" y dura 5 s; sin ella dura 3 s.
void avisar(BuildContext context, String texto, {VoidCallback? onDeshacer}) {
  final messenger = ScaffoldMessenger.of(context);
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
  );
}
