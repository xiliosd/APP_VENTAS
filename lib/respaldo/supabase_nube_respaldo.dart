import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'nube_respaldo.dart';

/// [NubeRespaldo] sobre Supabase: Auth por teléfono (OTP) y Storage.
class SupabaseNubeRespaldo implements NubeRespaldo {
  SupabaseNubeRespaldo(this._cliente);

  final SupabaseClient _cliente;

  static const _bucket = 'respaldos';
  static const _archivo = 'app_ventas.sqlite';

  GoTrueClient get _auth => _cliente.auth;

  StorageFileApi get _storage => _cliente.storage.from(_bucket);

  String get _carpeta {
    final usuario = _auth.currentUser;
    if (usuario == null) throw const ErrorSesionRespaldo();
    return usuario.id;
  }

  @override
  bool get haySesion => _auth.currentSession != null;

  @override
  String? get telefonoConectado {
    final telefono = _auth.currentUser?.phone;
    if (telefono == null || telefono.isEmpty) return null;
    return telefono.startsWith('+') ? telefono : '+$telefono';
  }

  @override
  Future<void> enviarCodigo(String telefonoE164) =>
      _auth.signInWithOtp(phone: telefonoE164);

  @override
  Future<void> verificarCodigo(String telefonoE164, String codigo) async {
    try {
      await _auth.verifyOTP(
          phone: telefonoE164, token: codigo, type: OtpType.sms);
    } on AuthException catch (e) {
      throw ErrorCodigoRespaldo(e.message);
    }
  }

  @override
  Future<void> cerrarSesion() => _auth.signOut();

  @override
  Future<DateTime?> fechaUltimoRespaldo() => _conSesion(() async {
        final archivos = await _storage.list(path: _carpeta);
        for (final archivo in archivos) {
          if (archivo.name == _archivo && archivo.updatedAt != null) {
            return DateTime.parse(archivo.updatedAt!).toLocal();
          }
        }
        return null;
      });

  @override
  Future<void> subir(File copia) => _conSesion(() => _storage.upload(
        '$_carpeta/$_archivo',
        copia,
        fileOptions: const FileOptions(upsert: true),
      ));

  @override
  Future<void> descargar(File destino) => _conSesion(() async {
        final bytes = await _storage.download('$_carpeta/$_archivo');
        await destino.writeAsBytes(bytes, flush: true);
      });

  /// Traduce errores de sesión (401/403, token inválido) a
  /// [ErrorSesionRespaldo]; los demás (red) se propagan tal cual.
  Future<T> _conSesion<T>(Future<T> Function() accion) async {
    try {
      return await accion();
    } on AuthException {
      throw const ErrorSesionRespaldo();
    } on StorageException catch (e) {
      if (e.statusCode == '401' || e.statusCode == '403') {
        throw const ErrorSesionRespaldo();
      }
      rethrow;
    }
  }
}
