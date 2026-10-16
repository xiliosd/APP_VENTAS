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

const _vacias = {
  'de', 'del', 'la', 'el', 'los', 'las', 'con', 'por', 'favor', 'porfa', //
  'dame', 'deme', 'regalame', 'regaleme', 'quiero', 'me', 'vendi', 'vendo',
};

const _numeros = {
  'un': 1, 'una': 1, 'uno': 1, 'otra': 1, 'otro': 1, //
  'dos': 2, 'tres': 3, 'cuatro': 4, 'cinco': 5, 'seis': 6, 'siete': 7,
  'ocho': 8, 'nueve': 9, 'diez': 10, 'once': 11, 'doce': 12, 'trece': 13,
  'catorce': 14, 'quince': 15, 'dieciseis': 16, 'diecisiete': 17,
  'dieciocho': 18, 'diecinueve': 19, 'veinte': 20, 'veintiun': 21,
  'veintiuno': 21, 'veintiuna': 21, 'veintidos': 22, 'veintitres': 23,
  'veinticuatro': 24, 'veinticinco': 25, 'veintiseis': 26,
  'veintisiete': 27, 'veintiocho': 28, 'veintinueve': 29, 'treinta': 30,
  'cuarenta': 40, 'cincuenta': 50, 'cien': 100, 'ciento': 100,
  'doscientos': 200, 'trescientos': 300,
};

bool _esDocena(String? t) => t == 'docena' || t == 'docenas';

/// Unidades de tamaño: una cifra seguida de una de estas es un tamaño
/// ("400 ml"), no la cantidad de otro producto.
const _unidades = {
  'ml', 'l', 'lt', 'lts', 'litro', 'litros', 'cc', 'g', 'gr', 'grs', //
  'gramo', 'gramos', 'kg', 'kilo', 'kilos', 'lb', 'libra', 'libras', 'oz',
  'onza', 'onzas', 'x',
};

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

/// Cuántas letras distintas tolera [dicha] (las cortas no se aproximan:
/// "pin" no es "pan").
int _tolerancia(String dicha) => dicha.length >= 8
    ? 2
    : dicha.length >= 4
    ? 1
    : 0;

/// Letras que hay que cambiar, quitar o poner para pasar de [a] a [b].
int _distancia(String a, String b) {
  var anterior = List<int>.generate(b.length + 1, (j) => j);
  for (var i = 1; i <= a.length; i++) {
    final actual = List<int>.filled(b.length + 1, 0)..[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cambio = a[i - 1] == b[j - 1] ? 0 : 1;
      actual[j] = [
        anterior[j] + 1,
        actual[j - 1] + 1,
        anterior[j - 1] + cambio,
      ].reduce((x, y) => x < y ? x : y);
    }
    anterior = actual;
  }
  return anterior[b.length];
}

/// [dicha] se parece al inicio de [palabra] ("lece" ~ "leche").
bool _pareceInicio(String dicha, String palabra) {
  final tolerancia = _tolerancia(dicha);
  if (tolerancia == 0) return false;
  // El inicio de la palabra con el largo de lo dicho, o uno más o menos.
  for (final largo in [dicha.length - 1, dicha.length, dicha.length + 1]) {
    if (largo < 1 || largo > palabra.length) continue;
    if (_distancia(dicha, palabra.substring(0, largo)) <= tolerancia) {
      return true;
    }
  }
  return false;
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

  /// Se halló ignorando palabras dichas: siempre se pregunta.
  bool aproximado = false;

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
    aproximado = false;
    if (coincidencias.isEmpty) coincidencias = _parecidos(catalogo);
    if (coincidencias.isEmpty) {
      coincidencias = _ignorandoPalabras(catalogo);
      aproximado = coincidencias.isNotEmpty;
    }
    exactos = [
      for (final c in catalogo)
        if (coincidencias.contains(c.p) &&
            c.nombre.join(' ') == producto.join(' '))
          c.p,
    ];
  }
}

extension on _Pedazo {
  bool _seParece(String dicha, List<String> palabras) =>
      palabras.any((w) => w.startsWith(dicha) || _pareceInicio(dicha, w));

  /// Con una letra distinta por palabra, o con palabras pegadas
  /// ("cocacola" es "coca cola").
  List<Producto> _parecidos(
    List<({Producto p, List<String> palabras, List<String> nombre})> catalogo,
  ) {
    final pegado = producto.join();
    return [
      for (final c in catalogo)
        if (producto.every((dicha) => _seParece(dicha, c.palabras)) ||
            (pegado.length >= 4 && c.palabras.join().startsWith(pegado)))
          c.p,
    ];
  }

  /// Los que más palabras comparten, si al menos la mitad de lo dicho
  /// coincide ("leche entera" halla Leche).
  List<Producto> _ignorandoPalabras(
    List<({Producto p, List<String> palabras, List<String> nombre})> catalogo,
  ) {
    var mejor = 0;
    var mejores = <Producto>[];
    for (final c in catalogo) {
      final iguales = producto
          .where((dicha) => _seParece(dicha, c.palabras))
          .length;
      if (iguales == 0 || iguales * 2 < producto.length) continue;
      if (iguales > mejor) {
        mejor = iguales;
        mejores = [c.p];
      } else if (iguales == mejor) {
        mejores.add(c.p);
      }
    }
    return mejores;
  }
}

/// El celular suele escribir cifras ("2 cocas 3 panes"): una cifra a mitad
/// del pedazo empieza otro producto si lo de antes y lo de después hallan
/// producto y no le sigue una unidad ("coca cola 400 ml" sigue entera).
List<List<String>> _partirEnCifras(
  List<String> palabras,
  List<({Producto p, List<String> palabras, List<String> nombre})> catalogo,
) {
  for (var i = 1; i < palabras.length - 1; i++) {
    if (int.tryParse(palabras[i]) == null ||
        _unidades.contains(palabras[i + 1])) {
      continue;
    }
    final antes = _Pedazo(palabras.sublist(0, i))..evaluar(catalogo);
    final despues = _Pedazo(palabras.sublist(i))..evaluar(catalogo);
    if (antes.coincidencias.isNotEmpty && despues.coincidencias.isNotEmpty) {
      return [antes.palabras, ..._partirEnCifras(despues.palabras, catalogo)];
    }
  }
  return [palabras];
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
  for (final palabrasPedazo in [
    for (final p in _pedazos(palabras)) ..._partirEnCifras(p, catalogo),
  ]) {
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
    final unico = p.aproximado
        ? null
        : p.coincidencias.length == 1
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
