import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../respaldo/config_respaldo.dart';
import 'nube_tienda.dart';

/// La tienda compartida en Supabase (tablas de
/// `supabase/migrations/20261103000000_tienda_compartida.sql`). Usa la misma
/// sesión por correo que el respaldo.
class SupabaseNubeTienda implements NubeTienda {
  SupabaseNubeTienda(this._cliente);

  final SupabaseClient _cliente;

  @override
  Future<String> crearTienda(String nombre) => _conSesion(
    () async =>
        await _cliente.rpc('crear_tienda', params: {'p_nombre': nombre})
            as String,
  );

  @override
  Future<String?> miTienda() =>
      _conSesion(() async => await _cliente.rpc('mi_tienda') as String?);

  @override
  Future<int> versionProtocoloMinima() => _conSesion(() async {
    final fila = await _cliente
        .from('configuracion_app')
        .select('valor')
        .eq('clave', 'version_protocolo_minima')
        .maybeSingle();
    return int.tryParse(fila?['valor'] as String? ?? '') ?? 1;
  });

  @override
  Future<void> subir(String tiendaId, List<CambioSubida> cambios) =>
      _conSesion(() async {
        if (cambios.isEmpty) return;
        await _cliente.from('filas').upsert([
          for (final cambio in cambios)
            {
              'tienda_id': tiendaId,
              'tabla': cambio.tabla,
              'id_global': cambio.idGlobal,
              'datos': cambio.datos,
              'borrado': cambio.borrado,
            },
        ], onConflict: 'tienda_id,tabla,id_global');
      });

  @override
  Future<List<FilaNube>> bajar(
    String tiendaId, {
    required int desde,
    int limite = 500,
  }) => _conSesion(() async {
    final filas = await _cliente
        .from('filas')
        .select('tabla, id_global, datos, borrado, version')
        .eq('tienda_id', tiendaId)
        .gt('version', desde)
        .order('version')
        .limit(limite);
    return [
      for (final fila in filas)
        FilaNube(
          tabla: fila['tabla'] as String,
          idGlobal: fila['id_global'] as String,
          datos: (fila['datos'] as Map?)?.cast<String, Object?>(),
          borrado: fila['borrado'] as bool,
          version: fila['version'] as int,
        ),
    ];
  });

  Future<T> _conSesion<T>(Future<T> Function() accion) async {
    if (_cliente.auth.currentUser == null) throw const ErrorSesionTienda();
    try {
      return await accion();
    } catch (error) {
      throw traducirErrorTienda(error);
    }
  }
}

/// Convierte los errores de red y de sesión de Supabase en los de
/// [NubeTienda]; los demás pasan igual.
Object traducirErrorTienda(Object error) {
  if (error is SocketException ||
      error is TimeoutException ||
      // `ClientException` de `http` (dependencia indirecta, sin importarla).
      error.runtimeType.toString() == 'ClientException' ||
      error is AuthRetryableFetchException) {
    return const ErrorSinConexion();
  }
  if (error is AuthException) return const ErrorSesionTienda();
  if (error is PostgrestException &&
      (error.code == 'PGRST301' ||
          error.code == '401' ||
          error.message.contains('JWT'))) {
    return const ErrorSesionTienda();
  }
  return error;
}

/// La nube de la tienda compartida, o null si la app se compiló sin claves.
final nubeTiendaProvider = Provider<NubeTienda?>((ref) {
  if (!ConfigRespaldo.configurado) return null;
  return SupabaseNubeTienda(Supabase.instance.client);
});
