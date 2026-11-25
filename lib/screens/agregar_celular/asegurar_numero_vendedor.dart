import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../providers/repository_providers.dart';
import '../../providers/usuarios_providers.dart';
import '../../sincronizacion/sincronizacion_provider.dart';

/// Le da a [vendedor] su número si no lo tenía y lo sube a la nube: el número
/// recién dado debe llegar allá antes de que el vendedor lo escriba. Con
/// [sincronizar] sube aunque ya lo tuviera (p. ej. un vendedor recién creado).
/// Lanza el error de la nube si no llega.
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
    await ref.read(sincronizacionProvider.notifier).sincronizarAhora();
  }
  return numero;
}
