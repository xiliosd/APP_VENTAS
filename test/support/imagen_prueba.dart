import 'dart:convert';
import 'dart:typed_data';

import 'package:app_ventas/screens/qr/selector_imagen.dart';

/// PNG válido de 1x1 px.
final Uint8List pngDePrueba = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==');

class SelectorImagenFalso implements SelectorImagen {
  SelectorImagenFalso({this.bytes, this.error});

  final Uint8List? bytes;
  final Object? error;

  @override
  Future<Uint8List?> elegir() async {
    if (error != null) throw error!;
    return bytes;
  }
}
