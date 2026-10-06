import '../data/database.dart';
import 'fecha_util.dart';

/// true si [usuario] puede corregir o anular un movimiento registrado por
/// [duenoId] en [fechaMovimiento]: el administrador siempre; el vendedor solo
/// lo suyo y del mismo día que [ahora].
bool puedeCorregir({
  required Usuario usuario,
  required int duenoId,
  required DateTime fechaMovimiento,
  required DateTime ahora,
}) {
  if (usuario.rol == 'admin') return true;
  return duenoId == usuario.id &&
      inicioDelDia(fechaMovimiento) == inicioDelDia(ahora);
}
