import 'package:flutter/material.dart';

/// Tokens de color de la app (estilo "claro y confiable", solo modo claro).
/// Los componentes usan siempre estas constantes, nunca hex sueltos.
abstract final class ColoresApp {
  static const primario = Color(0xFF1A539B);

  /// Azul de marca al 15 % sobre blanco: fondos de selección y de íconos.
  static const primarioSuave = Color(0xFFDDE5F0);

  /// Verde de la marca (logo, íconos, bordes, acentos). **Nunca para texto**:
  /// sobre blanco da 3.1:1; para texto y botones con texto blanco usar
  /// [entra].
  static const marcaVerde = Color(0xFF16A34A);

  /// Dinero que entra: ventas, ganancia, botón Cobrar, abonos.
  static const entra = Color(0xFF15803D);

  /// Borde claro de tarjetas de ingresos/ganancia.
  static const entraSuave = Color(0xFFBBF7D0);

  /// Dinero que sale, errores y acciones destructivas.
  static const sale = Color(0xFFDC2626);

  /// Borde claro de tarjetas de gastos.
  static const saleSuave = Color(0xFFFECACA);

  /// Fiado y por cobrar.
  static const fiado = Color(0xFFB45309);
  static const fiadoSuave = Color(0xFFFEF3C7);

  static const fondo = Color(0xFFF8FAFC);
  static const superficie = Color(0xFFFFFFFF);
  static const borde = Color(0xFFE5E7EB);
  static const texto = Color(0xFF1E293B);
  static const textoSecundario = Color(0xFF64748B);
}
