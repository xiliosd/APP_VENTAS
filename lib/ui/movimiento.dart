import 'package:flutter/widgets.dart';

/// Duraciones y curvas de toda la app (estilo Material 3 Expressive). Ningún
/// otro archivo define las suyas.
abstract final class Movimiento {
  /// Con rebote: presionar, aparecer.
  static const Curve resorte = Cubic(0.34, 1.6, 0.5, 1);

  /// Entrar y salir.
  static const Curve enfatizada = Curves.easeInOutCubicEmphasized;

  static const corta = Duration(milliseconds: 150);
  static const media = Duration(milliseconds: 300);
  static const larga = Duration(milliseconds: 500);
  static const conteo = Duration(milliseconds: 700);

  /// El celular pide quitar animaciones.
  static bool reducido(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// [d], o cero si el celular pide quitar animaciones.
  static Duration duracion(BuildContext context, Duration d) =>
      reducido(context) ? Duration.zero : d;
}
