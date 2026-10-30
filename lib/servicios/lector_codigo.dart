import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../screens/escaner/escaner_screen.dart';

/// Para qué se abre el escáner: decide el texto de ayuda y si se ofrece
/// seguir sin cámara (en el recorrido, donde no siempre hay un código a mano).
enum UsoEscaner {
  venta,
  practica,
  producto,
  primerosProductos;

  static const _ayudaVenta =
      'Si el código no existe, te ofrezco crearlo; si existe, lo sumo a la venta';

  /// Qué pasará con el código leído, dicho en palabras de tendero.
  String get ayuda => switch (this) {
    venta || practica => _ayudaVenta,
    producto => 'Si conozco el código, lo lleno por ti',
    primerosProductos => 'Si el código no existe, te ofrezco crearlo',
  };

  /// Solo el recorrido deja avanzar sin leer nada.
  bool get conSeguirSinCamara =>
      this == UsoEscaner.practica || this == UsoEscaner.primerosProductos;
}

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
