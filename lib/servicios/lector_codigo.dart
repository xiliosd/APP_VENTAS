import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../screens/escaner/escaner_screen.dart';

/// Obtiene un código de barras (cámara o escrito). Null si se canceló.
abstract class LectorCodigo {
  Future<String?> leer(BuildContext context);
}

/// Abre el escáner de cámara.
class LectorCamara implements LectorCodigo {
  @override
  Future<String?> leer(BuildContext context) => Navigator.of(context)
      .push<String>(MaterialPageRoute(builder: (_) => const EscanerScreen()));
}

final lectorCodigoProvider = Provider<LectorCodigo>((ref) => LectorCamara());
