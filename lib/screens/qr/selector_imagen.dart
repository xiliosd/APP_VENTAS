import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

/// Elige una imagen y devuelve sus bytes, o null si no se eligió ninguna.
abstract class SelectorImagen {
  Future<Uint8List?> elegir();

  /// Imagen elegida justo antes de que Android cerrara la app, o null.
  Future<Uint8List?> recuperarPerdida();
}

/// Galería del celular; reduce la imagen a 1024 px como máximo.
class SelectorImagenGaleria implements SelectorImagen {
  SelectorImagenGaleria() {
    // El selector de fotos del sistema no depende de que el celular tenga
    // una app de galería; sin ella, la app se cerraba al cargar el QR.
    final plataforma = ImagePickerPlatform.instance;
    if (plataforma is ImagePickerAndroid) {
      plataforma.useAndroidPhotoPicker = true;
    }
  }

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

  @override
  Future<Uint8List?> recuperarPerdida() async {
    if (defaultTargetPlatform != TargetPlatform.android) return null;
    final respuesta = await ImagePicker().retrieveLostData();
    if (respuesta.isEmpty) return null;
    if (respuesta.exception != null) throw respuesta.exception!;
    return respuesta.file?.readAsBytes();
  }
}

final selectorImagenProvider =
    Provider<SelectorImagen>((ref) => SelectorImagenGaleria());
