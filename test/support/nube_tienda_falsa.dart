import 'package:app_ventas/sincronizacion/nube_tienda.dart';

/// Nube en memoria con el mismo comportamiento que la tabla `filas` de
/// Supabase: una fila por clave y una versión que crece con cada escritura.
class NubeTiendaFalsa implements NubeTienda {
  final _filas = <String, FilaNube>{};
  var _version = 0;
  String? _tienda;

  bool sinConexion = false;
  bool sesionVencida = false;
  int versionMinima = 1;

  /// Si no es null, la subida número n (desde 1) falla sin guardar nada.
  int? fallarEnSubida;

  /// Se llama durante cada subida, antes de guardar (para simular cambios
  /// hechos en el celular mientras se sube).
  Future<void> Function()? alSubir;

  /// Cantidad de filas de cada subida.
  final subidas = <int>[];

  void _revisar() {
    if (sinConexion) throw const ErrorSinConexion();
    if (sesionVencida) throw const ErrorSesionTienda();
  }

  @override
  Future<String> crearTienda(String nombre) async {
    _revisar();
    return _tienda ??= 'tienda-1';
  }

  @override
  Future<String?> miTienda() async {
    _revisar();
    return _tienda;
  }

  @override
  Future<int> versionProtocoloMinima() async {
    _revisar();
    return versionMinima;
  }

  @override
  Future<void> subir(String tiendaId, List<CambioSubida> cambios) async {
    _revisar();
    await alSubir?.call();
    if (fallarEnSubida == subidas.length + 1) {
      subidas.add(0);
      throw const ErrorSinConexion();
    }
    subidas.add(cambios.length);
    for (final cambio in cambios) {
      _filas['${cambio.tabla}/${cambio.idGlobal}'] = FilaNube(
        tabla: cambio.tabla,
        idGlobal: cambio.idGlobal,
        datos: cambio.datos,
        borrado: cambio.borrado,
        version: ++_version,
      );
    }
  }

  @override
  Future<List<FilaNube>> bajar(
    String tiendaId, {
    required int desde,
    int limite = 500,
  }) async {
    _revisar();
    return (_filas.values.where((f) => f.version > desde).toList()
          ..sort((a, b) => a.version.compareTo(b.version)))
        .take(limite)
        .toList();
  }

  /// Todas las filas guardadas (para revisar en las pruebas).
  Iterable<FilaNube> get filas => _filas.values;
}
