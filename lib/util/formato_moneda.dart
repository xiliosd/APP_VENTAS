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
/// colombiano en grupos de tres ("3.000", "1.000.000"), el símbolo "$" y
/// espacios. Rechaza signos y todo lo que parezca decimal ("2.5", "1.50"):
/// devuelve null si el texto no es un entero sin signo bien escrito.
int? parsearMonto(String texto) {
  final limpio = texto.replaceAll(RegExp(r'[\s$]'), '');
  if (!RegExp(r'^(\d+|\d{1,3}(\.\d{3})+)$').hasMatch(limpio)) return null;
  return int.tryParse(limpio.replaceAll('.', ''));
}
