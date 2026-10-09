import 'package:flutter/material.dart';

/// Familia de los títulos de marca. Es una fuente variable: el peso se fija
/// con el eje `wght` (sin él se vería con el peso por defecto).
const familiaTitulos = 'Nunito';

/// Títulos de marca: Nunito ExtraBold.
/// Sin [color], el texto hereda el color del tema.
TextStyle estiloTitulo({double tamano = 24, Color? color}) {
  return TextStyle(
    fontFamily: familiaTitulos,
    fontSize: tamano,
    fontWeight: FontWeight.w800,
    fontVariations: const [FontVariation('wght', 800)],
    color: color,
  );
}
