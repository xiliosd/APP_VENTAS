import 'package:flutter/material.dart';

/// Tokens de color de la app (estilo "claro y confiable", solo modo claro).
/// Los componentes usan siempre estas constantes, nunca hex sueltos.
abstract final class ColoresApp {
  static const primario = Color(0xFF1E3A8A);

  /// Dinero que entra: ventas, ganancia, botón Cobrar, abonos.
  static const entra = Color(0xFF15803D);

  /// Dinero que sale, errores y acciones destructivas.
  static const sale = Color(0xFFDC2626);

  /// Fiado y por cobrar.
  static const fiado = Color(0xFFB45309);
  static const fiadoSuave = Color(0xFFFEF3C7);

  static const fondo = Color(0xFFF7F9FC);
  static const superficie = Color(0xFFFFFFFF);
  static const borde = Color(0xFFE5E7EB);
  static const texto = Color(0xFF0F172A);
  static const textoSecundario = Color(0xFF64748B);
}
