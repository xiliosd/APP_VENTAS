import 'dart:io';

import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/respaldo/nube_respaldo.dart';
import 'package:app_ventas/respaldo/restaurador.dart';

/// Nube en memoria: sin red. `subir` solo recuerda el archivo (no lo lee),
/// para poder usarse dentro de `testWidgets`.
class NubeRespaldoFalsa implements NubeRespaldo {
  NubeRespaldoFalsa({
    bool conSesion = false,
    this.telefono,
    this.fecha,
    this.codigoValido = '123456',
  }) : _sesion = conSesion;

  bool _sesion;
  String? telefono;
  DateTime? fecha;
  final String codigoValido;
  final enviados = <String>[];
  File? archivoSubido;
  int subidas = 0;

  /// Si no es null, `subir` lanza este error.
  Object? errorAlSubir;

  @override
  bool get haySesion => _sesion;

  @override
  String? get telefonoConectado => _sesion ? telefono : null;

  @override
  Future<void> enviarCodigo(String telefonoE164) async =>
      enviados.add(telefonoE164);

  @override
  Future<void> verificarCodigo(String telefonoE164, String codigo) async {
    if (codigo != codigoValido) {
      throw const ErrorCodigoRespaldo('Código incorrecto');
    }
    _sesion = true;
    telefono = telefonoE164;
  }

  @override
  Future<void> cerrarSesion() async => _sesion = false;

  @override
  Future<DateTime?> fechaUltimoRespaldo() async => fecha;

  @override
  Future<void> subir(File copia) async {
    if (errorAlSubir != null) throw errorAlSubir!;
    archivoSubido = copia;
    subidas++;
    fecha = DateTime.now();
  }

  @override
  Future<void> descargar(File destino) async {
    await archivoSubido!.copy(destino.path);
  }
}

/// Restaurador sin archivos: devuelve [resultado] y cuenta las llamadas.
class RestauradorFalso extends Restaurador {
  RestauradorFalso(this.resultado)
      : super(
          archivoBase: () async => File('no_usado.sqlite'),
          directorioTemporal: () async => Directory.systemTemp,
        );

  final ResultadoRestauracion resultado;
  int llamadas = 0;

  @override
  Future<ResultadoRestauracion> restaurar(
      NubeRespaldo nube, AppDatabase db) async {
    llamadas++;
    return resultado;
  }
}
