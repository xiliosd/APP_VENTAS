import 'package:drift/drift.dart';
import 'package:sqlite3/common.dart' show SqliteException;

import '../data/database.dart';
import 'filas_sincronizables.dart';
import 'nube_tienda.dart';

/// Versión del formato con que este celular sube y baja filas. Si la nube
/// exige una mayor, el celular deja de sincronizar hasta actualizar la app.
const versionProtocoloSincronizacion = 2;

/// Filas por subida y por página de bajada.
const tamanoLote = 500;

enum ResultadoSincronizacion {
  alDia,
  sinConexion,
  actualizarApp,
  sesionVencida,
  noCompartida,
}

/// El correo ya tiene una tienda compartida con datos: compartir desde este
/// celular la mezclaría con la suya. Hay que usar esa tienda aquí.
class TiendaCompartidaExistente implements Exception {
  const TiendaCompartidaExistente(this.tiendaId);

  final String tiendaId;
}

/// Mantiene la base de este celular al día con la tienda compartida.
///
/// Cada ciclo sube lo anotado en `cambios_pendientes`, baja lo nuevo desde el
/// cursor y lo aplica todo en una transacción. Si dos celulares cambian el
/// mismo registro gana el último que llega a la nube; las ventas, abonos y
/// gastos son registros propios, así que nunca se pisan entre celulares.
class Sincronizador {
  Sincronizador(this.db, this.nube);

  final AppDatabase db;
  final NubeTienda nube;

  Future<EstadoSincronizacionFila?> _estado() => (db.select(
    db.estadoSincronizacion,
  )..where((e) => e.id.equals(1))).getSingleOrNull();

  Future<bool> esCompartida() async => await _estado() != null;

  Future<int> cuantosPendientes() async {
    final cantidad = db.cambiosPendientes.id.count();
    final consulta = db.selectOnly(db.cambiosPendientes)
      ..addColumns([cantidad]);
    return (await consulta.getSingle()).read(cantidad) ?? 0;
  }

  /// Sube la tienda de este celular a la nube y la deja compartida.
  Future<void> convertirEnCompartida(String nombreTienda) async {
    // Si el correo ya compartió su tienda desde otro celular, subir esta la
    // mezclaría con aquella (o pisaría lo más nuevo con copias viejas). Una
    // tienda vacía es una conversión anterior que no terminó: se completa.
    final existente = await nube.miTienda();
    if (existente != null &&
        (await nube.bajar(existente, desde: 0, limite: 1)).isNotEmpty) {
      throw TiendaCompartidaExistente(existente);
    }
    final tiendaId = await nube.crearTienda(nombreTienda);
    await db.transaction(() async {
      await db
          .into(db.estadoSincronizacion)
          .insertOnConflictUpdate(
            EstadoSincronizacionCompanion.insert(
              id: const Value(1),
              tiendaId: tiendaId,
            ),
          );
      // Todo lo que ya había se anota para subir.
      for (final tabla in tablasConIdGlobal) {
        await db.customStatement(
          'INSERT INTO cambios_pendientes (tabla, id_global, borrado, cambio) '
          "SELECT '$tabla', id_global, 0, 1 FROM $tabla "
          'WHERE true ON CONFLICT (tabla, id_global) DO NOTHING',
        );
      }
      await db.customStatement(
        'INSERT INTO cambios_pendientes (tabla, id_global, borrado, cambio) '
        "SELECT 'configuracion_tienda', '$idGlobalConfiguracion', 0, 1 "
        'FROM configuracion_tienda WHERE id = 1 '
        'ON CONFLICT (tabla, id_global) DO NOTHING',
      );
    });
    await sincronizar();
  }

  /// Baja la tienda compartida [tiendaId] a este celular, que debe estar
  /// vacío (recién instalado o con los datos borrados).
  Future<void> descargarTienda(String tiendaId) async {
    if ((await db.select(db.usuarios).get()).isNotEmpty) {
      throw StateError('El celular ya tiene una tienda');
    }
    await db
        .into(db.estadoSincronizacion)
        .insertOnConflictUpdate(
          EstadoSincronizacionCompanion.insert(
            id: const Value(1),
            tiendaId: tiendaId,
          ),
        );
    final resultado = await sincronizar();
    if (resultado == ResultadoSincronizacion.sinConexion) {
      throw const ErrorSinConexion();
    }
    if (resultado == ResultadoSincronizacion.sesionVencida) {
      throw const ErrorSesionTienda();
    }
  }

  /// Fecha de la última sincronización completa en este celular.
  Future<DateTime?> ultimaSincronizacion() async =>
      (await _estado())?.ultimaSincronizacion;

  /// Borra todos los datos de la tienda de este celular (para bajar otra).
  Future<void> vaciarBase() => db.transaction(() async {
    // Sin la fila de estado los disparadores no anotan los borrados.
    await db.delete(db.estadoSincronizacion).go();
    await db.delete(db.cambiosPendientes).go();
    for (final tabla in tablasConIdGlobal.reversed) {
      await db.customStatement('DELETE FROM $tabla');
    }
    await db.customStatement('DELETE FROM configuracion_tienda');
  });

  Future<ResultadoSincronizacion> sincronizar() async {
    final estado = await _estado();
    if (estado == null) return ResultadoSincronizacion.noCompartida;
    try {
      if (await nube.versionProtocoloMinima() >
          versionProtocoloSincronizacion) {
        return ResultadoSincronizacion.actualizarApp;
      }
      await _subir(estado.tiendaId);
      await _bajarYAplicar(estado);
      return ResultadoSincronizacion.alDia;
    } on ErrorSinConexion {
      return ResultadoSincronizacion.sinConexion;
    } on ErrorSesionTienda {
      return ResultadoSincronizacion.sesionVencida;
    }
  }

  Future<void> _subir(String tiendaId) async {
    // Se avanza por id: una anotación que vuelve a cambiar durante la subida
    // conserva su id y queda para el siguiente ciclo, en vez de repetirse.
    var ultimoId = 0;
    while (true) {
      final lote =
          await (db.select(db.cambiosPendientes)
                ..where((p) => p.id.isBiggerThanValue(ultimoId))
                ..orderBy([(p) => OrderingTerm.asc(p.id)])
                ..limit(tamanoLote))
              .get();
      if (lote.isEmpty) return;
      final cambios = <CambioSubida>[];
      final subidos = <CambioPendiente>[];
      // Una sola lectura consistente: si en medio se deshace una venta, sus
      // líneas no salen apuntando a nada.
      await db.transaction(() async {
        for (final pendiente in lote) {
          final Map<String, Object?>? datos;
          try {
            datos = pendiente.borrado
                ? null
                : await leerFila(db, pendiente.tabla, pendiente.idGlobal);
          } on ReferenciaFaltante {
            // Su padre ya no está (llegará su borrado): queda pendiente.
            continue;
          }
          subidos.add(pendiente);
          cambios.add(
            CambioSubida(
              tabla: pendiente.tabla,
              idGlobal: pendiente.idGlobal,
              datos: datos,
              borrado: datos == null,
            ),
          );
        }
      });
      if (cambios.isNotEmpty) await nube.subir(tiendaId, cambios);
      // Solo se borra lo que nadie cambió mientras se subía.
      await db.transaction(() async {
        for (final pendiente in subidos) {
          await (db.delete(db.cambiosPendientes)..where(
                (p) =>
                    p.id.equals(pendiente.id) &
                    p.cambio.equals(pendiente.cambio),
              ))
              .go();
        }
      });
      ultimoId = lote.last.id;
      if (lote.length < tamanoLote) return;
    }
  }

  Future<void> _bajarYAplicar(EstadoSincronizacionFila estado) async {
    final filas = <FilaNube>[];
    var desde = estado.cursor;
    while (true) {
      final pagina = await nube.bajar(
        estado.tiendaId,
        desde: desde,
        limite: tamanoLote,
      );
      filas.addAll(pagina);
      if (pagina.isNotEmpty) desde = pagina.last.version;
      if (pagina.length < tamanoLote) break;
    }

    await db.transaction(() async {
      await _marcarAplicando(true);
      // Un registro cambiado aquí después de subir gana: se sube luego.
      final pendientes = {
        for (final p in await db.select(db.cambiosPendientes).get())
          '${p.tabla}/${p.idGlobal}',
      };
      final porAplicar = [
        for (final fila in filas)
          if (!pendientes.contains('${fila.tabla}/${fila.idGlobal}')) fila,
      ];
      // Primero los borrados, de hijos a padres (líneas antes que su venta):
      // al reemplazar los proveedores de un producto, la fila nueva chocaría
      // con la vieja (producto y proveedor no se repiten) si llegara antes.
      for (final tabla in tablasConIdGlobal.reversed) {
        for (final fila in porAplicar) {
          if (fila.tabla == tabla && fila.borrado) {
            await _aplicarSinFrenar(
              () => aplicarBorrado(db, tabla, fila.idGlobal),
            );
          }
        }
      }
      // Luego altas y ediciones, de padres a hijos.
      const orden = [...tablasConIdGlobal, 'configuracion_tienda'];
      for (final tabla in orden) {
        for (final fila in porAplicar) {
          if (fila.tabla == tabla && !fila.borrado && fila.datos != null) {
            await _aplicarSinFrenar(() => aplicarFila(db, tabla, fila.datos!));
          }
        }
      }
      await (db.update(
        db.estadoSincronizacion,
      )..where((e) => e.id.equals(1))).write(
        EstadoSincronizacionCompanion(
          cursor: Value(desde),
          aplicando: const Value(false),
          ultimaSincronizacion: Value(DateTime.now()),
        ),
      );
    });
  }

  /// Aplica una fila en su propio punto de guardado. Si no se puede (p. ej.
  /// la corrección de una venta que otro celular deshizo), se omite y el
  /// resto sigue: una sola fila no debe frenar para siempre la tienda.
  Future<void> _aplicarSinFrenar(Future<void> Function() aplicar) async {
    try {
      await db.transaction(aplicar);
    } on FilaHuerfana {
      // Apunta a algo que ya no existe en la tienda.
    } on SqliteException {
      // Choca con una regla de la base (dato inconsistente en la nube).
    }
  }

  Future<void> _marcarAplicando(bool aplicando) =>
      (db.update(db.estadoSincronizacion)..where((e) => e.id.equals(1))).write(
        EstadoSincronizacionCompanion(aplicando: Value(aplicando)),
      );
}
