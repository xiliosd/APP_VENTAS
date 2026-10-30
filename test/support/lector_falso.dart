import 'package:app_ventas/servicios/lector_codigo.dart';
import 'package:flutter/widgets.dart';

/// Devuelve [codigos] en orden, uno por lectura; null cuando se acaban.
/// Guarda en [usos] para qué se pidió cada lectura.
class LectorFalso implements LectorCodigo {
  LectorFalso(this.codigos);

  final List<String?> codigos;
  final List<UsoEscaner> usos = [];
  int lecturas = 0;

  @override
  Future<String?> leer(
    BuildContext context, {
    UsoEscaner uso = UsoEscaner.venta,
  }) async {
    usos.add(uso);
    return lecturas < codigos.length ? codigos[lecturas++] : null;
  }
}
