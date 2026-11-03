import 'dart:math';

final _aleatorio = Random.secure();
var _ultimoMilisegundo = 0;
var _contador = 0;

/// Identificador UUID v7 en minúsculas (36 caracteres).
///
/// Cada celular numera sus filas 1, 2, 3…; en una tienda compartida esos
/// números chocan entre celulares. Este identificador es el que todos los
/// celulares de la tienda reconocen como el mismo registro al sincronizar.
///
/// Empieza con la hora en milisegundos y un contador, así que ordenarlos como
/// texto da el orden en que se crearon: sirve de desempate igual en todos los
/// celulares (p. ej. dos conteos del mismo producto en el mismo segundo). Los
/// 62 bits finales al azar evitan que dos celulares generen el mismo.
String generarIdGlobal() {
  var milisegundo = DateTime.now().millisecondsSinceEpoch;
  if (milisegundo <= _ultimoMilisegundo) {
    // Mismo milisegundo (o el reloj retrocedió): sigue el contador.
    milisegundo = _ultimoMilisegundo;
    _contador++;
    if (_contador > 0xfff) {
      milisegundo++;
      _contador = 0;
    }
  } else {
    _contador = 0;
  }
  _ultimoMilisegundo = milisegundo;

  final bytes = List<int>.filled(16, 0);
  for (var i = 0; i < 6; i++) {
    bytes[i] = (milisegundo >> (8 * (5 - i))) & 0xff;
  }
  bytes[6] = 0x70 | (_contador >> 8); // versión 7 + contador (12 bits)
  bytes[7] = _contador & 0xff;
  for (var i = 8; i < 16; i++) {
    bytes[i] = _aleatorio.nextInt(256);
  }
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // variante RFC 4122
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
