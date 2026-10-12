import 'package:flutter/material.dart';

/// Ícono de 20 px en un cuadrado redondeado de 36 px con su color al 15 %.
class IconoCuadrado extends StatelessWidget {
  const IconoCuadrado({super.key, required this.icono, required this.color});

  final IconData icono;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icono, size: 20, color: color),
    );
  }
}
