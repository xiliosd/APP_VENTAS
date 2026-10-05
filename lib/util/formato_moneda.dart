String formatoMoneda(int montoEnPesos) {
  final esNegativo = montoEnPesos < 0;
  final digitos = montoEnPesos.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digitos.length; i++) {
    if (i > 0 && (digitos.length - i) % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(digitos[i]);
  }
  final signo = esNegativo ? '-' : '';
  return '$signo\$$buffer';
}

/// Interpreta un monto escrito por el usuario. Acepta el separador de miles
/// colombiano ("3.000"), el símbolo "$" y espacios; rechaza signos y
/// decimales. Devuelve null si el texto no es un entero sin signo.
int? parsearMonto(String texto) {
  final limpio = texto.replaceAll(RegExp(r'[\s.$]'), '');
  if (!RegExp(r'^\d+$').hasMatch(limpio)) return null;
  return int.tryParse(limpio);
}
