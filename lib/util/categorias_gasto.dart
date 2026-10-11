/// Categorías rápidas de gasto; se guardan al inicio de la descripción
/// ("Mercancía · hielo"). "Otro" es la ausencia de categoría.
const categoriasGasto = ['Mercancía', 'Servicios', 'Arriendo', 'Transporte'];

const _separador = ' · ';

/// Categoría al inicio de [descripcion], o null.
String? categoriaDe(String descripcion) {
  for (final c in categoriasGasto) {
    if (descripcion == c || descripcion.startsWith('$c$_separador')) return c;
  }
  return null;
}

/// [descripcion] con [categoria] al inicio (reemplazando la que hubiera);
/// con null, sin categoría.
String aplicarCategoria(String descripcion, String? categoria) {
  final actual = categoriaDe(descripcion.trim());
  var resto = descripcion.trim();
  if (actual != null) {
    resto = resto == actual ? '' : resto.substring(actual.length + _separador.length);
  }
  resto = resto.trim();
  if (categoria == null) return resto;
  return resto.isEmpty ? categoria : '$categoria$_separador$resto';
}
