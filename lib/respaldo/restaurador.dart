import 'dart:io';

import 'package:path/path.dart' as p;

import '../data/database.dart';
import 'copia_base_datos.dart';
import 'nube_respaldo.dart';

enum ResultadoRestauracion { restaurado, sinRespaldo, invalido }

/// Descarga el respaldo, lo valida y solo entonces reemplaza la base local.
class Restaurador {
  Restaurador({required this.archivoBase, required this.directorioTemporal});

  final Future<File> Function() archivoBase;
  final Future<Directory> Function() directorioTemporal;

  /// Si devuelve [ResultadoRestauracion.restaurado], [db] quedó cerrada y el
  /// archivo local reemplazado: quien llama debe abrir una base nueva.
  Future<ResultadoRestauracion> restaurar(
      NubeRespaldo nube, AppDatabase db) async {
    if (await nube.fechaUltimoRespaldo() == null) {
      return ResultadoRestauracion.sinRespaldo;
    }
    final temporal = await directorioTemporal();
    final descargado = File(p.join(temporal.path, 'restaurar_app_ventas.sqlite'));
    if (await descargado.exists()) await descargado.delete();
    await nube.descargar(descargado);

    if (!CopiaBaseDatos.esCopiaValida(descargado,
        versionMaxima: db.schemaVersion)) {
      await descargado.delete();
      return ResultadoRestauracion.invalido;
    }

    await db.close();
    final base = await archivoBase();
    for (final sufijo in ['-wal', '-shm', '-journal']) {
      final auxiliar = File('${base.path}$sufijo');
      if (await auxiliar.exists()) await auxiliar.delete();
    }
    await descargado.copy(base.path);
    await descargado.delete();
    return ResultadoRestauracion.restaurado;
  }
}
