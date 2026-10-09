import 'package:flutter/services.dart';

/// Vibraciones de la app. Respetan la configuración de vibración del celular.
abstract final class Vibracion {
  /// Tocar una tecla, un producto o un botón; cambiar de pestaña.
  static void toque() => HapticFeedback.selectionClick();

  /// Algo se registró bien (aviso de confirmación).
  static void exito() => HapticFeedback.mediumImpact();

  /// PIN incorrecto o falta un dato.
  static void error() => HapticFeedback.heavyImpact();
}
