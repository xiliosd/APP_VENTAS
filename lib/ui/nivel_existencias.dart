import 'package:flutter/material.dart';

import 'colores_app.dart';
import 'pildora.dart';

/// Qué tan surtido está un producto.
enum NivelExistencias { agotado, bajo, ok }

NivelExistencias nivelExistencias(int existencias, int minimo) =>
    existencias <= 0
        ? NivelExistencias.agotado
        : existencias <= minimo
            ? NivelExistencias.bajo
            : NivelExistencias.ok;

/// Cuánto de la barra de nivel se llena: existencias ÷ "pedir hasta"; sin él,
/// ÷ el doble del mínimo; sin ninguno, llena. Entre 0 y 1.
double fraccionNivel(int existencias, int minimo, int? pedirHasta) {
  if (existencias <= 0) return 0;
  final tope = (pedirHasta ?? 0) > 0
      ? pedirHasta!
      : minimo > 0
          ? 2 * minimo
          : existencias;
  return (existencias / tope).clamp(0.0, 1.0);
}

Color colorNivel(ColoresApp c, NivelExistencias nivel) => switch (nivel) {
      NivelExistencias.agotado => c.sale,
      NivelExistencias.bajo => c.fiado,
      NivelExistencias.ok => c.entra,
    };

/// "Agotado", "Bajo" u "OK".
class EtiquetaNivel extends StatelessWidget {
  const EtiquetaNivel({super.key, required this.nivel});

  final NivelExistencias nivel;

  @override
  Widget build(BuildContext context) {
    return Pildora(
      texto: switch (nivel) {
        NivelExistencias.agotado => 'Agotado',
        NivelExistencias.bajo => 'Bajo',
        NivelExistencias.ok => 'OK',
      },
      color: colorNivel(ColoresApp.of(context), nivel),
    );
  }
}

/// Barra delgada con lo que queda frente al tope.
class BarraNivel extends StatelessWidget {
  const BarraNivel({super.key, required this.fraccion, required this.nivel});

  final double fraccion;
  final NivelExistencias nivel;

  @override
  Widget build(BuildContext context) {
    final c = ColoresApp.of(context);
    return LinearProgressIndicator(
      value: fraccion,
      minHeight: 6,
      borderRadius: BorderRadius.circular(99),
      backgroundColor: c.textoSecundario.withValues(alpha: 0.15),
      color: colorNivel(c, nivel),
    );
  }
}
