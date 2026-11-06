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

/// Lo que responde la nube al revisar un PIN.
enum ResultadoPin { ok, incorrecto, bloqueado, inactivo }

ResultadoPin resultadoPinDesde(String? valor) =>
    ResultadoPin.values.where((r) => r.name == valor).firstOrNull ??
    ResultadoPin.incorrecto;

/// Respuesta a "Unirme a una tienda": con [resultado] ok trae la tienda.
class SolicitudIngreso {
  const SolicitudIngreso({
    required this.resultado,
    this.tiendaId,
    this.nombreTienda,
    this.nombreVendedor,
  });

  factory SolicitudIngreso.desdeJson(Map<String, Object?> json) =>
      SolicitudIngreso(
        resultado: resultadoPinDesde(json['resultado'] as String?),
        tiendaId: json['tienda'] as String?,
        nombreTienda: json['nombre_tienda'] as String?,
        nombreVendedor: json['nombre_vendedor'] as String?,
      );

  final ResultadoPin resultado;
  final String? tiendaId;
  final String? nombreTienda;
  final String? nombreVendedor;
}

enum EstadoMiembro { pendiente, aprobado, rechazado, revocado }

EstadoMiembro estadoMiembroDesde(String? valor) =>
    EstadoMiembro.values.where((e) => e.name == valor).firstOrNull ??
    EstadoMiembro.revocado;

/// La relación de la sesión de este celular con su tienda.
class Membresia {
  const Membresia({
    required this.tiendaId,
    required this.rol,
    required this.estado,
    this.revocadoEn,
    this.usuarioIdGlobal,
  });

  factory Membresia.desdeJson(Map<String, Object?> json) => Membresia(
    tiendaId: json['tienda']! as String,
    rol: json['rol']! as String,
    estado: estadoMiembroDesde(json['estado'] as String?),
    revocadoEn: json['revocado_en'] == null
        ? null
        : DateTime.parse(json['revocado_en']! as String),
    usuarioIdGlobal: json['usuario_id_global'] as String?,
  );

  final String tiendaId;
  final String rol;
  final EstadoMiembro estado;
  final DateTime? revocadoEn;

  /// El usuario de la tienda con que entró este celular (solo vendedores).
  final String? usuarioIdGlobal;

  bool get esVendedor => rol == 'vendedor';
}

/// Un celular de la tienda, como lo ve el admin.
class CelularTienda {
  const CelularTienda({
    required this.usuarioAuth,
    required this.rol,
    required this.estado,
    required this.solicitadoEn,
    this.nombreVendedor,
    this.nombreCelular,
    this.usuarioIdGlobal,
  });

  /// Id de la sesión del celular en la nube.
  final String usuarioAuth;
  final String rol;
  final EstadoMiembro estado;
  final DateTime solicitadoEn;
  final String? nombreVendedor;
  final String? nombreCelular;
  final String? usuarioIdGlobal;
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

  /// Abre una sesión anónima para este celular de vendedor (si no tiene
  /// ninguna).
  Future<void> iniciarSesionCelular();

  /// Cierra la sesión de este celular en la nube.
  Future<void> cerrarSesionCelular();

  /// El código que el admin le dicta al vendedor.
  Future<String> codigoTienda(String tiendaId);

  Future<SolicitudIngreso> solicitarIngreso(
    String codigo,
    int numeroVendedor,
    String pin,
    String nombreCelular,
  );

  /// La membresía de la sesión de este celular, o null si no tiene.
  Future<Membresia?> miMembresia();

  /// Celulares de vendedores que esperan aprobación.
  Future<List<CelularTienda>> solicitudes(String tiendaId);

  /// Todos los celulares de la tienda.
  Future<List<CelularTienda>> celulares(String tiendaId);

  Future<void> responderSolicitud(
    String tiendaId,
    String usuarioAuth, {
    required bool aprobar,
  });

  Future<void> revocarCelular(String tiendaId, String usuarioAuth);

  /// Quita el acceso a todos los celulares de ese vendedor y bloquea su PIN.
  Future<void> desactivarVendedor(String tiendaId, String idGlobal);

  Future<void> guardarPin(
    String tiendaId,
    String idGlobal,
    String pin,
    int version,
  );

  /// Sube el PIN que este celular guardaba (sha256) si la nube no tiene uno.
  Future<void> guardarPinLegado(
    String tiendaId,
    String idGlobal,
    String hash,
    int version,
  );

  /// Usuarios de la tienda cuyo PIN la nube aún no tiene.
  Future<List<String>> pinesFaltantes(String tiendaId);

  Future<ResultadoPin> verificarPin(
    String tiendaId,
    String idGlobal,
    String pin,
  );

  /// Desde un celular revocado: entrega sus movimientos de antes de la
  /// revocación. Devuelve cuántos aceptó la nube.
  Future<int> entregarPendientes(List<CambioSubida> cambios);
}
