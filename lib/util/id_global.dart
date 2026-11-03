import 'dart:math';

final _aleatorio = Random.secure();

/// Identificador UUID v4 en minúsculas (36 caracteres).
///
/// Cada celular numera sus filas 1, 2, 3…; en una tienda compartida esos
/// números chocan entre celulares. Este identificador es el que todos los
/// celulares de la tienda reconocen como el mismo registro al sincronizar.
String generarIdGlobal() {
  final bytes = List<int>.generate(16, (_) => _aleatorio.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // versión 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // variante RFC 4122
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
