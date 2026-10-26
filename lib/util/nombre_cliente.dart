import '../data/database.dart';
import 'texto_util.dart';

extension NombreCliente on Cliente {
  /// "nombre apellido"; solo el nombre si no hay apellido.
  String get nombreCompleto {
    final apellidoLimpio = apellido?.trim() ?? '';
    return apellidoLimpio.isEmpty
        ? nombre.trim()
        : '${nombre.trim()} $apellidoLimpio';
  }
}

/// Forma de comparar y buscar clientes: sin mayúsculas, tildes ni espacios de más.
String claveCliente(String nombreCompleto) =>
    sinTildes(claveNombre(nombreCompleto));

/// Solo los dígitos del teléfono, sin el 57 inicial del país; null si no hay
/// dígitos. La validación del formato es del formulario.
String? telefonoNormalizado(String? texto) {
  final digitos = (texto ?? '').replaceAll(RegExp(r'\D'), '');
  if (digitos.isEmpty) return null;
  if (digitos.length == 12 && digitos.startsWith('57')) {
    return digitos.substring(2);
  }
  return digitos;
}
