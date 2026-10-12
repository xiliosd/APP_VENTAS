import 'package:app_ventas/servicios/lector_codigo.dart';
import 'package:flutter/widgets.dart';

/// Devuelve [codigos] en orden, uno por lectura; null cuando se acaban.
class LectorFalso implements LectorCodigo {
  LectorFalso(this.codigos);

  final List<String?> codigos;
  int lecturas = 0;

  @override
  Future<String?> leer(BuildContext context) async =>
      lecturas < codigos.length ? codigos[lecturas++] : null;
}
