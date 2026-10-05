import 'package:flutter/material.dart';

import 'colores_app.dart';

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
      color: ColoresApp.superficie,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: elegido ? ColoresApp.primario : ColoresApp.borde,
          width: elegido ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
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
                        color:
                            destacado ? ColoresApp.primario : ColoresApp.texto,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    if (subtitulo != null)
                      Text(
                        subtitulo!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          color: ColoresApp.textoSecundario,
                          fontFeatures: [FontFeature.tabularFigures()],
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: ColoresApp.primario,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$cantidad',
                    style: const TextStyle(
                      color: Colors.white,
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
