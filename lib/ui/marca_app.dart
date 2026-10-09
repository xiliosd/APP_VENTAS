import 'package:flutter/material.dart';

import 'colores_app.dart';
import 'tipografia.dart';

/// Isotipo y nombre de la app (y, si se pide, el slogan), para las pantallas
/// de entrada.
class MarcaApp extends StatelessWidget {
  const MarcaApp({super.key, this.conSlogan = false});

  final bool conSlogan;

  static const slogan = 'La tranquilidad de tu tienda, en tu bolsillo.';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Image.asset(
              'assets/marca/isotipo.png',
              key: const Key('isotipo_marca'),
              width: 56,
              height: 56,
              semanticLabel: 'Logo de VeciTienda',
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                'VeciTienda',
                style: estiloTitulo(tamano: 28, color: ColoresApp.of(context).primario),
              ),
            ),
          ],
        ),
        if (conSlogan) ...[
          const SizedBox(height: 8),
          Text(
            slogan,
            style: TextStyle(fontSize: 15, color: ColoresApp.of(context).textoSecundario),
          ),
        ],
      ],
    );
  }
}
