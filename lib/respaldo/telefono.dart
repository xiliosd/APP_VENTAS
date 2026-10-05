/// `'+57XXXXXXXXXX'` si [digitos] es un celular colombiano de 10 dígitos que
/// empieza por 3 (se ignoran espacios); si no, null.
String? telefonoE164(String digitos) {
  final limpio = digitos.replaceAll(RegExp(r'\s'), '');
  return RegExp(r'^3\d{9}$').hasMatch(limpio) ? '+57$limpio' : null;
}

/// `'+57 300 *** 4567'`, para mostrar el número sin exponerlo completo.
String telefonoEnmascarado(String e164) {
  final digitos = e164.replaceAll(RegExp(r'\D'), '');
  if (digitos.length != 12 || !digitos.startsWith('57')) return e164;
  return '+57 ${digitos.substring(2, 5)} *** ${digitos.substring(8)}';
}
