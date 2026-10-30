import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../util/aviso_existencias.dart';
import 'repository_providers.dart';
import 'sesion_provider.dart';

/// Productos que llegaron a su mínimo con la última venta. Vive aparte de la
/// pantalla de venta porque esta se cierra al cobrar y el aviso debe verse en
/// el inicio.
class AvisoPorPedirNotifier extends Notifier<List<AvisoExistencias>> {
  @override
  List<AvisoExistencias> build() {
    // Otro usuario no debe ver el aviso de la venta de quien estuvo antes.
    ref.watch(sesionProvider.select((s) => s.usuarioActivo?.id));
    return const [];
  }

  void mostrar(List<AvisoExistencias> nuevos) {
    final porProducto = {for (final a in state) a.productoId: a};
    for (final a in nuevos) {
      porProducto[a.productoId] = a;
    }
    state = porProducto.values.toList();
  }

  void cerrar() => state = const [];

  /// Tras deshacer una venta, quita los productos que ya no están en el mínimo.
  Future<void> recalcular() async {
    state = await ref.read(inventarioRepositoryProvider).avisosVigentes(state);
  }
}

final avisoPorPedirProvider =
    NotifierProvider<AvisoPorPedirNotifier, List<AvisoExistencias>>(
      AvisoPorPedirNotifier.new,
    );
