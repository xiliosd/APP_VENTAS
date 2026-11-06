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

  @override
  Future<void> iniciarSesionCelular() async {
    if (_cliente.auth.currentUser != null) return;
    try {
      await _cliente.auth.signInAnonymously();
    } catch (error) {
      throw traducirErrorTienda(error);
    }
  }

  @override
  Future<void> cerrarSesionCelular() async {
    try {
      await _cliente.auth.signOut(scope: SignOutScope.local);
    } catch (_) {
      // Sin internet la sesión local igual se borra.
    }
  }

  @override
  Future<String> codigoTienda(String tiendaId) => _conSesion(
    () async =>
        await _cliente.rpc('codigo_tienda', params: {'p_tienda': tiendaId})
            as String,
  );

  @override
  Future<SolicitudIngreso> solicitarIngreso(
    String codigo,
    int numeroVendedor,
    String pin,
    String nombreCelular,
  ) => _conSesion(() async {
    final respuesta = await _cliente.rpc(
      'solicitar_ingreso',
      params: {
        'p_codigo': codigo,
        'p_numero': numeroVendedor,
        'p_pin': pin,
        'p_celular': nombreCelular,
      },
    );
    return SolicitudIngreso.desdeJson(
      (respuesta as Map).cast<String, Object?>(),
    );
  });

  @override
  Future<Membresia?> miMembresia() => _conSesion(() async {
    final respuesta = await _cliente.rpc('mi_membresia');
    if (respuesta == null) return null;
    return Membresia.desdeJson((respuesta as Map).cast<String, Object?>());
  });

  @override
  Future<List<CelularTienda>> celulares(String tiendaId) => _conSesion(
    () async {
      final miembros = await _cliente
          .from('miembros')
          .select(
            'usuario_id, rol, estado, usuario_id_global, nombre_celular, '
            'solicitado_en',
          )
          .eq('tienda_id', tiendaId)
          .order('solicitado_en');
      final ids = [
        for (final m in miembros)
          if (m['usuario_id_global'] != null) m['usuario_id_global'] as String,
      ];
      final nombres = <String, String>{};
      if (ids.isNotEmpty) {
        final usuarios = await _cliente
            .from('filas')
            .select('id_global, datos')
            .eq('tienda_id', tiendaId)
            .eq('tabla', 'usuarios')
            .inFilter('id_global', ids);
        for (final fila in usuarios) {
          final nombre = (fila['datos'] as Map?)?['nombre'];
          if (nombre is String) nombres[fila['id_global'] as String] = nombre;
        }
      }
      return [
        for (final m in miembros)
          CelularTienda(
            usuarioAuth: m['usuario_id'] as String,
            rol: m['rol'] as String,
            estado: estadoMiembroDesde(m['estado'] as String?),
            solicitadoEn: DateTime.parse(m['solicitado_en'] as String),
            nombreCelular: m['nombre_celular'] as String?,
            usuarioIdGlobal: m['usuario_id_global'] as String?,
            nombreVendedor: nombres[m['usuario_id_global']],
          ),
      ];
    },
  );

  @override
  Future<List<CelularTienda>> solicitudes(String tiendaId) async => [
    for (final celular in await celulares(tiendaId))
      if (celular.rol == 'vendedor' &&
          celular.estado == EstadoMiembro.pendiente)
        celular,
  ];

  @override
  Future<void> responderSolicitud(
    String tiendaId,
    String usuarioAuth, {
    required bool aprobar,
  }) => _conSesion(
    () => _cliente.rpc(
      'responder_solicitud',
      params: {
        'p_tienda': tiendaId,
        'p_usuario': usuarioAuth,
        'p_aprobar': aprobar,
      },
    ),
  );

  @override
  Future<void> revocarCelular(String tiendaId, String usuarioAuth) =>
      _conSesion(
        () => _cliente.rpc(
          'revocar_celular',
          params: {'p_tienda': tiendaId, 'p_usuario': usuarioAuth},
        ),
      );

  @override
  Future<void> desactivarVendedor(String tiendaId, String idGlobal) =>
      _conSesion(
        () => _cliente.rpc(
          'desactivar_vendedor',
          params: {'p_tienda': tiendaId, 'p_id_global': idGlobal},
        ),
      );

  @override
  Future<void> guardarPin(
    String tiendaId,
    String idGlobal,
    String pin,
    int version,
  ) => _conSesion(
    () => _cliente.rpc(
      'guardar_pin',
      params: {
        'p_tienda': tiendaId,
        'p_id_global': idGlobal,
        'p_pin': pin,
        'p_version': version,
      },
    ),
  );

  @override
  Future<void> guardarPinLegado(
    String tiendaId,
    String idGlobal,
    String hash,
    int version,
  ) => _conSesion(
    () => _cliente.rpc(
      'guardar_pin_legado',
      params: {
        'p_tienda': tiendaId,
        'p_id_global': idGlobal,
        'p_hash': hash,
        'p_version': version,
      },
    ),
  );

  @override
  Future<List<String>> pinesFaltantes(String tiendaId) => _conSesion(() async {
    final respuesta = await _cliente.rpc(
      'pines_faltantes',
      params: {'p_tienda': tiendaId},
    );
    return [for (final id in respuesta as List) id as String];
  });

  @override
  Future<ResultadoPin> verificarPin(
    String tiendaId,
    String idGlobal,
    String pin,
  ) => _conSesion(() async {
    final respuesta = await _cliente.rpc(
      'verificar_pin',
      params: {'p_tienda': tiendaId, 'p_id_global': idGlobal, 'p_pin': pin},
    );
    return resultadoPinDesde(respuesta as String?);
  });

  @override
  Future<int> entregarPendientes(List<CambioSubida> cambios) =>
      _conSesion(() async {
        final respuesta = await _cliente.rpc(
          'entregar_pendientes',
          params: {
            'p_filas': [
              for (final cambio in cambios)
                {
                  'tabla': cambio.tabla,
                  'id_global': cambio.idGlobal,
                  'datos': cambio.datos,
                },
            ],
          },
        );
        return respuesta as int;
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
