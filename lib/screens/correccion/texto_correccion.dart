import '../../data/database.dart';
import '../../util/fecha_util.dart';

/// "Anulada por Ana · 15:40" o "Corregida por Ana · antes: $5.000 · Efectivo".
/// Las ventas van en femenino; los abonos y los gastos, en masculino.
String textoCorreccion(Correccion correccion, String nombreUsuario) {
  final femenino = correccion.tipoMovimiento == TipoMovimiento.venta;
  if (correccion.accion == AccionCorreccion.anulado) {
    return '${femenino ? 'Anulada' : 'Anulado'} por $nombreUsuario · '
        '${formatoHora(correccion.fecha)}';
  }
  return '${femenino ? 'Corregida' : 'Corregido'} por $nombreUsuario · '
      'antes: ${correccion.antes}';
}
