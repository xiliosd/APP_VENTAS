DateTime inicioDelDia(DateTime dia) => DateTime(dia.year, dia.month, dia.day);

DateTime finDelDia(DateTime dia) =>
    DateTime(dia.year, dia.month, dia.day, 23, 59, 59, 999);

String _dosDigitos(int n) => n.toString().padLeft(2, '0');

String formatoFecha(DateTime fecha) =>
    '${_dosDigitos(fecha.day)}/${_dosDigitos(fecha.month)}/${fecha.year}';

String formatoHora(DateTime fecha) =>
    '${_dosDigitos(fecha.hour)}:${_dosDigitos(fecha.minute)}';

String formatoFechaHora(DateTime fecha) =>
    '${formatoFecha(fecha)} ${formatoHora(fecha)}';

/// "Debe desde hoy", "Debe desde ayer" o "Debe desde hace N días".
String textoDebeDesde(DateTime desde, DateTime hoy) {
  final dias = inicioDelDia(hoy).difference(inicioDelDia(desde)).inDays;
  if (dias <= 0) return 'Debe desde hoy';
  if (dias == 1) return 'Debe desde ayer';
  return 'Debe desde hace $dias días';
}
