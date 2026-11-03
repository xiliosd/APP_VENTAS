import 'dart:io';

/// Dónde se guarda el respaldo y cómo se identifica la tienda. La app solo
/// conoce esta interfaz; la implementación real es Supabase.
abstract class NubeRespaldo {
  bool get haySesion;

  /// Correo conectado, o null sin sesión.
  String? get correoConectado;

  /// Envía al [correo] un código de un solo uso para entrar.
  Future<void> enviarCodigo(String correo);

  /// Lanza [ErrorCodigoRespaldo] si el código es incorrecto o venció.
  Future<void> verificarCodigo(String correo, String codigo);

  Future<void> cerrarSesion();

  /// Fecha del respaldo guardado para esta tienda, o null si no hay.
  Future<DateTime?> fechaUltimoRespaldo();

  /// Reemplaza el respaldo de la tienda con [copia].
  Future<void> subir(File copia);

  /// Escribe el respaldo de la tienda en [destino].
  Future<void> descargar(File destino);
}

/// La sesión del respaldo venció o fue revocada: hay que verificar de nuevo.
class ErrorSesionRespaldo implements Exception {
  const ErrorSesionRespaldo();
}

/// El código de verificación es incorrecto o venció.
class ErrorCodigoRespaldo implements Exception {
  const ErrorCodigoRespaldo(this.mensaje);

  final String mensaje;
}
