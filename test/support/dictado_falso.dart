import 'dart:async';

import 'package:app_ventas/servicios/dictado.dart';

/// Dictado de prueba: responde [estado] al preparar y "oye" [texto]; con
/// [pendiente] espera a que la prueba lo complete.
class DictadoFalso implements Dictado {
  DictadoFalso({this.estado = EstadoDictado.listo, this.texto});

  EstadoDictado estado;
  String? texto;
  bool noDisponible = false;
  Completer<String?>? pendiente;
  void Function(String)? alOir;
  int escuchas = 0;
  int detenciones = 0;
  int preparaciones = 0;

  /// Si está, preparar() espera a que la prueba lo complete.
  Completer<void>? esperaPreparar;

  /// Como el plugin real: tras detener aún entrega lo que oyó.
  String? oyeDespuesDeDetener;

  @override
  Future<EstadoDictado> preparar() async {
    preparaciones++;
    if (esperaPreparar != null) await esperaPreparar!.future;
    return estado;
  }

  @override
  Future<String?> escuchar({required void Function(String parcial) alOir}) {
    escuchas++;
    this.alOir = alOir;
    if (noDisponible) return Future.error(const DictadoNoDisponible());
    if (pendiente != null) return pendiente!.future;
    if (texto != null) alOir(texto!);
    return Future.value(texto);
  }

  @override
  Future<void> detener() async {
    detenciones++;
    final tardio = oyeDespuesDeDetener;
    if (pendiente != null && !pendiente!.isCompleted) pendiente!.complete(null);
    if (tardio != null) alOir?.call(tardio);
  }
}
