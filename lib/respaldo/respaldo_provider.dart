import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/database.dart';
import '../providers/database_provider.dart';
import '../providers/sesion_provider.dart';
import 'config_respaldo.dart';
import 'copia_base_datos.dart';
import 'nube_respaldo.dart';
import 'restaurador.dart';
import 'supabase_nube_respaldo.dart';

/// Espera tras el último cambio antes de respaldar (varios cambios seguidos
/// producen un solo respaldo).
const retardoRespaldo = Duration(seconds: 30);

/// Marca guardada en el celular: el usuario terminó de activar el respaldo
/// (resolvió si había uno previo). Sin ella, una sesión de Supabase no basta
/// para subir nada: así un flujo abandonado nunca pisa un respaldo bueno.
const claveRespaldoHabilitado = 'respaldo_habilitado';

enum FaseRespaldo { noConfigurado, desactivado, activo, requiereReconexion }

class EstadoRespaldo {
  const EstadoRespaldo({
    required this.fase,
    this.telefono,
    this.ultimoRespaldo,
    this.respaldando = false,
  });

  final FaseRespaldo fase;
  final String? telefono;
  final DateTime? ultimoRespaldo;
  final bool respaldando;

  EstadoRespaldo copiar({
    FaseRespaldo? fase,
    String? telefono,
    DateTime? ultimoRespaldo,
    bool? respaldando,
  }) {
    return EstadoRespaldo(
      fase: fase ?? this.fase,
      telefono: telefono ?? this.telefono,
      ultimoRespaldo: ultimoRespaldo ?? this.ultimoRespaldo,
      respaldando: respaldando ?? this.respaldando,
    );
  }
}

/// Preferencias del celular; se cargan en `main` antes de arrancar la app.
final preferenciasProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('preferenciasProvider se sobrescribe en main()');
});

/// La nube real, o null si la app se compiló sin claves de Supabase.
final nubeRespaldoProvider = Provider<NubeRespaldo?>((ref) {
  if (!ConfigRespaldo.configurado) return null;
  return SupabaseNubeRespaldo(Supabase.instance.client);
});

/// Crea una copia de la base actual lista para subir.
final copiadorProvider = Provider<Future<File> Function()>((ref) {
  final db = ref.watch(databaseProvider);
  return () async =>
      CopiaBaseDatos.crearCopia(db, await getTemporaryDirectory());
});

final restauradorProvider = Provider<Restaurador>((ref) {
  return Restaurador(
    archivoBase: archivoBaseDatos,
    directorioTemporal: getTemporaryDirectory,
  );
});

final respaldoProvider = NotifierProvider<RespaldoNotifier, EstadoRespaldo>(
  RespaldoNotifier.new,
);

class RespaldoNotifier extends Notifier<EstadoRespaldo> {
  Timer? _temporizador;
  bool _enCurso = false;
  bool _pendiente = false;

  NubeRespaldo? get _nube => ref.read(nubeRespaldoProvider);

  SharedPreferences get _preferencias => ref.read(preferenciasProvider);

  bool get _habilitado =>
      _preferencias.getBool(claveRespaldoHabilitado) ?? false;

  Future<void> _marcarHabilitado(bool habilitado) =>
      _preferencias.setBool(claveRespaldoHabilitado, habilitado);

  @override
  EstadoRespaldo build() {
    final nube = ref.watch(nubeRespaldoProvider);
    if (nube == null) {
      return const EstadoRespaldo(fase: FaseRespaldo.noConfigurado);
    }
    final cambios = ref
        .watch(databaseProvider)
        .tableUpdates()
        .listen((_) => _programar());
    ref.onDispose(() {
      cambios.cancel();
      _temporizador?.cancel();
    });
    if (!_habilitado) {
      // Sesión de un flujo de activación que no terminó: se descarta.
      if (nube.haySesion) unawaited(nube.cerrarSesion());
      return const EstadoRespaldo(fase: FaseRespaldo.desactivado);
    }
    if (!nube.haySesion) {
      return const EstadoRespaldo(fase: FaseRespaldo.requiereReconexion);
    }
    Future.microtask(_alAbrir);
    return EstadoRespaldo(
      fase: FaseRespaldo.activo,
      telefono: nube.telefonoConectado,
    );
  }

  Future<void> _alAbrir() async {
    try {
      final fecha = await _nube?.fechaUltimoRespaldo();
      if (fecha != null) state = state.copiar(ultimoRespaldo: fecha);
    } on ErrorSesionRespaldo {
      state = state.copiar(fase: FaseRespaldo.requiereReconexion);
      return;
    } catch (_) {
      // Sin internet: el respaldo de abajo también fallará en silencio.
    }
    await respaldarAhora();
  }

  void _programar() {
    if (!_habilitado) return;
    _temporizador?.cancel();
    _temporizador = Timer(retardoRespaldo, () => respaldarAhora());
  }

  /// Sube una copia de la base si el respaldo está habilitado. Devuelve true
  /// si quedó respaldada. Si ya hay un respaldo en curso, deja otro
  /// programado para cuando termine.
  Future<bool> respaldarAhora() async {
    final nube = _nube;
    if (nube == null || !_habilitado) return false;
    if (!nube.haySesion) {
      // La sesión venció o fue revocada (Supabase la cerró).
      state = state.copiar(fase: FaseRespaldo.requiereReconexion);
      return false;
    }
    if (_enCurso) {
      _pendiente = true;
      return false;
    }
    _enCurso = true;
    state = state.copiar(respaldando: true);
    try {
      final copia = await ref.read(copiadorProvider)();
      await nube.subir(copia);
      state = state.copiar(
        fase: FaseRespaldo.activo,
        telefono: nube.telefonoConectado,
        ultimoRespaldo: DateTime.now(),
        respaldando: false,
      );
      return true;
    } on ErrorSesionRespaldo {
      state = state.copiar(
        fase: FaseRespaldo.requiereReconexion,
        respaldando: false,
      );
      return false;
    } catch (_) {
      // Sin internet u otro error: se reintenta en el próximo cambio o al
      // abrir la app; no se molesta al usuario.
      state = state.copiar(respaldando: false);
      return false;
    } finally {
      _enCurso = false;
      if (_pendiente) {
        _pendiente = false;
        _programar();
      }
    }
  }

  Future<void> enviarCodigo(String telefonoE164) =>
      _nube!.enviarCodigo(telefonoE164);

  /// Verifica el código. Devuelve la fecha del respaldo que ya existía para
  /// ese número, o null si no hay. **No habilita el respaldo**: eso lo hace
  /// [activar] (o [restaurar]) cuando el usuario resuelve qué hacer. Si algo
  /// falla después de verificar, cierra la sesión para no dejarla colgando.
  Future<DateTime?> verificar(String telefonoE164, String codigo) async {
    final nube = _nube!;
    await nube.verificarCodigo(telefonoE164, codigo);
    final DateTime? fecha;
    try {
      fecha = await nube.fechaUltimoRespaldo();
    } catch (_) {
      await nube.cerrarSesion();
      rethrow;
    }
    state = EstadoRespaldo(
      fase: _habilitado ? FaseRespaldo.activo : FaseRespaldo.desactivado,
      telefono: nube.telefonoConectado ?? telefonoE164,
      ultimoRespaldo: fecha,
    );
    return fecha;
  }

  /// Habilita el respaldo (el usuario ya decidió) y sube la primera copia.
  Future<bool> activar() async {
    await _marcarHabilitado(true);
    state = state.copiar(fase: FaseRespaldo.activo);
    return respaldarAhora();
  }

  /// Cierra la sesión del respaldo y lo deshabilita. No borra el respaldo de
  /// la nube ni los datos locales.
  Future<void> desconectar() async {
    _temporizador?.cancel();
    await _marcarHabilitado(false);
    await _nube?.cerrarSesion();
    state = const EstadoRespaldo(fase: FaseRespaldo.desactivado);
  }

  /// Reemplaza la base local con el respaldo. Si lo logra, habilita el
  /// respaldo, cierra la sesión local (vuelve a "¿Quién eres?") y reabre la
  /// base. Si no hay respaldo, lo deja habilitado para la tienda que se cree;
  /// si el respaldo es inválido, se desconecta para no pisarlo.
  Future<ResultadoRestauracion> restaurar() async {
    _temporizador?.cancel();
    final ResultadoRestauracion resultado;
    try {
      resultado = await ref
          .read(restauradorProvider)
          .restaurar(_nube!, ref.read(databaseProvider));
    } catch (_) {
      // La base pudo quedar cerrada a mitad de camino: se reabre.
      ref.invalidate(databaseProvider);
      rethrow;
    }
    switch (resultado) {
      case ResultadoRestauracion.restaurado:
        await _marcarHabilitado(true);
        ref.read(sesionProvider.notifier).cerrarSesion();
        ref.invalidate(databaseProvider);
      case ResultadoRestauracion.sinRespaldo:
        await _marcarHabilitado(true);
      case ResultadoRestauracion.invalido:
        await desconectar();
    }
    return resultado;
  }
}
