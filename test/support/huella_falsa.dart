import 'dart:async';

import 'package:app_ventas/servicios/autenticacion_huella.dart';

/// Huella de prueba: dice si hay biometría y responde [resultado]; con
/// [pendiente] espera a que la prueba la complete.
class HuellaFalsa implements AutenticacionHuella {
  HuellaFalsa({this.hay = true, this.resultado = ResultadoHuella.aprobada});

  bool hay;
  ResultadoHuella resultado;
  Completer<ResultadoHuella>? pendiente;
  int llamadas = 0;
  String? motivo;

  @override
  Future<bool> disponible() async => hay;

  @override
  Future<ResultadoHuella> confirmar(String motivo) {
    llamadas++;
    this.motivo = motivo;
    return pendiente?.future ?? Future.value(resultado);
  }
}
