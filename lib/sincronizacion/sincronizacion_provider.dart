import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/database_provider.dart';
import '../providers/aviso_por_pedir_provider.dart';
import '../providers/consejos_provider.dart';
import '../providers/huella_provider.dart';
import '../providers/preferencias_provider.dart';
import '../providers/recorrido_provider.dart';
import '../providers/repository_providers.dart';
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

/// Tienda a la que este celular pidió entrar como vendedor y aún espera la
/// aprobación. Mientras exista, la raíz muestra "Esperando aprobación".
const claveSolicitudPendiente = 'solicitud_tienda_pendiente';

/// Cada cuánto el celular que espera pregunta si ya lo aprobaron.
final intervaloSolicitudProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 5),
);

/// Cómo ve el admin a este celular en la lista de solicitudes.
final nombreCelularProvider = Provider<String>(
  (ref) => Platform.isAndroid ? 'Celular Android' : 'Celular',
);

final solicitudPendienteProvider =
    NotifierProvider<SolicitudPendienteNotifier, String?>(
      SolicitudPendienteNotifier.new,
    );

class SolicitudPendienteNotifier extends Notifier<String?> {
  @override
  String? build() =>
      ref.watch(preferenciasProvider).getString(claveSolicitudPendiente);

  Future<void> guardar(String tiendaId) async {
    state = tiendaId;
    await ref
        .read(preferenciasProvider)
        .setString(claveSolicitudPendiente, tiendaId);
  }

  Future<void> borrar() async {
    state = null;
    await ref.read(preferenciasProvider).remove(claveSolicitudPendiente);
  }
}

enum FaseSincronizacion {
  noCompartida,
  alDia,
  sincronizando,
  sinConexion,
  actualizarApp,
  requiereReconexion,

  /// Falla que no es de internet ni de sesión: se reintenta en el siguiente
  /// ciclo.
  error,
}

class EstadoTiendaCompartida {
  const EstadoTiendaCompartida({
    required this.fase,
    this.ultimaSincronizacion,
    this.pendientes = 0,
    this.solicitudes = const [],
    this.revocada = false,
  });

  final FaseSincronizacion fase;
  final DateTime? ultimaSincronizacion;

  /// Cambios de este celular que aún no llegan a la nube.
  final int pendientes;

  /// Celulares de vendedores que esperan que el admin los apruebe (solo en
  /// el celular del admin).
  final List<CelularTienda> solicitudes;

  /// El administrador le quitó el acceso a este celular y su copia de la
  /// tienda se borró: la raíz lo avisa y vuelve a la bienvenida.
  final bool revocada;

  EstadoTiendaCompartida copiar({
    FaseSincronizacion? fase,
    DateTime? ultimaSincronizacion,
    int? pendientes,
    List<CelularTienda>? solicitudes,
  }) => EstadoTiendaCompartida(
    fase: fase ?? this.fase,
    ultimaSincronizacion: ultimaSincronizacion ?? this.ultimaSincronizacion,
    pendientes: pendientes ?? this.pendientes,
    solicitudes: solicitudes ?? this.solicitudes,
  );
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
      state = state.copiar(fase: FaseSincronizacion.sincronizando);
      final FaseSincronizacion fase;
      final ResultadoSincronizacion resultado;
      try {
        resultado = await sincronizador.sincronizar();
        fase = switch (resultado) {
          ResultadoSincronizacion.alDia => FaseSincronizacion.alDia,
          ResultadoSincronizacion.sinConexion => FaseSincronizacion.sinConexion,
          ResultadoSincronizacion.actualizarApp =>
            FaseSincronizacion.actualizarApp,
          ResultadoSincronizacion.sesionVencida =>
            FaseSincronizacion.requiereReconexion,
          ResultadoSincronizacion.noCompartida ||
          ResultadoSincronizacion.revocada => FaseSincronizacion.noCompartida,
        };
        if (resultado == ResultadoSincronizacion.revocada) {
          await _olvidarTienda();
          state = const EstadoTiendaCompartida(
            fase: FaseSincronizacion.noCompartida,
            revocada: true,
          );
          return;
        }
      } catch (_) {
        // Error inesperado (p. ej. del servidor): se reintenta en el
        // siguiente ciclo sin molestar mientras se vende.
        state = state.copiar(
          fase: FaseSincronizacion.error,
          pendientes: await sincronizador.cuantosPendientes(),
        );
        return;
      }
      // Lo que vendió otro celular también avisa "toca pedir" aquí.
      if (fase == FaseSincronizacion.alDia &&
          sincronizador.avisosBajados.isNotEmpty) {
        try {
          await ref
              .read(avisoPorPedirProvider.notifier)
              .trasVenta(sincronizador.avisosBajados);
        } catch (_) {}
      }
      state = EstadoTiendaCompartida(
        fase: fase,
        ultimaSincronizacion: await sincronizador.ultimaSincronizacion(),
        pendientes: await sincronizador.cuantosPendientes(),
        solicitudes: fase == FaseSincronizacion.alDia
            ? sincronizador.solicitudes
            : state.solicitudes,
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

  /// Guarda en la nube el PIN del usuario [idGlobal] (con la tienda
  /// compartida). Lanza [ErrorSinConexion] sin internet: el PIN no se debe
  /// cambiar en este celular si no llegó a la nube.
  Future<void> guardarPinEnTienda({
    required String idGlobal,
    required String pin,
    required int version,
  }) async {
    final sincronizador = _sincronizador;
    final tiendaId = await sincronizador?.tiendaId();
    if (sincronizador == null || tiendaId == null) return;
    await sincronizador.nube.guardarPin(tiendaId, idGlobal, pin, version);
  }

  /// Tras perder el acceso: este celular olvida todo lo de la tienda (las
  /// huellas, el recorrido, los consejos y la sesión en la nube).
  Future<void> _olvidarTienda() async {
    await ref.read(usuariosConHuellaProvider.notifier).borrarTodas();
    final preferencias = ref.read(preferenciasProvider);
    await preferencias.remove(claveRecorrido);
    await preferencias.remove(claveRecorridoVendedor);
    for (final consejo in Consejo.values) {
      await preferencias.remove(ConsejosVistos.claveConsejo(consejo));
    }
    ref
      ..invalidate(recorridoProvider)
      ..invalidate(recorridoVendedorProvider)
      ..invalidate(consejosVistosProvider);
    await ref.read(solicitudPendienteProvider.notifier).borrar();
    await ref.read(nubeTiendaProvider)?.cerrarSesionCelular();
    ref.read(sesionProvider.notifier).cerrarSesion();
    ref.invalidate(haySesionUsuariosProvider);
  }

  /// Quita el acceso a todos los celulares de ese vendedor y bloquea su PIN
  /// en la nube. Lanza [ErrorSinConexion] sin internet.
  Future<void> desactivarVendedor(String idGlobal) async =>
      _sincronizador!.nube.desactivarVendedor(await _tiendaActual(), idGlobal);

  Future<String> _tiendaActual() async =>
      (await _sincronizador!.tiendaId()) ??
      (throw StateError('La tienda no es compartida'));

  /// El código que el admin le dicta al vendedor.
  Future<String> codigoTienda() async =>
      _sincronizador!.nube.codigoTienda(await _tiendaActual());

  /// Todos los celulares de la tienda (para el admin).
  Future<List<CelularTienda>> celulares() async =>
      _sincronizador!.nube.celulares(await _tiendaActual());

  Future<void> responderSolicitud(
    CelularTienda solicitud, {
    required bool aprobar,
  }) async {
    await _sincronizador!.nube.responderSolicitud(
      await _tiendaActual(),
      solicitud.usuarioAuth,
      aprobar: aprobar,
    );
    state = state.copiar(
      solicitudes: [
        for (final otra in state.solicitudes)
          if (otra.usuarioAuth != solicitud.usuarioAuth) otra,
      ],
    );
  }

  /// Le quita el acceso a un celular de vendedor: en su siguiente ciclo
  /// entrega lo pendiente y borra la tienda.
  Future<void> revocarCelular(String usuarioAuth) async =>
      _sincronizador!.nube.revocarCelular(await _tiendaActual(), usuarioAuth);

  /// El PIN escrito al pedir entrada, para guardarlo al bajar la tienda. Solo
  /// en memoria: si la app se cierra, el primer ingreso se revisa en línea.
  String? _pinSolicitud;

  /// Pide entrar a una tienda como vendedor desde este celular.
  Future<SolicitudIngreso> unirse({
    required String codigo,
    required int numeroVendedor,
    required String pin,
  }) async {
    final nube = ref.read(nubeTiendaProvider)!;
    await nube.iniciarSesionCelular();
    final respuesta = await nube.solicitarIngreso(
      codigo,
      numeroVendedor,
      pin,
      ref.read(nombreCelularProvider),
    );
    if (respuesta.resultado == ResultadoPin.ok) {
      _pinSolicitud = pin;
      await ref
          .read(solicitudPendienteProvider.notifier)
          .guardar(respuesta.tiendaId!);
    }
    return respuesta;
  }

  /// Pregunta por la solicitud de este celular. Si la aprobaron, baja la
  /// tienda; si no (o ya no existe), deja de esperar y cierra la sesión.
  /// Devuelve el estado (pendiente, aprobado o rechazado).
  Future<EstadoMiembro?> revisarSolicitud() async {
    final tiendaId = ref.read(solicitudPendienteProvider);
    final nube = ref.read(nubeTiendaProvider);
    if (tiendaId == null || nube == null) return null;
    final membresia = await nube.miMembresia();
    if (membresia == null ||
        membresia.tiendaId != tiendaId ||
        membresia.estado == EstadoMiembro.rechazado ||
        membresia.estado == EstadoMiembro.revocado) {
      await cancelarSolicitud();
      return EstadoMiembro.rechazado;
    }
    if (membresia.estado == EstadoMiembro.pendiente) {
      return EstadoMiembro.pendiente;
    }
    // Si la app se cerró justo después de bajar la tienda, ya está aquí:
    // bajarla otra vez fallaría ("el celular ya tiene una tienda") y el
    // celular se quedaría esperando para siempre.
    final db = ref.read(databaseProvider);
    final yaBajada =
        await _sincronizador?.tiendaId() == tiendaId &&
        (await db.select(db.usuarios).get()).isNotEmpty;
    if (!yaBajada) await descargarTienda(tiendaId);
    await ref.read(recorridoVendedorProvider.notifier).marcarPendiente();
    final pin = _pinSolicitud;
    final idGlobal = membresia.usuarioIdGlobal;
    if (pin != null && idGlobal != null) {
      final vendedor = await (db.select(
        db.usuarios,
      )..where((u) => u.idGlobal.equals(idGlobal))).getSingleOrNull();
      if (vendedor != null) {
        await ref
            .read(usuarioRepositoryProvider)
            .guardarPinLocal(vendedor.id, pin);
      }
    }
    _pinSolicitud = null;
    await ref.read(solicitudPendienteProvider.notifier).borrar();
    return EstadoMiembro.aprobado;
  }

  /// Deja de esperar la aprobación y cierra la sesión de este celular.
  Future<void> cancelarSolicitud() async {
    _pinSolicitud = null;
    // Una descarga cortada deja el estado de la tienda sin datos: se borra
    // para que el celular quede como nuevo.
    final sincronizador = _sincronizador;
    final db = ref.read(databaseProvider);
    if (sincronizador != null &&
        await sincronizador.esCompartida() &&
        (await db.select(db.usuarios).get()).isEmpty) {
      await sincronizador.vaciarBase();
    }
    await ref.read(solicitudPendienteProvider.notifier).borrar();
    await ref.read(nubeTiendaProvider)?.cerrarSesionCelular();
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
    // La raíz decide entre "Bienvenida" y "¿Quién eres?" con esta consulta,
    // que se hace una sola vez: sin repetirla seguiría en la bienvenida.
    ref.invalidate(haySesionUsuariosProvider);
    await sincronizarAhora();
  }
}

/// Al crear un usuario o cambiar un PIN en la tienda compartida sin internet.
const mensajeSinInternetPin =
    'Necesitas internet para guardar el PIN en la tienda compartida.';

/// Mensaje para el usuario de un error al compartir o descargar la tienda.
String mensajeErrorTienda(Object error) => switch (error) {
  ErrorSinConexion() => 'Sin internet. Inténtalo cuando tengas conexión.',
  ErrorSesionTienda() =>
    'La sesión venció. Vuelve a entrar con el código del correo.',
  _ => 'No se pudo completar. Inténtalo de nuevo.',
};
