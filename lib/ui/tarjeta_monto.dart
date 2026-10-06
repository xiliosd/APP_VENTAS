import 'package:flutter/material.dart';

import 'colores_app.dart';
import 'monto.dart';

/// Tarjeta con una etiqueta, una cifra y un detalle opcional.
class TarjetaMonto extends StatelessWidget {
  const TarjetaMonto({
    super.key,
    required this.etiqueta,
    required this.valor,
    this.tono = TonoMonto.neutro,
    this.detalle,
    this.onTap,
    this.fondo,
    this.tamano = 18,
    this.colorBorde,
  });

  final String etiqueta;
  final int valor;
  final TonoMonto tono;
  final String? detalle;
  final VoidCallback? onTap;
  final Color? fondo;
  final double tamano;

  /// Color del borde (por defecto el gris de [ColoresApp.borde]).
  final Color? colorBorde;

  @override
  Widget build(BuildContext context) {
    final colorEtiqueta = tono == TonoMonto.claro
        ? Colors.white70
        : ColoresApp.textoSecundario;
    return Material(
      color: fondo ?? ColoresApp.superficie,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: fondo == null
            ? BorderSide(
                color: colorBorde ?? ColoresApp.borde,
                width: colorBorde == null ? 1 : 1.5,
              )
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(etiqueta,
                        style: TextStyle(fontSize: 13, color: colorEtiqueta)),
                  ),
                  if (onTap != null)
                    Icon(Icons.chevron_right_rounded,
                        size: 18, color: colorEtiqueta),
                ],
              ),
              const SizedBox(height: 4),
              Monto(valor, tamano: tamano, tono: tono),
              if (detalle != null) ...[
                const SizedBox(height: 2),
                Text(detalle!,
                    style: TextStyle(fontSize: 12, color: colorEtiqueta)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
