import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/catalogo_repository.dart';
import '../repositories/cliente_repository.dart';
import '../repositories/correccion_repository.dart';
import '../repositories/fiado_repository.dart';
import '../repositories/gasto_repository.dart';
import '../repositories/historial_repository.dart';
import '../repositories/inventario_repository.dart';
import '../repositories/producto_repository.dart';
import '../repositories/proveedor_repository.dart';
import '../repositories/reporte_repository.dart';
import '../repositories/resumen_repository.dart';
import '../repositories/usuario_repository.dart';
import '../repositories/venta_repository.dart';
import 'database_provider.dart';

final usuarioRepositoryProvider = Provider(
  (ref) => UsuarioRepository(ref.watch(databaseProvider)),
);

final productoRepositoryProvider = Provider(
  (ref) => ProductoRepository(ref.watch(databaseProvider)),
);

final clienteRepositoryProvider = Provider(
  (ref) => ClienteRepository(ref.watch(databaseProvider)),
);

final ventaRepositoryProvider = Provider(
  (ref) => VentaRepository(ref.watch(databaseProvider)),
);

final fiadoRepositoryProvider = Provider(
  (ref) => FiadoRepository(
    ref.watch(databaseProvider),
    correcciones: ref.watch(correccionRepositoryProvider),
  ),
);

final gastoRepositoryProvider = Provider(
  (ref) => GastoRepository(ref.watch(databaseProvider)),
);

final resumenRepositoryProvider = Provider(
  (ref) => ResumenRepository(
    ref.watch(databaseProvider),
    ref.watch(ventaRepositoryProvider),
    ref.watch(gastoRepositoryProvider),
    ref.watch(fiadoRepositoryProvider),
  ),
);

final historialRepositoryProvider = Provider(
  (ref) => HistorialRepository(
    ref.watch(ventaRepositoryProvider),
    ref.watch(gastoRepositoryProvider),
    ref.watch(correccionRepositoryProvider),
    ref.watch(clienteRepositoryProvider),
  ),
);

final correccionRepositoryProvider = Provider(
  (ref) => CorreccionRepository(ref.watch(databaseProvider)),
);

final reporteRepositoryProvider = Provider(
  (ref) => ReporteRepository(
    ref.watch(databaseProvider),
    ref.watch(fiadoRepositoryProvider),
  ),
);

final proveedorRepositoryProvider = Provider(
  (ref) => ProveedorRepository(ref.watch(databaseProvider)),
);

final inventarioRepositoryProvider = Provider(
  (ref) => InventarioRepository(ref.watch(databaseProvider)),
);

final catalogoRepositoryProvider = Provider(
  (ref) => CatalogoRepository(
    ref.watch(databaseProvider),
    ref.watch(productoRepositoryProvider),
    ref.watch(proveedorRepositoryProvider),
    ref.watch(inventarioRepositoryProvider),
  ),
);
