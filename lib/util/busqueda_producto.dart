import '../data/database.dart';
import 'texto_util.dart';

/// [p] coincide con lo escrito: nombre, marca o tamaño (sin tildes ni
/// mayúsculas) o el código de barras exacto. Vacío coincide con todo.
bool coincideBusqueda(Producto p, String consulta) {
  final q = sinTildes(claveNombre(consulta));
  if (q.isEmpty) return true;
  if (p.codigoBarras != null && p.codigoBarras == consulta.trim()) {
    return true;
  }
  return [p.nombre, p.marca, p.tamano]
      .whereType<String>()
      .any((t) => sinTildes(claveNombre(t)).contains(q));
}

/// "Marca · Tamaño" con lo que tenga, o null.
String? detalleProducto(Producto p) {
  final partes = [p.marca, p.tamano].whereType<String>().toList();
  return partes.isEmpty ? null : partes.join(' · ');
}
