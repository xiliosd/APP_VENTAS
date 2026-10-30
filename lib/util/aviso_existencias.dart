import '../data/database.dart';

/// Un producto que acaba de llegar a su mínimo o se agotó.
class AvisoExistencias {
  const AvisoExistencias({
    required this.productoId,
    required this.nombre,
    required this.existencias,
    required this.minimo,
  });

  final int productoId;
  final String nombre;
  final int existencias;
  final int minimo;

  bool get agotado => existencias <= 0;

  String get texto =>
      agotado ? 'Se agotó $nombre' : 'Quedan $existencias $nombre: toca pedir';
}

/// Productos que, entre [antes] y [despues], cruzaron su mínimo o llegaron a
/// cero. Si ya estaban por debajo no se repite el aviso: solo molesta al
/// momento de cruzar. Agotados primero, luego por nombre.
List<AvisoExistencias> productosQueCruzaron({
  required Map<int, int> antes,
  required Map<int, int> despues,
  required Map<int, Producto> productos,
}) {
  final avisos = <AvisoExistencias>[];
  for (final entrada in antes.entries) {
    final producto = productos[entrada.key];
    final ahora = despues[entrada.key];
    if (producto == null || ahora == null) continue;
    final previo = entrada.value;
    final cruzoMinimo = previo > producto.minimo && ahora <= producto.minimo;
    final seAgoto = previo > 0 && ahora <= 0;
    if (!cruzoMinimo && !seAgoto) continue;
    avisos.add(
      AvisoExistencias(
        productoId: producto.id,
        nombre: producto.nombre,
        existencias: ahora,
        minimo: producto.minimo,
      ),
    );
  }
  return avisos..sort((a, b) {
    if (a.agotado != b.agotado) return a.agotado ? -1 : 1;
    return a.nombre.compareTo(b.nombre);
  });
}
