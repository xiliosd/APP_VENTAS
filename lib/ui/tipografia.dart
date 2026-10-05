import 'package:flutter/material.dart';

import 'colores_app.dart';

/// Familia de los títulos de marca. Es una fuente variable: el peso se fija
/// con el eje `wght` (sin él se vería con el peso por defecto).
const familiaTitulos = 'Nunito';

/// Títulos de marca: Nunito ExtraBold.
TextStyle estiloTitulo({double tamano = 24, Color color = ColoresApp.texto}) {
  return TextStyle(
    fontFamily: familiaTitulos,
    fontSize: tamano,
    fontWeight: FontWeight.w800,
    fontVariations: const [FontVariation('wght', 800)],
    color: color,
  );
}
