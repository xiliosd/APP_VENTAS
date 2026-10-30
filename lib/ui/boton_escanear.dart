import 'package:flutter/material.dart';

/// Botón con texto para abrir el escáner: un ícono solo no le dice a quien
/// usa la app por primera vez que ahí se escanea el código de barras.
class BotonEscanear extends StatelessWidget {
  const BotonEscanear({
    super.key,
    required this.onPressed,
    this.texto = 'Escanear código',
  });

  final VoidCallback? onPressed;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
      icon: const Icon(Icons.qr_code_scanner_rounded),
      label: Text(texto, overflow: TextOverflow.ellipsis),
    );
  }
}
