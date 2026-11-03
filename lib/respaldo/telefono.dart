/// `'+57XXXXXXXXXX'` si [digitos] es un celular colombiano de 10 dígitos que
/// empieza por 3 (se ignoran espacios); si no, null.
String? telefonoE164(String digitos) {
  final limpio = digitos.replaceAll(RegExp(r'\s'), '');
  return RegExp(r'^3\d{9}$').hasMatch(limpio) ? '+57$limpio' : null;
}
