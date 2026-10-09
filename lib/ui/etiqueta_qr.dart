import 'package:flutter/material.dart';

import 'colores_app.dart';

/// Marca pequeña "QR" para ventas y abonos recibidos por transferencia.
class EtiquetaQr extends StatelessWidget {
  const EtiquetaQr({super.key = const Key('etiqueta_qr')});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: ColoresApp.of(context).primario.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'QR',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: ColoresApp.of(context).primario,
        ),
      ),
    );
  }
}
