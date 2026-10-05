import 'package:flutter/material.dart';

import 'colores_app.dart';

/// Ícono y nombre de la app, para las pantallas de entrada.
class MarcaApp extends StatelessWidget {
  const MarcaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: ColoresApp.primario,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.storefront_rounded, color: Colors.white),
        ),
        const SizedBox(width: 12),
        const Text(
          'App Ventas',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: ColoresApp.primario,
          ),
        ),
      ],
    );
  }
}
