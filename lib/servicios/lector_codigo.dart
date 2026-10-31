import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../screens/escaner/escaner_screen.dart';
import 'uso_escaner.dart';

export 'uso_escaner.dart';

/// Obtiene un código de barras (cámara o escrito). Null si se canceló.
abstract class LectorCodigo {
  Future<String?> leer(
    BuildContext context, {
    UsoEscaner uso = UsoEscaner.venta,
  });
}

/// Abre el escáner de cámara.
class LectorCamara implements LectorCodigo {
  @override
  Future<String?> leer(
    BuildContext context, {
    UsoEscaner uso = UsoEscaner.venta,
  }) => Navigator.of(context)
      .push<String>(MaterialPageRoute(builder: (_) => EscanerScreen(uso: uso)));
}

final lectorCodigoProvider = Provider<LectorCodigo>((ref) => LectorCamara());
