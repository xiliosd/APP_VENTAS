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

/// "hoy 14:32", "ayer 09:05" o "03/10/2026 14:32".
String textoUltimoRespaldo(DateTime fecha, DateTime ahora) {
  final dias = inicioDelDia(ahora).difference(inicioDelDia(fecha)).inDays;
  if (dias == 0) return 'hoy ${formatoHora(fecha)}';
  if (dias == 1) return 'ayer ${formatoHora(fecha)}';
  return formatoFechaHora(fecha);
}
