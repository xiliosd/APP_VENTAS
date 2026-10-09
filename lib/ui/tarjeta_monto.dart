import 'package:flutter/material.dart';

import 'colores_app.dart';
import 'monto.dart';
import 'tema_app.dart';

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

  /// Color del borde; sin él la tarjeta no tiene borde (la distingue su
  /// color de superficie).
  final Color? colorBorde;

  @override
  Widget build(BuildContext context) {
    final colorEtiqueta = tono == TonoMonto.claro
        ? ColoresApp.of(context)
            .sobreTarjetaPrincipal
            .withValues(alpha: 0.75)
        : ColoresApp.of(context).textoSecundario;
    return Material(
      color: fondo ?? ColoresApp.of(context).superficie,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radioTarjeta),
        side: colorBorde == null || fondo != null
            ? BorderSide.none
            : BorderSide(color: colorBorde!, width: 1.5),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radioTarjeta),
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
