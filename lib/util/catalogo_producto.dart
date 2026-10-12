/// Tipos de producto (clave → nombre). Se guardan las claves.
const Map<String, String> tiposProducto = {
  'bebidas': 'Bebidas',
  'lacteos': 'Lácteos',
  'panaderia': 'Panadería',
  'abarrotes': 'Granos y abarrotes',
  'snacks': 'Snacks y dulces',
  'aseo_personal': 'Aseo personal',
  'aseo_hogar': 'Aseo del hogar',
  'licores': 'Licores',
  'carnes': 'Carnes y embutidos',
  'fruver': 'Frutas y verduras',
  'otros': 'Otros',
};

/// Envases (clave → nombre). Se guardan las claves.
const Map<String, String> envasesProducto = {
  'botella_plastica': 'Botella plástica',
  'botella_vidrio': 'Botella de vidrio',
  'lata': 'Lata',
  'caja': 'Caja o tetrapak',
  'bolsa': 'Bolsa',
  'paquete': 'Paquete',
  'frasco': 'Frasco',
  'granel': 'Granel',
  'otro': 'Otro',
};

String nombreTipo(String clave) => tiposProducto[clave] ?? clave;

String nombreEnvase(String clave) => envasesProducto[clave] ?? clave;

/// Palabras de las etiquetas de Open Food Facts → tipo. "licores" va primero
/// para ganarle a "bebidas" cuando una bebida es alcohólica.
const _palabrasTipo = <String, List<String>>{
  'licores': ['alcoholic-beverages', 'beers', 'wines', 'spirits', 'liquors'],
  'lacteos': ['dairies', 'milks', 'yogurts', 'cheeses', 'butters'],
  'bebidas': ['beverages', 'sodas', 'waters', 'juices', 'carbonated-drinks'],
  'panaderia': ['breads', 'bakery'],
  'snacks': ['snacks', 'chocolates', 'candies', 'biscuits', 'confectioneries'],
  'abarrotes': [
    'cereals', 'rices', 'pastas', 'legumes', 'oils', 'sugars', 'flours',
    'coffees', 'salts',
  ],
  'carnes': ['meats', 'sausages', 'hams'],
  'fruver': ['fruits', 'vegetables'],
  'aseo_personal': ['shampoos', 'soaps', 'toothpastes', 'deodorants'],
  'aseo_hogar': ['detergents', 'cleaning'],
};

/// Quita el prefijo de idioma ("en:sodas" → "sodas").
String _sinPrefijo(String etiqueta) {
  final i = etiqueta.indexOf(':');
  return (i < 0 ? etiqueta : etiqueta.substring(i + 1)).toLowerCase();
}

String? tipoDesdeOff(List<String> etiquetas) {
  final limpias = etiquetas.map(_sinPrefijo).toSet();
  for (final MapEntry(key: tipo, value: palabras) in _palabrasTipo.entries) {
    if (palabras.any(limpias.contains)) return tipo;
  }
  return null;
}

const _palabrasEnvase = <String, List<String>>{
  'botella_plastica': ['plastic-bottle', 'pet-bottle'],
  'botella_vidrio': ['glass-bottle'],
  'lata': ['can', 'aluminium-can', 'metal-can'],
  'caja': ['tetra-pak', 'carton', 'box', 'brick'],
  'bolsa': ['bag', 'sachet', 'pouch'],
  'frasco': ['jar'],
  'paquete': ['packet', 'wrapper', 'pack'],
};

String? envaseDesdeOff(List<String> etiquetas) {
  final limpias = etiquetas.map(_sinPrefijo).toSet();
  for (final MapEntry(key: envase, value: palabras)
      in _palabrasEnvase.entries) {
    if (palabras.any(limpias.contains)) return envase;
  }
  return null;
}
