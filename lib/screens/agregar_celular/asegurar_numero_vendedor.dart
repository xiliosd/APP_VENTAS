import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../providers/repository_providers.dart';
import '../../providers/usuarios_providers.dart';
import '../../sincronizacion/nube_tienda.dart';
import '../../sincronizacion/sincronizacion_provider.dart';

/// Le da a [vendedor] su número si no lo tenía y lo sube a la nube: el número
/// recién dado debe llegar allá antes de que el vendedor lo escriba. Con
/// [sincronizar] sube aunque ya lo tuviera (p. ej. un vendedor recién creado).
/// Lanza [ErrorSinConexion], [ErrorSesionTienda] o un [StateError] si el ciclo
/// de sincronización terminó sin dejar la tienda al día.
Future<int> asegurarNumeroVendedorEnNube(
  WidgetRef ref,
  Usuario vendedor, {
  bool sincronizar = false,
}) async {
  final teniaNumero = vendedor.numeroVendedor != null;
  final numero = await ref
      .read(usuarioRepositoryProvider)
      .asegurarNumeroVendedor(vendedor.id);
  ref.invalidate(listaUsuariosProvider);
  if (!teniaNumero || sincronizar) {
    final notificador = ref.read(sincronizacionProvider.notifier);
    await notificador.sincronizarAhora();
    // sincronizarAhora no lanza: deja el resultado en la fase del estado. Si ya
    // había un ciclo en curso, espera a la repetición que dejó en cola, así la
    // fase es la de un ciclo que empezó después del número nuevo.
    switch (ref.read(sincronizacionProvider).fase) {
      case FaseSincronizacion.sinConexion:
        throw const ErrorSinConexion();
      case FaseSincronizacion.requiereReconexion:
        throw const ErrorSesionTienda();
      case FaseSincronizacion.error ||
          FaseSincronizacion.actualizarApp ||
          FaseSincronizacion.noCompartida:
        throw StateError('No se pudo subir el número del vendedor');
      case FaseSincronizacion.alDia || FaseSincronizacion.sincronizando:
        break;
    }
  }
  return numero;
}
