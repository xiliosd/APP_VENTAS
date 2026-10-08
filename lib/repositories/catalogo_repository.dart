import '../data/database.dart';
import 'inventario_repository.dart';
import 'producto_repository.dart';
import 'proveedor_repository.dart';

/// Un proveedor del producto en el formulario; [proveedorId] null = nuevo
/// (se crea al guardar, o se reutiliza uno con el mismo nombre).
class ProveedorEnFormulario {
  const ProveedorEnFormulario({
    this.proveedorId,
    required this.nombre,
    required this.precioCompra,
    required this.preferido,
  });

  final int? proveedorId;
  final String nombre;
  final int precioCompra;
  final bool preferido;
}

/// Existencias pedidas en el formulario. [hayAhora] solo al activar el
/// control.
class ControlEnFormulario {
  const ControlEnFormulario({
    this.hayAhora,
    required this.minimo,
    this.pedirHasta,
  });

  final int? hayAhora;
  final int minimo;
  final int? pedirHasta;
}

/// Guarda un producto con sus proveedores y existencias en una sola
/// transacción: si algo falla, no queda nada a medias.
class CatalogoRepository {
  CatalogoRepository(
    this._db,
    this._productos,
    this._proveedores,
    this._inventario,
  );

  final AppDatabase _db;
  final ProductoRepository _productos;
  final ProveedorRepository _proveedores;
  final InventarioRepository _inventario;

  /// [control] null = no controla existencias; [controlabaAntes] indica si
  /// las controlaba al abrir el formulario. Devuelve el id del producto.
  Future<int> guardarProductoCompleto({
    int? id,
    required String nombre,
    required int precio,
    required List<ProveedorEnFormulario> proveedores,
    ControlEnFormulario? control,
    required bool controlabaAntes,
    required Usuario por,
  }) {
    return _db.transaction(() async {
      final vinculos = <ProveedorDeProducto>[];
      for (final p in proveedores) {
        final proveedorId = p.proveedorId ??
            (await _proveedores.buscarPorNombre(p.nombre))?.id ??
            await _proveedores.crear(nombre: p.nombre);
        vinculos.add(ProveedorDeProducto(
          proveedorId: proveedorId,
          precioCompra: p.precioCompra,
          preferido: p.preferido,
        ));
      }
      final productoId = await _productos.guardarProducto(
        id: id,
        nombre: nombre,
        precio: precio,
        proveedores: vinculos,
      );
      if (control != null) {
        if (!controlabaAntes) {
          await _inventario.activarControl(
            productoId,
            cantidad: control.hayAhora!,
            minimo: control.minimo,
            por: por,
          );
        }
        await _inventario.cambiarLimites(
          productoId,
          minimo: control.minimo,
          pedirHasta: control.pedirHasta,
        );
      } else if (controlabaAntes) {
        await _inventario.desactivarControl(productoId);
      }
      return productoId;
    });
  }
}
