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

/// true si [usuario] maneja productos, proveedores y pedidos: el
/// administrador, o un vendedor de confianza con el permiso de catálogo.
bool puedeManejarCatalogo(Usuario? usuario) =>
    usuario != null && (usuario.rol == 'admin' || usuario.manejaCatalogo);

/// true si [usuario] puede editar o anular un pedido hecho por [autorId].
bool puedeCambiarPedido(Usuario usuario, {required int autorId}) =>
    puedeManejarCatalogo(usuario) || usuario.id == autorId;
