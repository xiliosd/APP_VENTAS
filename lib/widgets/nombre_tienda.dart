import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/configuracion_providers.dart';

/// El nombre de la tienda en una línea; nada si aún no tiene nombre.
class NombreTienda extends ConsumerWidget {
  const NombreTienda({super.key, this.estilo, this.espacioAbajo = 0});

  final TextStyle? estilo;

  /// Espacio debajo, solo cuando hay nombre.
  final double espacioAbajo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nombre = ref.watch(nombreTiendaProvider).valueOrNull;
    if (nombre == null) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(bottom: espacioAbajo),
      child: Text(
        nombre,
        key: const Key('nombre_tienda'),
        style: estilo,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
