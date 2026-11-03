import 'package:app_ventas/sincronizacion/sincronizacion_provider.dart';

/// Sincronización falsa para pruebas de pantallas: estado fijo y registro de
/// lo que se pidió.
class SincronizacionFalsa extends SincronizacionNotifier {
  SincronizacionFalsa({
    this.inicial = const EstadoTiendaCompartida(
      fase: FaseSincronizacion.noCompartida,
    ),
    this.tienda,
    this.errorAlDescargar,
  });

  final EstadoTiendaCompartida inicial;

  /// Tienda compartida del correo verificado (null = no tiene).
  final String? tienda;
  final Object? errorAlDescargar;

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
}
