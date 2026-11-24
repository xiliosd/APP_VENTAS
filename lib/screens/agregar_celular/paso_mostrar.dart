import 'package:flutter/material.dart';

import '../../data/database.dart';

/// Paso 3 del asistente: lo que el vendedor necesita para entrar. Provisional;
/// la pantalla completa llega en la siguiente tarea.
class PasoMostrar extends StatelessWidget {
  const PasoMostrar({
    super.key,
    required this.vendedor,
    required this.cambiaCelular,
  });

  final Usuario vendedor;
  final bool cambiaCelular;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
