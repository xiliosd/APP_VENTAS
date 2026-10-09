/// Cómo van las ventas de un día frente al día anterior.
enum TendenciaVentas { sube, baja, igual, casiIgual, sinAnterior }

class ComparacionVentas {
  const ComparacionVentas(this.tendencia, this.porcentaje, this.texto);
  final TendenciaVentas tendencia;
  final int porcentaje;
  final String texto;
}

/// Compara las ventas de [dia] con las del día [anterior]. Null si ninguno
/// de los dos tuvo ventas. [esHoy] decide si se dice "ayer" o "el día anterior".
ComparacionVentas? comparacionVentas(int dia, int anterior, {required bool esHoy}) {
  final cuando = esHoy ? 'ayer' : 'el día anterior';
  if (anterior == 0) {
    if (dia == 0) return null;
    final sujeto = esHoy ? 'Ayer' : 'El día anterior';
    return ComparacionVentas(
        TendenciaVentas.sinAnterior, 0, '$sujeto no hubo ventas');
  }
  if (dia == anterior) {
    return ComparacionVentas(TendenciaVentas.igual, 0, 'Igual que $cuando');
  }
  final porcentaje = ((dia - anterior) / anterior * 100).round().abs();
  if (porcentaje == 0) {
    return ComparacionVentas(
        TendenciaVentas.casiIgual, 0, 'Casi igual que $cuando');
  }
  return dia > anterior
      ? ComparacionVentas(
          TendenciaVentas.sube, porcentaje, '▲ $porcentaje % vs. $cuando')
      : ComparacionVentas(
          TendenciaVentas.baja, porcentaje, '▼ $porcentaje % vs. $cuando');
}
