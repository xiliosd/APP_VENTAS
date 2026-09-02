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
