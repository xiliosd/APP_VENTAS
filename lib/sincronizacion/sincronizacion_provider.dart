import 'dart:async';

import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/database_provider.dart';
import '../providers/huella_provider.dart';
import '../providers/sesion_provider.dart';
import 'nube_tienda.dart';
import 'sincronizador.dart';
import 'supabase_nube_tienda.dart';

/// Espera tras el último cambio local antes de sincronizar (varios cambios
/// seguidos, como una venta con sus líneas, van en un solo ciclo).
final retardoSincronizacionProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 5),
);

/// Cada cuánto se revisa la nube con la app abierta, para ver lo que hizo el
/// otro celular aunque este no cambie nada.
final intervaloSincronizacionProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 60),
);

enum FaseSincronizacion {
  noCompartida,
  alDia,
  sincronizando,
  sinConexion,
  actualizarApp,
  requiereReconexion,
}

class EstadoTiendaCompartida {
  const EstadoTiendaCompartida({
    required this.fase,
    this.ultimaSincronizacion,
    this.pendientes = 0,
  });

  final FaseSincronizacion fase;
  final DateTime? ultimaSincronizacion;

  /// Cambios de este celular que aún no llegan a la nube.
  final int pendientes;
}

/// El sincronizador de este celular, o null si la app no tiene nube.
final sincronizadorProvider = Provider<Sincronizador?>((ref) {
  final nube = ref.watch(nubeTiendaProvider);
  if (nube == null) return null;
  return Sincronizador(ref.watch(databaseProvider), nube);
});

final sincronizacionProvider =
    NotifierProvider<SincronizacionNotifier, EstadoTiendaCompartida>(
      SincronizacionNotifier.new,
    );

class SincronizacionNotifier extends Notifier<EstadoTiendaCompartida> {
  Timer? _espera;
  bool _enCurso = false;
  bool _otraVez = false;

  Sincronizador? get _sincronizador => ref.read(sincronizadorProvider);

  @override
  EstadoTiendaCompartida build() {
    final sincronizador = ref.watch(sincronizadorProvider);
    const inicial = EstadoTiendaCompartida(
      fase: FaseSincronizacion.noCompartida,
    );
    if (sincronizador == null) return inicial;
    final db = ref.watch(databaseProvider);
    // Drift no ve lo que escriben los disparadores en `cambios_pendientes`:
    // se escucha cualquier tabla de datos. Las dos de la sincronización se
    // ignoran, o cada ciclo (que las escribe) programaría otro sin fin.
    const internas = {'cambios_pendientes', 'estado_sincronizacion'};
    final cambios = db.tableUpdates().listen((actualizadas) {
      if (actualizadas.any((t) => !internas.contains(t.table))) _programar();
    });
    final periodico = Timer.periodic(
      ref.watch(intervaloSincronizacionProvider),
      (_) => unawaited(sincronizarAhora()),
    );
    final ciclo = AppLifecycleListener(
      onResume: () => unawaited(sincronizarAhora()),
    );
    ref.onDispose(() {
      cambios.cancel();
      periodico.cancel();
      ciclo.dispose();
      _espera?.cancel();
    });
    Future.microtask(sincronizarAhora);
    return inicial;
  }

  void _programar() {
    // Los borrados de la propia subida también avisan: se ignoran.
    if (_enCurso) return;
    _espera?.cancel();
    _espera = Timer(
      ref.read(retardoSincronizacionProvider),
      () => unawaited(sincronizarAhora()),
    );
  }

  /// Un ciclo de sincronización si la tienda es compartida. Si ya hay uno en
  /// curso, deja otro para cuando termine.
  Future<void> sincronizarAhora() async {
    final sincronizador = _sincronizador;
    if (sincronizador == null) return;
    if (_enCurso) {
      _otraVez = true;
      return;
    }
    _enCurso = true;
    try {
      if (!await sincronizador.esCompartida()) {
        state = const EstadoTiendaCompartida(
          fase: FaseSincronizacion.noCompartida,
        );
        return;
      }
      state = EstadoTiendaCompartida(
        fase: FaseSincronizacion.sincronizando,
        ultimaSincronizacion: state.ultimaSincronizacion,
        pendientes: state.pendientes,
      );
      final FaseSincronizacion fase;
      try {
        fase = switch (await sincronizador.sincronizar()) {
          ResultadoSincronizacion.alDia => FaseSincronizacion.alDia,
          ResultadoSincronizacion.sinConexion => FaseSincronizacion.sinConexion,
          ResultadoSincronizacion.actualizarApp =>
            FaseSincronizacion.actualizarApp,
          ResultadoSincronizacion.sesionVencida =>
            FaseSincronizacion.requiereReconexion,
          ResultadoSincronizacion.noCompartida =>
            FaseSincronizacion.noCompartida,
        };
      } catch (_) {
        // Error inesperado (p. ej. datos de la nube incompletos): se reintenta
        // en el siguiente ciclo sin molestar mientras se vende.
        state = EstadoTiendaCompartida(
          fase: FaseSincronizacion.sinConexion,
          ultimaSincronizacion: state.ultimaSincronizacion,
          pendientes: await sincronizador.cuantosPendientes(),
        );
        return;
      }
      state = EstadoTiendaCompartida(
        fase: fase,
        ultimaSincronizacion: await sincronizador.ultimaSincronizacion(),
        pendientes: await sincronizador.cuantosPendientes(),
      );
    } finally {
      _enCurso = false;
      if (_otraVez) {
        _otraVez = false;
        unawaited(sincronizarAhora());
      }
    }
  }

  /// Sube la tienda de este celular a la nube y la deja compartida.
  Future<void> compartirTienda() async {
    final sincronizador = _sincronizador!;
    final db = ref.read(databaseProvider);
    final configuracion = await db
        .select(db.configuracionTienda)
        .getSingleOrNull();
    await sincronizador.convertirEnCompartida(
      configuracion?.nombreTienda ?? '',
    );
    await sincronizarAhora();
  }

  /// Si esta versión de la app puede compartir la tienda (tiene nube).
  bool get disponible => _sincronizador != null;

  Future<bool> esCompartida() async =>
      await _sincronizador?.esCompartida() ?? false;

  /// La tienda compartida del correo con sesión, o null si no tiene.
  Future<String?> tiendaDelCorreo() async =>
      ref.read(nubeTiendaProvider)?.miTienda();

  /// Baja la tienda compartida [tiendaId] a este celular. Con
  /// [reemplazarDatos] primero borra los datos que tenga.
  Future<void> descargarTienda(
    String tiendaId, {
    bool reemplazarDatos = false,
  }) async {
    final sincronizador = _sincronizador!;
    // Los ids locales cambian: ninguna huella debe apuntar a otra persona.
    await ref.read(usuariosConHuellaProvider.notifier).borrarTodas();
    if (reemplazarDatos) await sincronizador.vaciarBase();
    await sincronizador.descargarTienda(tiendaId);
    ref.read(sesionProvider.notifier).cerrarSesion();
    await sincronizarAhora();
  }
}

/// Mensaje para el usuario de un error al compartir o descargar la tienda.
String mensajeErrorTienda(Object error) => switch (error) {
  ErrorSinConexion() => 'Sin internet. Inténtalo cuando tengas conexión.',
  ErrorSesionTienda() =>
    'La sesión venció. Vuelve a entrar con el código del correo.',
  _ => 'No se pudo completar. Inténtalo de nuevo.',
};
