import 'package:app_ventas/respaldo/respaldo_provider.dart';
import 'package:app_ventas/sincronizacion/nube_tienda.dart';
import 'package:app_ventas/sincronizacion/sincronizacion_provider.dart';

/// Respaldo con una fase fija, para pantallas que solo la consultan.
class RespaldoFijo extends RespaldoNotifier {
  RespaldoFijo(this.fase);

  final FaseRespaldo fase;

  @override
  EstadoRespaldo build() => EstadoRespaldo(fase: fase);
}

/// Sincronización falsa para pruebas de pantallas: estado fijo y registro de
/// lo que se pidió.
class SincronizacionFalsa extends SincronizacionNotifier {
  SincronizacionFalsa({
    this.inicial = const EstadoTiendaCompartida(
      fase: FaseSincronizacion.noCompartida,
    ),
    this.tienda,
    this.errorAlDescargar,
    this.errorAlCompartir,
    this.errorAlGuardarPin,
    this.celularesTienda = const [],
  });

  final EstadoTiendaCompartida inicial;

  /// Tienda compartida del correo verificado (null = no tiene).
  final String? tienda;
  final Object? errorAlDescargar;
  final Object? errorAlCompartir;
  final Object? errorAlGuardarPin;

  final List<CelularTienda> celularesTienda;
  final respuestas = <(String, bool)>[];
  final revocaciones = <String>[];

  final pinesGuardados = <({String idGlobal, String pin, int version})>[];

  int compartidas = 0;
  int sincronizaciones = 0;
  final descargas = <({String tienda, bool reemplazarDatos})>[];

  @override
  EstadoTiendaCompartida build() => inicial;

  @override
  bool get disponible => true;

  @override
  Future<bool> esCompartida() async =>
      state.fase != FaseSincronizacion.noCompartida;

  @override
  Future<void> compartirTienda() async {
    if (errorAlCompartir != null) throw errorAlCompartir!;
    compartidas++;
    state = EstadoTiendaCompartida(
      fase: FaseSincronizacion.alDia,
      ultimaSincronizacion: DateTime.now(),
    );
  }

  @override
  Future<String?> tiendaDelCorreo() async => tienda;

  @override
  Future<void> descargarTienda(
    String tiendaId, {
    bool reemplazarDatos = false,
  }) async {
    if (errorAlDescargar != null) throw errorAlDescargar!;
    descargas.add((tienda: tiendaId, reemplazarDatos: reemplazarDatos));
    state = const EstadoTiendaCompartida(fase: FaseSincronizacion.alDia);
  }

  @override
  Future<void> sincronizarAhora() async => sincronizaciones++;

  @override
  Future<void> guardarPinEnTienda({
    required String idGlobal,
    required String pin,
    required int version,
  }) async {
    if (errorAlGuardarPin != null) throw errorAlGuardarPin!;
    pinesGuardados.add((idGlobal: idGlobal, pin: pin, version: version));
  }

  @override
  Future<String> codigoTienda() async => 'ABC234';

  @override
  Future<List<CelularTienda>> celulares() async => celularesTienda;

  @override
  Future<void> responderSolicitud(
    CelularTienda solicitud, {
    required bool aprobar,
  }) async {
    respuestas.add((solicitud.usuarioAuth, aprobar));
    state = state.copiar(
      solicitudes: [
        for (final otra in state.solicitudes)
          if (otra.usuarioAuth != solicitud.usuarioAuth) otra,
      ],
    );
  }

  @override
  Future<void> revocarCelular(String usuarioAuth) async =>
      revocaciones.add(usuarioAuth);
}
