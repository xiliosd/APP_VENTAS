import 'package:app_ventas/sincronizacion/nube_tienda.dart';
import 'package:app_ventas/util/pin_hash.dart';

/// Lo que guarda la nube falsa, compartido por todos los celulares que la
/// usan (ver [NubeTiendaFalsa.otroCelular]).
class _Almacen {
  final filas = <String, FilaNube>{};
  var version = 0;
  String? tienda;
  String nombreTienda = '';
  final codigo = 'ABC234';
  var sesiones = 0;
  DateTime Function() ahora = DateTime.now;

  /// Sesión → su membresía (una sola tienda).
  final miembros = <String, _Miembro>{};

  /// `id_global` del usuario → su PIN.
  final pines = <String, _Pin>{};
}

class _Miembro {
  _Miembro({
    required this.rol,
    required this.estado,
    required this.solicitadoEn,
    this.usuarioIdGlobal,
    this.nombreCelular,
  });

  final String rol;
  EstadoMiembro estado;
  String? usuarioIdGlobal;
  String? nombreCelular;
  DateTime solicitadoEn;
  DateTime? revocadoEn;
}

class _Pin {
  String? pin;
  String? hashLegado;
  int version = 0;
  int intentos = 0;
  DateTime? bloqueadoHasta;
  bool activo = true;
}

/// Nube en memoria con el mismo comportamiento que las tablas de Supabase:
/// `filas` con una versión que crece con cada escritura, y los celulares de
/// vendedores con su aprobación y su PIN revisado en el servidor.
///
/// La instancia que crea la prueba es el celular del admin (sesión por
/// correo). [otroCelular] da otro celular que comparte la misma nube.
class NubeTiendaFalsa implements NubeTienda {
  NubeTiendaFalsa() : _a = _Almacen(), sesion = 'admin';

  NubeTiendaFalsa._celular(this._a) : sesion = null;

  final _Almacen _a;

  /// La sesión de este celular en la nube, o null si no tiene.
  String? sesion;

  bool sinConexion = false;
  bool sesionVencida = false;

  /// Un error que no es de red ni de sesión (p. ej. del servidor).
  bool errorInesperado = false;
  int versionMinima = 1;

  /// Si no es null, la subida número n (desde 1) falla sin guardar nada.
  int? fallarEnSubida;

  /// Se llama durante cada subida, antes de guardar (para simular cambios
  /// hechos en el celular mientras se sube).
  Future<void> Function()? alSubir;

  /// Se llama al empezar cada bajada (para simular cambios hechos en el
  /// celular entre la subida y la bajada).
  Future<void> Function()? alBajar;

  /// Cantidad de filas de cada subida.
  final subidas = <int>[];

  /// Veces que se consultó la versión mínima: una por ciclo de
  /// sincronización.
  int ciclos = 0;

  /// Lo que recibió [entregarPendientes] (aceptado o no).
  final entregas = <CambioSubida>[];

  /// Otro celular que usa la misma nube, sin sesión todavía.
  NubeTiendaFalsa otroCelular() => NubeTiendaFalsa._celular(_a);

  /// Para mover el reloj de la nube (bloqueos y revocaciones).
  set reloj(DateTime Function() ahora) => _a.ahora = ahora;

  void _revisar() {
    if (sinConexion) throw const ErrorSinConexion();
    if (sesionVencida) throw const ErrorSesionTienda();
    if (errorInesperado) throw StateError('error del servidor');
  }

  _Miembro? get _miembro => _a.miembros[sesion];

  bool get _puedeVer =>
      _miembro?.estado == EstadoMiembro.aprobado ||
      (sesion == 'admin' && _miembro == null);

  void _exigirAdmin() {
    final miembro = _miembro;
    if (miembro?.rol != 'admin' || miembro?.estado != EstadoMiembro.aprobado) {
      throw StateError('solo el administrador puede hacer esto');
    }
  }

  @override
  Future<String> crearTienda(String nombre) async {
    _revisar();
    _a.nombreTienda = nombre;
    _a.miembros.putIfAbsent(
      sesion!,
      () => _Miembro(
        rol: 'admin',
        estado: EstadoMiembro.aprobado,
        solicitadoEn: _a.ahora(),
      ),
    );
    return _a.tienda ??= 'tienda-1';
  }

  @override
  Future<String?> miTienda() async {
    _revisar();
    return _miembro?.rol == 'admin' ? _a.tienda : null;
  }

  @override
  Future<int> versionProtocoloMinima() async {
    ciclos++;
    _revisar();
    return versionMinima;
  }

  @override
  Future<void> subir(String tiendaId, List<CambioSubida> cambios) async {
    _revisar();
    if (!_puedeVer) throw StateError('sin acceso a la tienda');
    await alSubir?.call();
    if (fallarEnSubida == subidas.length + 1) {
      subidas.add(0);
      throw const ErrorSinConexion();
    }
    subidas.add(cambios.length);
    for (final cambio in cambios) {
      _guardarFila(cambio);
    }
  }

  void _guardarFila(CambioSubida cambio) {
    final datos = cambio.datos == null ? null : {...cambio.datos!};
    if (cambio.tabla == 'usuarios') datos?.remove('pin_hash');
    _a.filas['${cambio.tabla}/${cambio.idGlobal}'] = FilaNube(
      tabla: cambio.tabla,
      idGlobal: cambio.idGlobal,
      datos: datos,
      borrado: cambio.borrado,
      version: ++_a.version,
    );
  }

  @override
  Future<List<FilaNube>> bajar(
    String tiendaId, {
    required int desde,
    int limite = 500,
  }) async {
    _revisar();
    await alBajar?.call();
    if (!_puedeVer) return const [];
    return (_a.filas.values.where((f) => f.version > desde).toList()
          ..sort((a, b) => a.version.compareTo(b.version)))
        .take(limite)
        .toList();
  }

  /// Todas las filas guardadas (para revisar en las pruebas).
  Iterable<FilaNube> get filas => _a.filas.values;

  @override
  Future<void> iniciarSesionCelular() async {
    _revisar();
    sesion ??= 'celular-${++_a.sesiones}';
  }

  @override
  Future<void> cerrarSesionCelular() async {
    sesion = null;
  }

  @override
  Future<String> codigoTienda(String tiendaId) async {
    _revisar();
    if (!_puedeVer) throw StateError('sin acceso a la tienda');
    return _a.codigo;
  }

  ResultadoPin _pinValido(String idGlobal, String pin) {
    final guardado = _a.pines[idGlobal];
    if (guardado == null) return ResultadoPin.incorrecto;
    final bloqueo = guardado.bloqueadoHasta;
    if (bloqueo != null && bloqueo.isAfter(_a.ahora())) {
      return ResultadoPin.bloqueado;
    }
    final correcto =
        guardado.pin == pin ||
        (guardado.hashLegado != null && guardado.hashLegado == hashPin(pin));
    if (!correcto) {
      guardado.intentos++;
      if (guardado.intentos >= 5) {
        guardado
          ..intentos = 0
          ..bloqueadoHasta = _a.ahora().add(const Duration(minutes: 15));
      }
      return ResultadoPin.incorrecto;
    }
    guardado
      ..intentos = 0
      ..bloqueadoHasta = null;
    if (guardado.hashLegado != null) {
      guardado
        ..pin = pin
        ..hashLegado = null;
    }
    return guardado.activo ? ResultadoPin.ok : ResultadoPin.inactivo;
  }

  @override
  Future<SolicitudIngreso> solicitarIngreso(
    String codigo,
    int numeroVendedor,
    String pin,
    String nombreCelular,
  ) async {
    _revisar();
    if (sesion == null) throw const ErrorSesionTienda();
    const incorrecto = SolicitudIngreso(resultado: ResultadoPin.incorrecto);
    if (_a.tienda == null || codigo.trim().toUpperCase() != _a.codigo) {
      return incorrecto;
    }
    final vendedor = _a.filas.values
        .where(
          (f) =>
              f.tabla == 'usuarios' &&
              !f.borrado &&
              f.datos?['rol'] == 'vendedor' &&
              f.datos?['numero_vendedor'] == numeroVendedor &&
              f.datos?['activo'] != 0 &&
              f.datos?['activo'] != false,
        )
        .firstOrNull;
    if (vendedor == null || _miembro?.rol == 'admin') return incorrecto;
    final resultado = _pinValido(vendedor.idGlobal, pin);
    if (resultado != ResultadoPin.ok) {
      return SolicitudIngreso(resultado: resultado);
    }
    final anterior = _miembro;
    final sigueAprobado =
        anterior?.estado == EstadoMiembro.aprobado &&
        anterior?.usuarioIdGlobal == vendedor.idGlobal;
    _a.miembros[sesion!] = _Miembro(
      rol: 'vendedor',
      estado: sigueAprobado ? EstadoMiembro.aprobado : EstadoMiembro.pendiente,
      usuarioIdGlobal: vendedor.idGlobal,
      nombreCelular: nombreCelular,
      solicitadoEn: _a.ahora(),
    );
    return SolicitudIngreso(
      resultado: ResultadoPin.ok,
      tiendaId: _a.tienda,
      nombreTienda: _a.nombreTienda,
      nombreVendedor: vendedor.datos?['nombre'] as String?,
    );
  }

  @override
  Future<Membresia?> miMembresia() async {
    _revisar();
    final miembro = _miembro;
    if (miembro == null) return null;
    return Membresia(
      tiendaId: _a.tienda!,
      rol: miembro.rol,
      estado: miembro.estado,
      revocadoEn: miembro.revocadoEn,
      usuarioIdGlobal: miembro.usuarioIdGlobal,
    );
  }

  @override
  Future<List<CelularTienda>> celulares(String tiendaId) async {
    _revisar();
    _exigirAdmin();
    return [
      for (final MapEntry(key: usuarioAuth, value: m) in _a.miembros.entries)
        CelularTienda(
          usuarioAuth: usuarioAuth,
          rol: m.rol,
          estado: m.estado,
          solicitadoEn: m.solicitadoEn,
          nombreCelular: m.nombreCelular,
          usuarioIdGlobal: m.usuarioIdGlobal,
          nombreVendedor:
              _a.filas['usuarios/${m.usuarioIdGlobal}']?.datos?['nombre']
                  as String?,
        ),
    ];
  }

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
  }) async {
    _revisar();
    _exigirAdmin();
    final miembro = _a.miembros[usuarioAuth];
    if (miembro?.rol != 'vendedor' ||
        miembro?.estado != EstadoMiembro.pendiente) {
      return;
    }
    miembro!.estado = aprobar
        ? EstadoMiembro.aprobado
        : EstadoMiembro.rechazado;
  }

  void _revocar(_Miembro miembro) {
    if (miembro.rol != 'vendedor') return;
    if (miembro.estado != EstadoMiembro.pendiente &&
        miembro.estado != EstadoMiembro.aprobado) {
      return;
    }
    miembro
      ..estado = EstadoMiembro.revocado
      ..revocadoEn = _a.ahora();
  }

  @override
  Future<void> revocarCelular(String tiendaId, String usuarioAuth) async {
    _revisar();
    _exigirAdmin();
    final miembro = _a.miembros[usuarioAuth];
    if (miembro != null) _revocar(miembro);
  }

  @override
  Future<void> desactivarVendedor(String tiendaId, String idGlobal) async {
    _revisar();
    _exigirAdmin();
    for (final miembro in _a.miembros.values) {
      if (miembro.usuarioIdGlobal == idGlobal) _revocar(miembro);
    }
    _a.pines[idGlobal]?.activo = false;
  }

  @override
  Future<void> guardarPin(
    String tiendaId,
    String idGlobal,
    String pin,
    int version,
  ) async {
    _revisar();
    _exigirAdmin();
    _a.pines[idGlobal] = _Pin()
      ..pin = pin
      ..version = version;
  }

  @override
  Future<void> guardarPinLegado(
    String tiendaId,
    String idGlobal,
    String hash,
    int version,
  ) async {
    _revisar();
    _exigirAdmin();
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(hash)) {
      throw StateError('hash inválido');
    }
    _a.pines.putIfAbsent(
      idGlobal,
      () => _Pin()
        ..hashLegado = hash
        ..version = version,
    );
  }

  @override
  Future<List<String>> pinesFaltantes(String tiendaId) async {
    _revisar();
    _exigirAdmin();
    return [
      for (final fila in _a.filas.values)
        if (fila.tabla == 'usuarios' &&
            !fila.borrado &&
            !_a.pines.containsKey(fila.idGlobal))
          fila.idGlobal,
    ];
  }

  @override
  Future<ResultadoPin> verificarPin(
    String tiendaId,
    String idGlobal,
    String pin,
  ) async {
    _revisar();
    if (!_puedeVer) throw StateError('sin acceso a la tienda');
    return _pinValido(idGlobal, pin);
  }

  static const _tablasMovimientos = {
    'ventas',
    'lineas_venta',
    'pagos_fiado',
    'gastos',
    'conteos_inventario',
    'entradas_mercancia',
    'lineas_entrada',
    'correcciones',
  };

  @override
  Future<int> entregarPendientes(List<CambioSubida> cambios) async {
    _revisar();
    final miembro = _miembro;
    final revocadoEn = miembro?.revocadoEn;
    if (miembro?.estado != EstadoMiembro.revocado ||
        revocadoEn == null ||
        _a.ahora().difference(revocadoEn) > const Duration(days: 30)) {
      throw StateError('este celular no puede entregar movimientos');
    }
    entregas.addAll(cambios);
    var aceptadas = 0;
    for (final cambio in cambios) {
      final datos = cambio.datos;
      if (datos == null ||
          !_tablasMovimientos.contains(cambio.tabla) ||
          _a.filas.containsKey('${cambio.tabla}/${cambio.idGlobal}')) {
        continue;
      }
      if (cambio.tabla == 'lineas_venta' || cambio.tabla == 'lineas_entrada') {
        final padre = cambio.tabla == 'lineas_venta'
            ? 'ventas/${datos['venta_id']}'
            : 'entradas_mercancia/${datos['entrada_id']}';
        if (_a.filas[padre] == null || _a.filas[padre]!.borrado) continue;
      } else {
        final fecha = datos['fecha'];
        if (fecha is! int ||
            fecha >= revocadoEn.millisecondsSinceEpoch ~/ 1000) {
          continue;
        }
      }
      _guardarFila(cambio);
      aceptadas++;
    }
    return aceptadas;
  }
}
