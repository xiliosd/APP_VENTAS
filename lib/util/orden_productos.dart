import '../data/database.dart';
import 'texto_util.dart';

/// Cómo se ordena un listado de productos.
enum OrdenProductos { alfabetico, creacion, masVendidos }

/// Clave de orden por nombre: sin tildes ni mayúsculas, con la ñ entre la n
/// y la o ("Nube", "Ñame", "Oso").
String _claveAlfabetica(Producto p) =>
    sinTildes('${p.nombre} ${p.tamano ?? ''}'.trim())
        .replaceAll('ñ', 'n\u007f');

int _alfabetico(Producto a, Producto b) {
  final porNombre = _claveAlfabetica(a).compareTo(_claveAlfabetica(b));
  return porNombre != 0 ? porNombre : a.id.compareTo(b.id);
}

/// [productos] en [orden], sin cambiar la lista recibida. Con
/// [OrdenProductos.masVendidos], [vendidos] (id → unidades) manda; los que
/// no se vendieron siguen en A–Z.
List<Producto> ordenarProductos(
  List<Producto> productos,
  OrdenProductos orden, {
  Map<int, int> vendidos = const {},
}) {
  final lista = [...productos];
  switch (orden) {
    case OrdenProductos.alfabetico:
      lista.sort(_alfabetico);
    case OrdenProductos.creacion:
      lista.sort((a, b) => a.id.compareTo(b.id));
    case OrdenProductos.masVendidos:
      lista.sort((a, b) {
        final porVentas = (vendidos[b.id] ?? 0).compareTo(vendidos[a.id] ?? 0);
        return porVentas != 0 ? porVentas : _alfabetico(a, b);
      });
  }
  return lista;
}
