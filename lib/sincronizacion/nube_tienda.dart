/// Un registro de la tienda tal como está en la nube.
class FilaNube {
  const FilaNube({
    required this.tabla,
    required this.idGlobal,
    required this.datos,
    required this.borrado,
    required this.version,
  });

  final String tabla;
  final String idGlobal;

  /// null cuando [borrado].
  final Map<String, Object?>? datos;
  final bool borrado;

  /// Crece con cada escritura en la tienda: es el cursor de bajada.
  final int version;
}

/// Un cambio de este celular para subir a la nube.
class CambioSubida {
  const CambioSubida({
    required this.tabla,
    required this.idGlobal,
    required this.datos,
    required this.borrado,
  });

  final String tabla;
  final String idGlobal;
  final Map<String, Object?>? datos;
  final bool borrado;
}

/// No hay internet o el servidor no respondió: se reintenta después.
class ErrorSinConexion implements Exception {
  const ErrorSinConexion();
}

/// La sesión de la nube venció: hay que volver a entrar con el código.
class ErrorSesionTienda implements Exception {
  const ErrorSesionTienda();
}

/// La tienda compartida en la nube.
abstract interface class NubeTienda {
  /// Crea la tienda del admin con sesión (o devuelve la que ya tiene).
  Future<String> crearTienda(String nombre);

  /// La tienda de la que el usuario con sesión es admin, o null.
  Future<String?> miTienda();

  /// Versión mínima del protocolo de sincronización que acepta la nube.
  Future<int> versionProtocoloMinima();

  Future<void> subir(String tiendaId, List<CambioSubida> cambios);

  /// Filas con versión mayor que [desde], en orden de versión.
  Future<List<FilaNube>> bajar(
    String tiendaId, {
    required int desde,
    int limite = 500,
  });
}
