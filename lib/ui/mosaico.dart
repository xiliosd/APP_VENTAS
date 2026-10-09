import 'package:flutter/material.dart';

import 'colores_app.dart';
import 'tema_app.dart';
import 'vibracion.dart';

/// Baldosa tocable para productos y montos rápidos, con insignia de cantidad.
class Mosaico extends StatelessWidget {
  const Mosaico({
    super.key,
    required this.titulo,
    this.subtitulo,
    this.cantidad = 0,
    required this.onTap,
    this.destacado = false,
  });

  final String titulo;
  final String? subtitulo;
  final int cantidad;
  final VoidCallback onTap;
  final bool destacado;

  @override
  Widget build(BuildContext context) {
    final elegido = cantidad > 0;
    return Material(
      color: ColoresApp.of(context).superficie,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radioTarjeta),
        side: BorderSide(
          color: elegido ? ColoresApp.of(context).primario : ColoresApp.of(context).borde,
          width: elegido ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          Vibracion.toque();
          onTap();
        },
        borderRadius: BorderRadius.circular(radioTarjeta),
        child: Stack(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      titulo,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: destacado
                            ? ColoresApp.of(context).primario
                            : ColoresApp.of(context).texto,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    if (subtitulo != null)
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          subtitulo!,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 13,
                            color: ColoresApp.of(context).textoSecundario,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (elegido)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: ColoresApp.of(context).primario,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$cantidad',
                    style: TextStyle(
                      color: ColoresApp.of(context).sobrePrimario,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Alto de un [Mosaico] según el tamaño de letra del teléfono, para que el
/// título (hasta 2 líneas) y el subtítulo quepan sin cortarse.
double altoMosaico(BuildContext context, {required bool conSubtitulo}) {
  return MediaQuery.textScalerOf(context).scale(conSubtitulo ? 60 : 40) + 24;
}

/// Grilla de 3 columnas de [Mosaico]s con alto ajustado a la letra.
class GrillaMosaicos extends StatelessWidget {
  const GrillaMosaicos({
    super.key,
    required this.conSubtitulo,
    required this.children,
  });

  final bool conSubtitulo;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        mainAxisExtent: altoMosaico(context, conSubtitulo: conSubtitulo),
      ),
      children: children,
    );
  }
}
