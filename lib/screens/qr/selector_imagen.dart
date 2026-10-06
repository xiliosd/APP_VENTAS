import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// Elige una imagen y devuelve sus bytes, o null si no se eligió ninguna.
abstract class SelectorImagen {
  Future<Uint8List?> elegir();
}

/// Galería del celular; reduce la imagen a 1024 px como máximo.
class SelectorImagenGaleria implements SelectorImagen {
  @override
  Future<Uint8List?> elegir() async {
    final archivo = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    return archivo?.readAsBytes();
  }
}

final selectorImagenProvider =
    Provider<SelectorImagen>((ref) => SelectorImagenGaleria());
