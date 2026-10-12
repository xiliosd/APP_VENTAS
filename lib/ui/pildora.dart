import 'package:flutter/material.dart';

import 'colores_app.dart';

/// Etiqueta corta: un punto del [color] y el texto sobre ese color al 15 %.
/// El texto va en el color de texto para leerse bien en ambos temas.
class Pildora extends StatelessWidget {
  const Pildora({super.key, required this.texto, required this.color});

  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: ShapeDecoration(
        shape: const StadiumBorder(),
        color: color.withValues(alpha: 0.15),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              texto,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: ColoresApp.of(context).texto,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
