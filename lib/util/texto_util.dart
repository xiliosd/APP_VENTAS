/// "1 venta", "3 ventas".
String plural(int n, String uno, String varios) =>
    '$n ${n == 1 ? uno : varios}';

/// Forma de comparar nombres: sin mayúsculas y con los espacios recortados
/// y colapsados ("  Don  Juan " → "don juan").
String claveNombre(String nombre) =>
    nombre.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
