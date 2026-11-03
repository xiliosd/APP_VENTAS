/// `id_global` fijo de la única fila de `configuracion_tienda` en la nube.
const idGlobalConfiguracion = 'unica';

/// Sentencias `CREATE TRIGGER` que anotan en `cambios_pendientes` cada alta,
/// edición o borrado de [tablas] (y de `configuracion_tienda`).
///
/// Solo anotan con la tienda compartida (hay fila en `estado_sincronizacion`)
/// y mientras no se están aplicando cambios bajados de la nube; así los
/// repositorios no necesitan saber nada de la sincronización y un borrado
/// físico ("Deshacer" una venta) también llega a los otros celulares.
List<String> sentenciasDisparadores(List<String> tablas) {
  const condicion =
      'WHEN EXISTS (SELECT 1 FROM estado_sincronizacion '
      'WHERE id = 1 AND aplicando = 0)';

  String disparador(
    String tabla,
    String nombre,
    String evento,
    String idGlobal,
    int borrado,
  ) =>
      'CREATE TRIGGER IF NOT EXISTS sincronizar_${tabla}_$nombre '
      'AFTER $evento ON $tabla $condicion BEGIN '
      'INSERT INTO cambios_pendientes (tabla, id_global, borrado, cambio) '
      "VALUES ('$tabla', $idGlobal, $borrado, 1) "
      'ON CONFLICT (tabla, id_global) DO UPDATE SET '
      'borrado = excluded.borrado, cambio = cambios_pendientes.cambio + 1; '
      'END';

  return [
    for (final tabla in tablas) ...[
      disparador(tabla, 'insercion', 'INSERT', 'NEW.id_global', 0),
      disparador(tabla, 'edicion', 'UPDATE', 'NEW.id_global', 0),
      disparador(tabla, 'borrado', 'DELETE', 'OLD.id_global', 1),
    ],
    disparador(
      'configuracion_tienda',
      'insercion',
      'INSERT',
      "'$idGlobalConfiguracion'",
      0,
    ),
    disparador(
      'configuracion_tienda',
      'edicion',
      'UPDATE',
      "'$idGlobalConfiguracion'",
      0,
    ),
  ];
}
