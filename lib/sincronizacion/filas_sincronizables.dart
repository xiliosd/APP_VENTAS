import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Variable;

import '../data/database.dart';

/// Llaves foráneas de cada tabla sincronizable: columna → tabla a la que
/// apunta. En la nube viajan como el `id_global` de la fila apuntada, porque
/// los `id` locales cambian de un celular a otro.
const llavesForaneas = <String, Map<String, String>>{
  'productos_proveedores': {
    'producto_id': 'productos',
    'proveedor_id': 'proveedores',
  },
  'conteos_inventario': {'producto_id': 'productos', 'usuario_id': 'usuarios'},
  'entradas_mercancia': {
    'proveedor_id': 'proveedores',
    'usuario_id': 'usuarios',
    'anulada_por_id': 'usuarios',
  },
  'lineas_entrada': {
    'entrada_id': 'entradas_mercancia',
    'producto_id': 'productos',
  },
  'pedidos': {
    'proveedor_id': 'proveedores',
    'usuario_id': 'usuarios',
    'entrada_id': 'entradas_mercancia',
  },
  'lineas_pedido': {'pedido_id': 'pedidos', 'producto_id': 'productos'},
  'ventas': {
    'producto_id': 'productos',
    'cliente_id': 'clientes',
    'usuario_id': 'usuarios',
  },
  'lineas_venta': {'venta_id': 'ventas', 'producto_id': 'productos'},
  'pagos_fiado': {'cliente_id': 'clientes', 'usuario_id': 'usuarios'},
  'gastos': {'usuario_id': 'usuarios', 'entrada_id': 'entradas_mercancia'},
  'correcciones': {'usuario_id': 'usuarios'},
};

/// `correcciones.movimiento_id` apunta a una de tres tablas según
/// `tipo_movimiento`.
const tablaDeMovimiento = <String, String>{
  'venta': 'ventas',
  'abono': 'pagos_fiado',
  'gasto': 'gastos',
};

/// Al leer una fila para subirla, la fila a la que apunta ya no existe en
/// este celular (se borró justo después).
class ReferenciaFaltante implements Exception {
  const ReferenciaFaltante(this.tabla, this.columna);

  final String tabla;
  final String columna;
}

/// Una fila llegó de la nube antes que la fila a la que apunta.
class FilaHuerfana implements Exception {
  const FilaHuerfana(this.tabla, this.columna, this.idGlobal);

  final String tabla;
  final String columna;
  final String idGlobal;

  @override
  String toString() => 'FilaHuerfana($tabla.$columna → $idGlobal)';
}

/// Las referencias de [tabla] (incluida la de las correcciones, que depende
/// de [fila]) como columna → tabla apuntada.
Map<String, String> _referencias(String tabla, Map<String, Object?> fila) => {
  ...?llavesForaneas[tabla],
  if (tabla == 'correcciones')
    'movimiento_id': tablaDeMovimiento[fila['tipo_movimiento']]!,
};

/// La fila [idGlobal] de [tabla] lista para subir, o null si ya no existe.
Future<Map<String, Object?>?> leerFila(
  AppDatabase db,
  String tabla,
  String idGlobal,
) async {
  if (tabla == 'configuracion_tienda') return _leerConfiguracion(db);
  final filas = await db
      .customSelect(
        'SELECT * FROM $tabla WHERE id_global = ?',
        variables: [Variable.withString(idGlobal)],
      )
      .get();
  if (filas.isEmpty) return null;
  final datos = Map<String, Object?>.of(filas.single.data)..remove('id');
  // El PIN se queda en cada celular; la nube lo guarda aparte (`pines`).
  if (tabla == 'usuarios') datos.remove('pin_hash');
  for (final MapEntry(key: columna, value: apuntada) in _referencias(
    tabla,
    datos,
  ).entries) {
    final id = datos[columna];
    if (id == null) continue;
    final destino = await db
        .customSelect(
          'SELECT id_global FROM $apuntada WHERE id = ?',
          variables: [Variable.withInt(id as int)],
        )
        .getSingleOrNull();
    if (destino == null) throw ReferenciaFaltante(tabla, columna);
    datos[columna] = destino.read<String>('id_global');
  }
  return datos;
}

Future<Map<String, Object?>?> _leerConfiguracion(AppDatabase db) async {
  final fila = await db
      .customSelect(
        'SELECT nombre_tienda, imagen_qr FROM configuracion_tienda '
        'WHERE id = 1',
      )
      .getSingleOrNull();
  if (fila == null) return null;
  final imagen = fila.read<Uint8List?>('imagen_qr');
  return {
    'nombre_tienda': fila.read<String?>('nombre_tienda'),
    'imagen_qr': imagen == null ? null : base64Encode(imagen),
  };
}

final _columnasPorTabla = <String, Set<String>>{};

Future<Set<String>> _columnas(AppDatabase db, String tabla) async =>
    _columnasPorTabla[tabla] ??= {
      for (final columna
          in await db.customSelect("PRAGMA table_info('$tabla')").get())
        columna.read<String>('name'),
    };

/// Guarda en este celular la fila [datos] de [tabla] que llegó de la nube:
/// la crea o la reemplaza según su `id_global`. Lanza [FilaHuerfana] si
/// apunta a una fila que aún no está.
Future<void> aplicarFila(
  AppDatabase db,
  String tabla,
  Map<String, Object?> datos,
) async {
  if (tabla == 'configuracion_tienda') return _aplicarConfiguracion(db, datos);
  final columnas = await _columnas(db, tabla);
  // Columnas que este celular no conoce (de una versión más nueva) se omiten.
  final valores = {
    for (final MapEntry(:key, :value) in datos.entries)
      if (columnas.contains(key) && key != 'id') key: value,
  };
  for (final MapEntry(key: columna, value: apuntada) in _referencias(
    tabla,
    valores,
  ).entries) {
    final idGlobal = valores[columna];
    if (idGlobal == null) continue;
    final destino = await db
        .customSelect(
          'SELECT id FROM $apuntada WHERE id_global = ?',
          variables: [Variable.withString(idGlobal as String)],
        )
        .getSingleOrNull();
    if (destino == null) throw FilaHuerfana(tabla, columna, idGlobal);
    valores[columna] = destino.read<int>('id');
  }
  if (tabla == 'productos_proveedores' &&
      !await _ganaProveedorRepetido(db, valores)) {
    return;
  }
  // SQLite revisa el NOT NULL de la fila nueva aun cuando termina en
  // actualización: el PIN vacío va siempre en la inserción y solo entra en la
  // actualización cuando el guardado aquí ya no sirve.
  final conservar = {'id_global'};
  if (tabla == 'usuarios' && !await _pinLocalCaduco(db, valores)) {
    conservar.add('pin_hash');
  }
  final nombres = valores.keys.toList();
  final actualizar = [
    for (final nombre in nombres)
      if (!conservar.contains(nombre)) '$nombre = excluded.$nombre',
  ];
  await db.customStatement(
    'INSERT INTO $tabla (${nombres.join(', ')}) '
    'VALUES (${List.filled(nombres.length, '?').join(', ')}) '
    'ON CONFLICT (id_global) DO UPDATE SET ${actualizar.join(', ')}',
    [for (final nombre in nombres) valores[nombre]],
  );
}

/// El PIN guardado en este celular no se pisa con lo que llega de la nube.
/// Un usuario nuevo queda sin PIN (su primer ingreso aquí se revisa en
/// línea), y si el PIN se cambió en otro celular (`version_pin` mayor) el
/// guardado aquí se borra porque ya no sirve. Deja `pin_hash` vacío en
/// [valores] y devuelve si también debe borrarse el guardado.
Future<bool> _pinLocalCaduco(
  AppDatabase db,
  Map<String, Object?> valores,
) async {
  valores['pin_hash'] = '';
  final local = await db
      .customSelect(
        'SELECT version_pin FROM usuarios WHERE id_global = ?',
        variables: [Variable.withString(valores['id_global']! as String)],
      )
      .getSingleOrNull();
  final versionQueLlega = (valores['version_pin'] as int?) ?? 0;
  return local == null || versionQueLlega > local.read<int>('version_pin');
}

/// Producto y proveedor no se repiten: si dos celulares agregaron el mismo
/// proveedor a un producto, cada uno con su `id_global`, todos se quedan con
/// el mayor. Devuelve false si la fila que llega pierde (no se aplica).
Future<bool> _ganaProveedorRepetido(
  AppDatabase db,
  Map<String, Object?> valores,
) async {
  final otra = await db
      .customSelect(
        'SELECT id_global FROM productos_proveedores '
        'WHERE producto_id = ? AND proveedor_id = ? AND id_global <> ?',
        variables: [
          Variable.withInt(valores['producto_id']! as int),
          Variable.withInt(valores['proveedor_id']! as int),
          Variable.withString(valores['id_global']! as String),
        ],
      )
      .getSingleOrNull();
  if (otra == null) return true;
  final idOtra = otra.read<String>('id_global');
  if (idOtra.compareTo(valores['id_global']! as String) > 0) return false;
  await db.customStatement(
    'DELETE FROM productos_proveedores WHERE id_global = ?',
    [idOtra],
  );
  return true;
}

Future<void> _aplicarConfiguracion(
  AppDatabase db,
  Map<String, Object?> datos,
) async {
  final imagen = datos['imagen_qr'] as String?;
  await db.customStatement(
    'INSERT INTO configuracion_tienda (id, nombre_tienda, imagen_qr) '
    'VALUES (1, ?, ?) ON CONFLICT (id) DO UPDATE SET '
    'nombre_tienda = excluded.nombre_tienda, imagen_qr = excluded.imagen_qr',
    [datos['nombre_tienda'], imagen == null ? null : base64Decode(imagen)],
  );
}

/// Borra de este celular la fila [idGlobal] de [tabla], si está.
Future<void> aplicarBorrado(AppDatabase db, String tabla, String idGlobal) =>
    db.customStatement('DELETE FROM $tabla WHERE id_global = ?', [idGlobal]);
