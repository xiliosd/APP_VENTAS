import 'package:flutter/material.dart';

import 'colores_app.dart';

const _paleta = [
  ColoresApp.primario,
  Color(0xFF0F766E),
  Color(0xFF7C3AED),
  ColoresApp.fiado,
  Color(0xFFBE185D),
  ColoresApp.entra,
];

/// Círculo de color con la inicial del nombre; el color sale del id.
class AvatarInicial extends StatelessWidget {
  const AvatarInicial({
    super.key,
    required this.id,
    required this.nombre,
    this.radio = 20,
  });

  final int id;
  final String nombre;
  final double radio;

  @override
  Widget build(BuildContext context) {
    final limpio = nombre.trim();
    return CircleAvatar(
      radius: radio,
      backgroundColor: _paleta[id % _paleta.length],
      child: Text(
        limpio.isEmpty ? '?' : limpio[0].toUpperCase(),
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: radio * 0.9,
        ),
      ),
    );
  }
}

String etiquetaRol(String rol) => rol == 'admin' ? 'Administrador' : 'Vendedor';
