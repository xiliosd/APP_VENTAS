import '../data/database.dart';
import 'texto_util.dart';

/// Cómo quedó una parte de lo dictado frente a los productos.
enum TipoParteDictada { reconocida, dudosa, noEncontrada }

/// Una parte de la venta dictada: "dos coca colas".
class ParteDictada {
  const ParteDictada({
    required this.texto,
    required this.cantidad,
    required this.tipo,
    required this.opciones,
  });

  /// Lo que se dijo del producto, sin cantidad ni palabras vacías.
  final String texto;
  final int cantidad;
  final TipoParteDictada tipo;

  /// Uno si se reconoció, de 2 a 5 si hay que elegir, vacío si no se halló.
  final List<Producto> opciones;
}

const _cantidadMaxima = 99;

/// Palabras con que suele empezar el dictado y no son productos.
const _prefijo = {
  'vecitienda',
  'veci',
  'registra',
  'registrar',
  'registre',
  'vender',
  'vende',
  'venta',
  'y',
};

const _separadores = {'y', 'mas'};

const _vacias = {'de', 'del', 'la', 'el', 'los', 'las', 'con', 'por', 'favor'};

const _numeros = {
  'un': 1, 'una': 1, 'uno': 1, 'otra': 1, 'otro': 1, //
  'dos': 2, 'tres': 3, 'cuatro': 4, 'cinco': 5, 'seis': 6, 'siete': 7,
  'ocho': 8, 'nueve': 9, 'diez': 10, 'once': 11, 'doce': 12, 'trece': 13,
  'catorce': 14, 'quince': 15, 'dieciseis': 16, 'diecisiete': 17,
  'dieciocho': 18, 'diecinueve': 19, 'veinte': 20, 'treinta': 30,
  'cuarenta': 40, 'cincuenta': 50, 'cien': 100, 'ciento': 100,
  'doscientos': 200, 'trescientos': 300,
};

bool _esDocena(String? t) => t == 'docena' || t == 'docenas';

/// Palabras normalizadas: minúsculas, sin tildes, sin signos ni guiones.
List<String> _palabras(String texto) =>
    sinTildes(texto)
        .replaceAll(RegExp(r'[^a-z0-9ñ]+'), ' ')
        .trim()
        .split(' ')
        .where((p) => p.isNotEmpty)
        .toList();

/// Plural simple: "panes" → "pan", "colas" → "cola".
String _raiz(String palabra) {
  if (palabra.length > 3 && palabra.endsWith('es')) {
    return palabra.substring(0, palabra.length - 2);
  }
  if (palabra.length > 3 && palabra.endsWith('s')) {
    return palabra.substring(0, palabra.length - 1);
  }
  return palabra;
}

/// Lee la cantidad al inicio de [palabras]: (cantidad, palabras usadas).
(int?, int) _cantidad(List<String> palabras) {
  if (palabras.isEmpty) return (null, 0);
  final primera = palabras.first;
  final segunda = palabras.length > 1 ? palabras[1] : null;
  if ((primera == 'media' || primera == 'medio') && _esDocena(segunda)) {
    return (6, 2);
  }
  if (_esDocena(primera)) return (12, 1);
  final numero = int.tryParse(primera) ?? _numeros[primera];
  if (numero == null) return (null, 0);
  if (_esDocena(segunda)) return (numero * 12, 2);
  return (numero, 1);
}

/// Parte las palabras en pedazos: en "y", "más" y donde empieza una
/// cantidad en palabra (el reconocedor casi nunca escribe comas). Las cifras
/// no parten, para no romper tamaños como "400".
List<List<String>> _pedazos(List<String> palabras) {
  final pedazos = <List<String>>[[]];
  for (var i = 0; i < palabras.length; i++) {
    final p = palabras[i];
    if (_separadores.contains(p)) {
      pedazos.add([]);
      continue;
    }
    final empiezaCantidad =
        _numeros.containsKey(p) ||
        ((p == 'media' || p == 'medio') &&
            _esDocena(i + 1 < palabras.length ? palabras[i + 1] : null));
    if (empiezaCantidad && pedazos.last.isNotEmpty) pedazos.add([]);
    pedazos.last.add(p);
  }
  return pedazos.where((p) => p.isNotEmpty).toList();
}

class _Pedazo {
  _Pedazo(this.palabras);

  final List<String> palabras;
  late int? cantidad;
  late List<String> producto;

  /// Las palabras del producto como se dijeron, para mostrarlas o buscarlas.
  late String dicho;
  late List<Producto> coincidencias;
  late List<Producto> exactos;

  void evaluar(
    List<({Producto p, List<String> palabras, List<String> nombre})> catalogo,
  ) {
    final (n, usadas) = _cantidad(palabras);
    cantidad = n;
    final sinVacias = [
      for (final p in palabras.skip(usadas))
        if (!_vacias.contains(p)) p,
    ];
    dicho = sinVacias.join(' ');
    producto = [for (final p in sinVacias) _raiz(p)];
    if (producto.isEmpty) {
      coincidencias = const [];
      exactos = const [];
      return;
    }
    // Cada palabra dicha es el inicio de alguna palabra del producto.
    coincidencias = [
      for (final c in catalogo)
        if (producto.every(
          (dicha) => c.palabras.any((w) => w.startsWith(dicha)),
        ))
          c.p,
    ];
    exactos = [
      for (final c in catalogo)
        if (coincidencias.contains(c.p) &&
            c.nombre.join(' ') == producto.join(' '))
          c.p,
    ];
  }
}

/// Lo que se dictó, en partes con su cantidad y los productos [activos] que
/// le corresponden. Nada se agrega al ticket desde aquí: la hoja de
/// confirmación decide.
List<ParteDictada> interpretarDictado(String dicho, List<Producto> activos) {
  final palabras = _palabras(dicho.replaceAll(',', ' y '));
  while (palabras.isNotEmpty && _prefijo.contains(palabras.first)) {
    palabras.removeAt(0);
  }
  final catalogo = [
    for (final p in activos)
      (
        p: p,
        palabras: _palabras(
          [p.nombre, p.marca, p.tamano].whereType<String>().join(' '),
        ),
        nombre: [for (final w in _palabras(p.nombre)) _raiz(w)],
      ),
  ];

  final pedazos = <_Pedazo>[];
  for (final palabrasPedazo in _pedazos(palabras)) {
    final pedazo = _Pedazo(palabrasPedazo)..evaluar(catalogo);
    final anterior = pedazos.isEmpty ? null : pedazos.last;
    // Un pedazo sin cantidad que no halla nada era parte del anterior
    // ("litro y medio").
    if (anterior != null &&
        pedazo.cantidad == null &&
        pedazo.coincidencias.isEmpty) {
      pedazos.last = _Pedazo([...anterior.palabras, ...palabrasPedazo])
        ..evaluar(catalogo);
      continue;
    }
    pedazos.add(pedazo);
  }

  final partes = <ParteDictada>[];
  for (final p in pedazos.where((p) => p.producto.isNotEmpty)) {
    final cantidad = (p.cantidad ?? 1).clamp(1, _cantidadMaxima);
    final unico = p.coincidencias.length == 1
        ? p.coincidencias.single
        : p.exactos.length == 1
        ? p.exactos.single
        : null;
    final tipo = unico != null
        ? TipoParteDictada.reconocida
        : p.coincidencias.isEmpty
        ? TipoParteDictada.noEncontrada
        : TipoParteDictada.dudosa;
    final opciones = unico != null ? [unico] : p.coincidencias.take(5).toList();
    // El mismo producto dicho dos veces suma en una sola parte.
    final repetida = unico == null
        ? -1
        : partes.indexWhere(
            (x) =>
                x.tipo == TipoParteDictada.reconocida &&
                x.opciones.single.id == unico.id,
          );
    if (repetida >= 0) {
      final x = partes[repetida];
      partes[repetida] = ParteDictada(
        texto: x.texto,
        cantidad: (x.cantidad + cantidad).clamp(1, _cantidadMaxima),
        tipo: x.tipo,
        opciones: x.opciones,
      );
      continue;
    }
    partes.add(
      ParteDictada(
        texto: p.dicho,
        cantidad: cantidad,
        tipo: tipo,
        opciones: opciones,
      ),
    );
  }
  return partes;
}
