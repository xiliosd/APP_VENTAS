import '../sincronizacion/nube_tienda.dart';

/// Lo que trae el QR que el dueño le muestra al vendedor: nunca el PIN.
typedef DatosUnirse = ({String codigo, int numero});

const _prefijo = 'vecitienda:unirse:1:';

/// Mismo alfabeto que `_codigo_tienda_nuevo` en la nube (sin 0/O/1/I/L).
final _formatoCodigo = RegExp(r'^[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{6}$');

String textoCodigoUnirse({required String codigo, required int numero}) =>
    '$_prefijo$codigo:$numero';

/// Los datos del QR, o null si no es un código de VeciTienda de esta versión.
DatosUnirse? leerCodigoUnirse(String texto) {
  final limpio = texto.trim();
  if (!limpio.startsWith(_prefijo)) return null;
  final partes = limpio.substring(_prefijo.length).split(':');
  if (partes.length != 2) return null;
  final codigo = partes[0].toUpperCase();
  final numero = int.tryParse(partes[1]);
  if (!_formatoCodigo.hasMatch(codigo) || numero == null || numero < 1) {
    return null;
  }
  return (codigo: codigo, numero: numero);
}

/// Si [celular] es un celular aprobado del vendedor con [idGlobal].
bool esCelularAprobadoDe(CelularTienda celular, String? idGlobal) =>
    celular.rol == 'vendedor' &&
    celular.estado == EstadoMiembro.aprobado &&
    idGlobal != null &&
    celular.usuarioIdGlobal == idGlobal;

/// Si el vendedor con [idGlobal] ya tiene un celular aprobado.
bool tieneCelularAprobado(List<CelularTienda> celulares, String? idGlobal) =>
    celulares.any((celular) => esCelularAprobadoDe(celular, idGlobal));

/// Al aprobar el celular nuevo de un vendedor, los que tenía antes y dejan
/// de servir: solo los aprobados de ese mismo vendedor.
List<CelularTienda> celularesAReemplazar(
  List<CelularTienda> celulares, {
  required String idGlobal,
  required String usuarioAuthNuevo,
}) => [
  for (final celular in celulares)
    if (esCelularAprobadoDe(celular, idGlobal) &&
        celular.usuarioAuth != usuarioAuthNuevo)
      celular,
];
