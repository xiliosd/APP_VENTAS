/// Forma básica `usuario@dominio.tld`: sin espacios, una sola arroba y un
/// dominio con al menos un punto entre partes no vacías. No pretende validar
/// todo lo que permite el estándar: el código que llega al correo confirma
/// que existe.
final _formaCorreo = RegExp(r'^[^\s@]+@[^\s@.]+(\.[^\s@.]+)+$');

/// El correo recortado y en minúsculas si tiene la forma
/// `usuario@dominio.tld`; si no, null.
String? correoNormalizado(String texto) {
  final limpio = texto.trim().toLowerCase();
  return _formaCorreo.hasMatch(limpio) ? limpio : null;
}

/// `'os***@gmail.com'`, para mostrar el correo sin exponerlo completo: deja
/// ver las dos primeras letras del usuario, o una si el usuario es corto.
String correoEnmascarado(String correo) {
  final arroba = correo.indexOf('@');
  if (arroba <= 0) return correo;
  final usuario = correo.substring(0, arroba);
  final visibles = usuario.length > 2 ? 2 : 1;
  return '${usuario.substring(0, visibles)}***${correo.substring(arroba)}';
}
