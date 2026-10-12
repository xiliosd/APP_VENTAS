# Código de barras Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Escanear códigos de barras para crear productos (autocompletados desde Open Food Facts) y para vender, con marca, tamaño, envase y tipo para buscar y filtrar.

**Architecture:** Esquema v8 con cinco columnas opcionales en `productos`; el repositorio valida el código único entre activos. La consulta a Open Food Facts y el lector de códigos van detrás de proveedores de Riverpod (`consultaProductoProvider`, `lectorCodigoProvider`) para usar dobles en pruebas. Un widget compartido de campos de detalle sirve a la ficha y a la hoja rápida de la venta.

**Tech Stack:** Flutter 3.47, Riverpod 2, Drift (build_runner), `dart:io` HttpClient, `mobile_scanner` 7.4.2 (nueva).

**Spec:** `docs/superpowers/specs/2026-10-12-vecitienda-codigo-barras-design.md`

## Global Constraints

- Única dependencia nueva: `mobile_scanner: 7.4.2` (fijada, sin `^`).
- Sin `package:http`: la consulta usa `dart:io` `HttpClient`.
- Open Food Facts: `GET {base}/api/v2/product/{codigo}?fields=product_name,product_name_es,brands,quantity,packaging_tags,categories_tags`, cabecera `User-Agent: VeciTienda/1.0 (Android)`, límite 5 s; cualquier fallo → `null`.
- Claves de tipo: `bebidas, lacteos, panaderia, abarrotes, snacks, aseo_personal, aseo_hogar, licores, carnes, fruver, otros`. Claves de envase: `botella_plastica, botella_vidrio, lata, caja, bolsa, paquete, frasco, granel, otro`.
- Textos vacíos o solo espacios en los campos nuevos se guardan como nulo.
- Colores solo con `ColoresApp`; modo oscuro y letra 2,0× sin excepciones.
- Archivos con CRLF: editar con `$TEMP/ed.py` o la herramienta Edit.
- Comando de pruebas completo: `flutter test` (727 al empezar).

## Review Focus

1. Código con espacios o saltos de línea (lector físico que manda `\n`, pegado con espacios): se recorta antes de buscar y de guardar — prueba en Tarea 1 y Tarea 7.
2. Editar un producto existente sin tocar su código no debe chocar consigo mismo — prueba en Tarea 1.
3. Open Food Facts devuelve `brands` con varias marcas ("Postobón,Colombiana") o nombre vacío: se usa la primera marca y un nombre vacío cuenta como ausente — prueba en Tarea 3.
4. Consulta que llega después de que la persona ya escribió el nombre: no pisa lo escrito — prueba en Tarea 5.
5. Producto inactivo con el código escaneado en la venta: avisa y no duplica — prueba en Tarea 7.

---

### Task 1: Esquema v8 y repositorio

**Files:**
- Modify: `lib/data/database.dart` (tabla `Productos`, `schemaVersion`, migración), regenerar `lib/data/database.g.dart`
- Modify: `lib/repositories/producto_repository.dart`, `lib/repositories/catalogo_repository.dart`
- Create: `test/support/esquema_v7.dart`
- Test: `test/data/migracion_test.dart`, `test/repositories/producto_repository_test.dart`

**Interfaces:**
- Produces:
  - Columnas `Producto.codigoBarras`, `marca`, `tamano`, `envase`, `tipo` (todas `String?`).
  - `class DetallesProducto { const DetallesProducto({this.codigoBarras, this.marca, this.tamano, this.envase, this.tipo}); final String? codigoBarras, marca, tamano, envase, tipo; }`
  - `class CodigoRepetido implements Exception { const CodigoRepetido(this.nombre); final String nombre; }`
  - `ProductoRepository.guardarProducto({int? id, required String nombre, required int precio, List<ProveedorDeProducto> proveedores = const [], DetallesProducto? detalles})` — `detalles == null` no toca las columnas nuevas.
  - `Future<Producto?> ProductoRepository.productoPorCodigo(String codigo)`
  - `Future<List<String>> ProductoRepository.marcasUsadas()`
  - `CatalogoRepository.guardarProductoCompleto(..., DetallesProducto? detalles)` (lo pasa a `guardarProducto`).

- [ ] **Step 1: Write the failing tests**

`test/support/esquema_v7.dart`:

```dart
import 'package:sqlite3/sqlite3.dart';

import 'esquema_v6.dart';

/// Crea en [ruta] una base con el esquema v7 (4C): el de v6 más "pedir hasta".
void crearBaseV7(String ruta) {
  crearBaseV6(ruta);
  sqlite3.open(ruta)
    ..execute('ALTER TABLE productos ADD COLUMN pedir_hasta INTEGER NULL;')
    ..userVersion = 7
    ..close();
}
```

En `test/data/migracion_test.dart` (import `../support/esquema_v7.dart`), al final de `main`:

```dart
  test('una base v7 abre en v8 sin código ni detalles', () async {
    final archivo = File('${carpeta.path}/v7.sqlite');
    crearBaseV7(archivo.path);

    final db = AppDatabase(NativeDatabase(archivo));
    addTearDown(db.close);

    final producto = await db.select(db.productos).getSingle();
    expect(producto.minimo, 5);
    expect(producto.codigoBarras, isNull);
    expect(producto.marca, isNull);
    expect(producto.tamano, isNull);
    expect(producto.envase, isNull);
    expect(producto.tipo, isNull);
  });

  test('una base v1 abre en v8 y guarda código y detalles', () async {
    final archivo = File('${carpeta.path}/v1d.sqlite');
    crearBaseV1(archivo.path);

    final db = AppDatabase(NativeDatabase(archivo));
    addTearDown(db.close);

    final id = await db.into(db.productos).insert(ProductosCompanion.insert(
        nombre: 'Coca-Cola',
        precio: 4500,
        codigoBarras: const Value('7702004003508'),
        tipo: const Value('bebidas')));
    final p = await (db.select(db.productos)..where((x) => x.id.equals(id)))
        .getSingle();
    expect((p.codigoBarras, p.tipo), ('7702004003508', 'bebidas'));
  });
```

En `test/repositories/producto_repository_test.dart` (leer primero su montaje; usa una base en memoria), agregar:

```dart
  group('código y detalles', () {
    test('guarda y lee los detalles; vacíos quedan nulos', () async {
      final repo = ProductoRepository(db);
      final id = await repo.guardarProducto(
        nombre: 'Coca-Cola',
        precio: 4500,
        detalles: const DetallesProducto(
          codigoBarras: ' 7702004003508\n',
          marca: 'Postobón ',
          tamano: '1,5 L',
          envase: 'botella_plastica',
          tipo: '  ',
        ),
      );
      final p = (await repo.productoPorCodigo('7702004003508'))!;
      expect(p.id, id);
      expect(p.marca, 'Postobón');
      expect(p.tamano, '1,5 L');
      expect(p.envase, 'botella_plastica');
      expect(p.tipo, isNull);
    });

    test('sin detalles, editar no borra los que había', () async {
      final repo = ProductoRepository(db);
      final id = await repo.guardarProducto(
          nombre: 'Pan',
          precio: 500,
          detalles: const DetallesProducto(marca: 'Bimbo'));
      await repo.guardarProducto(id: id, nombre: 'Pan tajado', precio: 600);
      final p = await (db.select(db.productos)..where((x) => x.id.equals(id)))
          .getSingle();
      expect(p.marca, 'Bimbo');
    });

    test('un código de otro producto activo no se puede repetir', () async {
      final repo = ProductoRepository(db);
      await repo.guardarProducto(
          nombre: 'Pan',
          precio: 500,
          detalles: const DetallesProducto(codigoBarras: '123'));
      expect(
        () => repo.guardarProducto(
            nombre: 'Leche',
            precio: 3000,
            detalles: const DetallesProducto(codigoBarras: '123')),
        throwsA(isA<CodigoRepetido>()
            .having((e) => e.nombre, 'nombre', 'Pan')),
      );
    });

    test('el mismo producto puede volver a guardar su código', () async {
      final repo = ProductoRepository(db);
      final id = await repo.guardarProducto(
          nombre: 'Pan',
          precio: 500,
          detalles: const DetallesProducto(codigoBarras: '123'));
      await repo.guardarProducto(
          id: id,
          nombre: 'Pan',
          precio: 600,
          detalles: const DetallesProducto(codigoBarras: '123'));
      expect((await repo.productoPorCodigo('123'))!.precio, 600);
    });

    test('un producto inactivo no bloquea su código', () async {
      final repo = ProductoRepository(db);
      final viejo = await repo.guardarProducto(
          nombre: 'Pan viejo',
          precio: 500,
          detalles: const DetallesProducto(codigoBarras: '123'));
      await repo.desactivarProducto(viejo);
      final nuevo = await repo.guardarProducto(
          nombre: 'Pan nuevo',
          precio: 600,
          detalles: const DetallesProducto(codigoBarras: '123'));
      expect((await repo.productoPorCodigo('123'))!.id, nuevo);
    });

    test('productoPorCodigo devuelve un inactivo si es el único', () async {
      final repo = ProductoRepository(db);
      final id = await repo.guardarProducto(
          nombre: 'Pan',
          precio: 500,
          detalles: const DetallesProducto(codigoBarras: '123'));
      await repo.desactivarProducto(id);
      final p = await repo.productoPorCodigo(' 123 ');
      expect(p!.activo, isFalse);
      expect(await repo.productoPorCodigo('999'), isNull);
    });

    test('marcasUsadas da las marcas de los activos sin repetir', () async {
      final repo = ProductoRepository(db);
      await repo.guardarProducto(
          nombre: 'A', precio: 1, detalles: const DetallesProducto(marca: 'Zenú'));
      await repo.guardarProducto(
          nombre: 'B', precio: 1, detalles: const DetallesProducto(marca: 'Alpina'));
      await repo.guardarProducto(
          nombre: 'C', precio: 1, detalles: const DetallesProducto(marca: 'Zenú'));
      final d = await repo.guardarProducto(
          nombre: 'D', precio: 1, detalles: const DetallesProducto(marca: 'Vieja'));
      await repo.desactivarProducto(d);
      expect(await repo.marcasUsadas(), ['Alpina', 'Zenú']);
    });
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/data/migracion_test.dart test/repositories/producto_repository_test.dart`
Expected: FAIL (no compila: no existen `codigoBarras`, `DetallesProducto`, …).

- [ ] **Step 3: Implement**

`lib/data/database.dart`, en `Productos` después de `pedirHasta`:

```dart
  /// Código de barras (Fase código de barras). Único entre los activos; lo
  /// valida el repositorio para que un inactivo pueda conservar el suyo.
  TextColumn get codigoBarras => text().nullable()();
  TextColumn get marca => text().nullable()();

  /// Libre: "1,5 L", "400 ml", "500 g".
  TextColumn get tamano => text().nullable()();

  /// Claves de `lib/util/catalogo_producto.dart`.
  TextColumn get envase => text().nullable()();
  TextColumn get tipo => text().nullable()();
```

`schemaVersion => 8`, y en `onUpgrade` después del bloque `desde < 7`:

```dart
          if (desde < 8) {
            await m.addColumn(productos, productos.codigoBarras);
            await m.addColumn(productos, productos.marca);
            await m.addColumn(productos, productos.tamano);
            await m.addColumn(productos, productos.envase);
            await m.addColumn(productos, productos.tipo);
          }
```

Regenerar: `dart run build_runner build --delete-conflicting-outputs`.

`lib/repositories/producto_repository.dart` — después de `ProveedorDeProducto`:

```dart
/// Código de barras, marca, tamaño, envase y tipo de un producto.
class DetallesProducto {
  const DetallesProducto({
    this.codigoBarras,
    this.marca,
    this.tamano,
    this.envase,
    this.tipo,
  });

  final String? codigoBarras;
  final String? marca;
  final String? tamano;
  final String? envase;
  final String? tipo;
}

/// Otro producto activo ya tiene ese código de barras.
class CodigoRepetido implements Exception {
  const CodigoRepetido(this.nombre);

  /// Nombre del producto que ya lo tiene.
  final String nombre;
}

String? _limpio(String? texto) {
  final t = texto?.trim();
  return t == null || t.isEmpty ? null : t;
}
```

En `guardarProducto`: agregar el parámetro `DetallesProducto? detalles,` y, dentro de la transacción, antes de insertar/actualizar:

```dart
      final codigo = _limpio(detalles?.codigoBarras);
      if (codigo != null) {
        final otro = await (_db.select(_db.productos)
              ..where((p) =>
                  p.codigoBarras.equals(codigo) &
                  p.activo.equals(true) &
                  (id == null ? const Constant(true) : p.id.equals(id).not())))
            .getSingleOrNull();
        if (otro != null) throw CodigoRepetido(otro.nombre);
      }
      final columnas = detalles == null
          ? const ProductosCompanion()
          : ProductosCompanion(
              codigoBarras: Value(codigo),
              marca: Value(_limpio(detalles.marca)),
              tamano: Value(_limpio(detalles.tamano)),
              envase: Value(_limpio(detalles.envase)),
              tipo: Value(_limpio(detalles.tipo)),
            );
```

y cambiar la inserción/actualización a:

```dart
      final productoId = id ??
          await _db.into(_db.productos).insert(columnas.copyWith(
              nombre: Value(limpio), precio: Value(precio)));
      if (id != null) {
        await (_db.update(_db.productos)..where((p) => p.id.equals(id)))
            .write(columnas.copyWith(
                nombre: Value(limpio), precio: Value(precio)));
      }
```

(Si `getSingleOrNull` encontrara más de uno por datos viejos, usar `.get()` y tomar `.firstOrNull`.) Agregar al final de la clase:

```dart
  /// El producto con [codigo] (recortado); prefiere el activo.
  Future<Producto?> productoPorCodigo(String codigo) async {
    final limpio = codigo.trim();
    if (limpio.isEmpty) return null;
    final filas = await (_db.select(_db.productos)
          ..where((p) => p.codigoBarras.equals(limpio)))
        .get();
    return filas.where((p) => p.activo).firstOrNull ?? filas.firstOrNull;
  }

  /// Marcas de los productos activos, sin repetir y en orden alfabético.
  Future<List<String>> marcasUsadas() async {
    final filas = await (_db.select(_db.productos)
          ..where((p) => p.activo.equals(true) & p.marca.isNotNull()))
        .get();
    return {for (final p in filas) p.marca!}.toList()..sort();
  }
```

`lib/repositories/catalogo_repository.dart` — `guardarProductoCompleto` gana `DetallesProducto? detalles,` y lo pasa: `_productos.guardarProducto(id: id, nombre: nombre, precio: precio, proveedores: vinculos, detalles: detalles)`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/data test/repositories`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/data lib/repositories test/support/esquema_v7.dart test/data test/repositories
git commit -m "Add barcode, brand, size, package and type columns to products"
```

---

### Task 2: Catálogo fijo y búsqueda de productos

**Files:**
- Create: `lib/util/catalogo_producto.dart`, `lib/util/busqueda_producto.dart`
- Test: `test/util/catalogo_producto_test.dart`

**Interfaces:**
- Produces:
  - `const Map<String, String> tiposProducto` (clave → nombre, en el orden de la spec) y `const Map<String, String> envasesProducto`.
  - `String nombreTipo(String clave)`, `String nombreEnvase(String clave)` (devuelven la clave si no existe).
  - `String? tipoDesdeOff(List<String> etiquetas)`, `String? envaseDesdeOff(List<String> etiquetas)`.
  - `bool coincideBusqueda(Producto p, String consulta)`.
  - `String? detalleProducto(Producto p)` → "Marca · Tamaño", "Marca", "Tamaño" o null.

- [ ] **Step 1: Write the failing tests**

`test/util/catalogo_producto_test.dart`:

```dart
import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/util/busqueda_producto.dart';
import 'package:app_ventas/util/catalogo_producto.dart';
import 'package:flutter_test/flutter_test.dart';

Producto _p({
  String nombre = 'Gaseosa',
  String? codigo,
  String? marca,
  String? tamano,
}) =>
    Producto(
      id: 1,
      nombre: nombre,
      precio: 1000,
      activo: true,
      controlaExistencias: false,
      minimo: 0,
      codigoBarras: codigo,
      marca: marca,
      tamano: tamano,
    );

void main() {
  group('tipoDesdeOff', () {
    test('bebidas, lácteos y desconocido', () {
      expect(tipoDesdeOff(['en:beverages', 'en:carbonated-drinks', 'en:sodas']),
          'bebidas');
      expect(tipoDesdeOff(['en:dairies', 'en:milks']), 'lacteos');
      expect(tipoDesdeOff(['en:something-else']), isNull);
      expect(tipoDesdeOff(const []), isNull);
    });
    test('licores gana sobre bebidas', () {
      expect(tipoDesdeOff(['en:beverages', 'en:alcoholic-beverages', 'en:beers']),
          'licores');
    });
  });

  group('envaseDesdeOff', () {
    test('plástico, lata y desconocido', () {
      expect(envaseDesdeOff(['en:plastic-bottle']), 'botella_plastica');
      expect(envaseDesdeOff(['en:pet-bottle']), 'botella_plastica');
      expect(envaseDesdeOff(['en:can']), 'lata');
      expect(envaseDesdeOff(['en:glass-bottle']), 'botella_vidrio');
      expect(envaseDesdeOff(['en:mystery']), isNull);
    });
  });

  test('nombres del catálogo', () {
    expect(nombreTipo('aseo_hogar'), 'Aseo del hogar');
    expect(nombreEnvase('caja'), 'Caja o tetrapak');
    expect(tiposProducto.length, 11);
    expect(envasesProducto.length, 9);
  });

  group('coincideBusqueda', () {
    test('nombre, marca y tamaño sin tildes; código exacto', () {
      final p = _p(nombre: 'Gaseosa Colombiana', codigo: '7702', marca: 'Postobón',
          tamano: '1,5 L');
      expect(coincideBusqueda(p, ''), isTrue);
      expect(coincideBusqueda(p, 'colombiana'), isTrue);
      expect(coincideBusqueda(p, '  postobon '), isTrue);
      expect(coincideBusqueda(p, '1,5'), isTrue);
      expect(coincideBusqueda(p, '7702'), isTrue);
      expect(coincideBusqueda(p, '770'), isFalse);
      expect(coincideBusqueda(p, 'pepsi'), isFalse);
    });
  });

  test('detalleProducto', () {
    expect(detalleProducto(_p(marca: 'Alpina', tamano: '1 L')), 'Alpina · 1 L');
    expect(detalleProducto(_p(marca: 'Alpina')), 'Alpina');
    expect(detalleProducto(_p(tamano: '1 L')), '1 L');
    expect(detalleProducto(_p()), isNull);
  });
}
```

(Si el constructor generado de `Producto` exige otros campos, completarlos según `database.g.dart`.)

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/util/catalogo_producto_test.dart`
Expected: FAIL (no existen los archivos).

- [ ] **Step 3: Implement**

`lib/util/catalogo_producto.dart`:

```dart
/// Tipos de producto (clave → nombre). Se guardan las claves.
const Map<String, String> tiposProducto = {
  'bebidas': 'Bebidas',
  'lacteos': 'Lácteos',
  'panaderia': 'Panadería',
  'abarrotes': 'Granos y abarrotes',
  'snacks': 'Snacks y dulces',
  'aseo_personal': 'Aseo personal',
  'aseo_hogar': 'Aseo del hogar',
  'licores': 'Licores',
  'carnes': 'Carnes y embutidos',
  'fruver': 'Frutas y verduras',
  'otros': 'Otros',
};

/// Envases (clave → nombre). Se guardan las claves.
const Map<String, String> envasesProducto = {
  'botella_plastica': 'Botella plástica',
  'botella_vidrio': 'Botella de vidrio',
  'lata': 'Lata',
  'caja': 'Caja o tetrapak',
  'bolsa': 'Bolsa',
  'paquete': 'Paquete',
  'frasco': 'Frasco',
  'granel': 'Granel',
  'otro': 'Otro',
};

String nombreTipo(String clave) => tiposProducto[clave] ?? clave;

String nombreEnvase(String clave) => envasesProducto[clave] ?? clave;

/// Palabras de las etiquetas de Open Food Facts → tipo. "licores" va primero
/// para ganarle a "bebidas" cuando una bebida es alcohólica.
const _palabrasTipo = <String, List<String>>{
  'licores': ['alcoholic-beverages', 'beers', 'wines', 'spirits', 'liquors'],
  'lacteos': ['dairies', 'milks', 'yogurts', 'cheeses', 'butters'],
  'bebidas': ['beverages', 'sodas', 'waters', 'juices', 'carbonated-drinks'],
  'panaderia': ['breads', 'bakery'],
  'snacks': ['snacks', 'chocolates', 'candies', 'biscuits', 'confectioneries'],
  'abarrotes': [
    'cereals', 'rices', 'pastas', 'legumes', 'oils', 'sugars', 'flours',
    'coffees', 'salts',
  ],
  'carnes': ['meats', 'sausages', 'hams'],
  'fruver': ['fruits', 'vegetables'],
  'aseo_personal': ['shampoos', 'soaps', 'toothpastes', 'deodorants'],
  'aseo_hogar': ['detergents', 'cleaning'],
};

/// Quita el prefijo de idioma ("en:sodas" → "sodas").
String _sinPrefijo(String etiqueta) {
  final i = etiqueta.indexOf(':');
  return (i < 0 ? etiqueta : etiqueta.substring(i + 1)).toLowerCase();
}

String? tipoDesdeOff(List<String> etiquetas) {
  final limpias = etiquetas.map(_sinPrefijo).toSet();
  for (final MapEntry(key: tipo, value: palabras) in _palabrasTipo.entries) {
    if (palabras.any(limpias.contains)) return tipo;
  }
  return null;
}

const _palabrasEnvase = <String, List<String>>{
  'botella_plastica': ['plastic-bottle', 'pet-bottle'],
  'botella_vidrio': ['glass-bottle'],
  'lata': ['can', 'aluminium-can', 'metal-can'],
  'caja': ['tetra-pak', 'carton', 'box', 'brick'],
  'bolsa': ['bag', 'sachet', 'pouch'],
  'frasco': ['jar'],
  'paquete': ['packet', 'wrapper', 'pack'],
};

String? envaseDesdeOff(List<String> etiquetas) {
  final limpias = etiquetas.map(_sinPrefijo).toSet();
  for (final MapEntry(key: envase, value: palabras)
      in _palabrasEnvase.entries) {
    if (palabras.any(limpias.contains)) return envase;
  }
  return null;
}
```

`lib/util/busqueda_producto.dart`:

```dart
import '../data/database.dart';
import 'texto_util.dart';

/// [p] coincide con lo escrito: nombre, marca o tamaño (sin tildes ni
/// mayúsculas) o el código de barras exacto. Vacío coincide con todo.
bool coincideBusqueda(Producto p, String consulta) {
  final q = sinTildes(claveNombre(consulta));
  if (q.isEmpty) return true;
  if (p.codigoBarras != null && p.codigoBarras == consulta.trim()) {
    return true;
  }
  return [p.nombre, p.marca, p.tamano]
      .whereType<String>()
      .any((t) => sinTildes(claveNombre(t)).contains(q));
}

/// "Marca · Tamaño" con lo que tenga, o null.
String? detalleProducto(Producto p) {
  final partes = [p.marca, p.tamano].whereType<String>().toList();
  return partes.isEmpty ? null : partes.join(' · ');
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/util/catalogo_producto_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/util/catalogo_producto.dart lib/util/busqueda_producto.dart test/util/catalogo_producto_test.dart
git commit -m "Add the product type and package catalog and product search matching"
```

---

### Task 3: Consulta a Open Food Facts

**Files:**
- Create: `lib/servicios/open_food_facts.dart`
- Test: `test/servicios/open_food_facts_test.dart`

**Interfaces:**
- Consumes: `tipoDesdeOff`, `envaseDesdeOff` (Tarea 2).
- Produces:
  - `class DatosProducto { const DatosProducto({this.nombre, this.marca, this.tamano, this.envase, this.tipo}); final String? nombre, marca, tamano, envase, tipo; }`
  - `abstract class ConsultaProducto { Future<DatosProducto?> buscar(String codigo); }`
  - `class OpenFoodFacts implements ConsultaProducto { OpenFoodFacts({Uri? base, Duration limite = const Duration(seconds: 5)}); }`
  - `final consultaProductoProvider = Provider<ConsultaProducto>((ref) => OpenFoodFacts());`

- [ ] **Step 1: Write the failing tests**

`test/servicios/open_food_facts_test.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:app_ventas/servicios/open_food_facts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late HttpServer servidor;
  late void Function(HttpRequest) responder;
  String? userAgent;
  String? ruta;

  setUp(() async {
    servidor = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    servidor.listen((r) {
      userAgent = r.headers.value('user-agent');
      ruta = r.uri.toString();
      responder(r);
    });
  });
  tearDown(() => servidor.close(force: true));

  OpenFoodFacts cliente({Duration limite = const Duration(seconds: 2)}) =>
      OpenFoodFacts(
          base: Uri.parse('http://127.0.0.1:${servidor.port}'), limite: limite);

  void json(Object cuerpo, {int estado = 200}) => responder = (r) {
        r.response
          ..statusCode = estado
          ..headers.contentType = ContentType.json
          ..write(jsonEncode(cuerpo))
          ..close();
      };

  test('una respuesta completa se traduce a DatosProducto', () async {
    json({
      'status': 1,
      'product': {
        'product_name': 'Coca-Cola',
        'product_name_es': 'Coca-Cola Original',
        'brands': 'Coca-Cola,FEMSA',
        'quantity': '1,5 L',
        'packaging_tags': ['en:plastic-bottle'],
        'categories_tags': ['en:beverages', 'en:sodas'],
      },
    });
    final d = (await cliente().buscar('7702535011072'))!;
    expect(d.nombre, 'Coca-Cola Original');
    expect(d.marca, 'Coca-Cola');
    expect(d.tamano, '1,5 L');
    expect(d.envase, 'botella_plastica');
    expect(d.tipo, 'bebidas');
    expect(userAgent, startsWith('VeciTienda/1.0'));
    expect(ruta, startsWith('/api/v2/product/7702535011072?fields='));
  });

  test('nombre en español vacío usa el general; campos vacíos son nulos',
      () async {
    json({
      'status': 1,
      'product': {'product_name': 'Avena', 'product_name_es': '', 'brands': ''},
    });
    final d = (await cliente().buscar('1'))!;
    expect(d.nombre, 'Avena');
    expect(d.marca, isNull);
    expect(d.tamano, isNull);
  });

  test('status 0, 404 y JSON dañado dan null', () async {
    json({'status': 0});
    expect(await cliente().buscar('1'), isNull);
    json({'status': 0}, estado: 404);
    expect(await cliente().buscar('1'), isNull);
    responder = (r) => r.response
      ..write('{no es json')
      ..close();
    expect(await cliente().buscar('1'), isNull);
  });

  test('si tarda más del límite da null', () async {
    responder = (r) async {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      r.response
        ..write('{}')
        ..close();
    };
    expect(
        await cliente(limite: const Duration(milliseconds: 100)).buscar('1'),
        isNull);
  });

  test('sin servidor da null', () async {
    final c = OpenFoodFacts(base: Uri.parse('http://127.0.0.1:1'));
    expect(await c.buscar('1'), isNull);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/servicios/open_food_facts_test.dart`
Expected: FAIL (no existe el archivo).

- [ ] **Step 3: Implement**

`lib/servicios/open_food_facts.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../util/catalogo_producto.dart';

/// Lo que se pudo averiguar de un producto por su código.
class DatosProducto {
  const DatosProducto({
    this.nombre,
    this.marca,
    this.tamano,
    this.envase,
    this.tipo,
  });

  final String? nombre;
  final String? marca;
  final String? tamano;
  final String? envase;
  final String? tipo;
}

/// Busca los datos de un producto por su código de barras. Devuelve null si
/// no lo encuentra o si falla (sin internet, lento, respuesta rara).
abstract class ConsultaProducto {
  Future<DatosProducto?> buscar(String codigo);
}

/// Open Food Facts: base abierta y gratuita de productos.
class OpenFoodFacts implements ConsultaProducto {
  OpenFoodFacts({Uri? base, this.limite = const Duration(seconds: 5)})
      : base = base ?? Uri.parse('https://world.openfoodfacts.org');

  final Uri base;
  final Duration limite;

  static const _campos = 'product_name,product_name_es,brands,quantity,'
      'packaging_tags,categories_tags';

  @override
  Future<DatosProducto?> buscar(String codigo) async {
    final cliente = HttpClient()..connectionTimeout = limite;
    try {
      return await _buscar(cliente, codigo.trim()).timeout(limite);
    } catch (_) {
      return null;
    } finally {
      cliente.close(force: true);
    }
  }

  Future<DatosProducto?> _buscar(HttpClient cliente, String codigo) async {
    final uri = base.replace(
      path: '/api/v2/product/${Uri.encodeComponent(codigo)}',
      queryParameters: {'fields': _campos},
    );
    final pedido = await cliente.getUrl(uri);
    pedido.headers.set(HttpHeaders.userAgentHeader, 'VeciTienda/1.0 (Android)');
    final respuesta = await pedido.close();
    if (respuesta.statusCode != 200) return null;
    final cuerpo = jsonDecode(await respuesta.transform(utf8.decoder).join());
    if (cuerpo is! Map || cuerpo['status'] != 1) return null;
    final p = cuerpo['product'];
    if (p is! Map) return null;

    String? texto(Object? v) {
      final t = v is String ? v.trim() : null;
      return t == null || t.isEmpty ? null : t;
    }

    List<String> etiquetas(Object? v) =>
        v is List ? v.whereType<String>().toList() : const [];

    final marcas = texto(p['brands'])?.split(',');
    return DatosProducto(
      nombre: texto(p['product_name_es']) ?? texto(p['product_name']),
      marca: marcas == null ? null : texto(marcas.first),
      tamano: texto(p['quantity']),
      envase: envaseDesdeOff(etiquetas(p['packaging_tags'])),
      tipo: tipoDesdeOff(etiquetas(p['categories_tags'])),
    );
  }
}

final consultaProductoProvider =
    Provider<ConsultaProducto>((ref) => OpenFoodFacts());
```

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/servicios/open_food_facts_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/servicios/open_food_facts.dart test/servicios/open_food_facts_test.dart
git commit -m "Look up product details on Open Food Facts by barcode"
```

---

### Task 4: Escáner (mobile_scanner)

**Files:**
- Modify: `pubspec.yaml`, `pubspec.lock`
- Create: `lib/servicios/lector_codigo.dart`, `lib/screens/escaner/escaner_screen.dart`
- Test: `test/screens/escaner/codigo_escrito_test.dart`, `test/support/lector_falso.dart`

**Interfaces:**
- Produces:
  - `abstract class LectorCodigo { Future<String?> leer(BuildContext context); }`
  - `class LectorCamara implements LectorCodigo` (abre `EscanerScreen`).
  - `final lectorCodigoProvider = Provider<LectorCodigo>((ref) => LectorCamara());`
  - `Future<String?> pedirCodigoEscrito(BuildContext context)` (diálogo; claves `campo_codigo_escrito`, `boton_usar_codigo`).
  - Soporte de pruebas: `class LectorFalso implements LectorCodigo { LectorFalso(this.codigos); final List<String?> codigos; int lecturas; }` — devuelve los códigos en orden (null cuando se acaban).

- [ ] **Step 1: Add the dependency**

Run: `flutter pub add mobile_scanner:7.4.2`
Expected: `pubspec.yaml` gana `mobile_scanner: 7.4.2`. Revisar `android/app/build.gradle(.kts)`: `minSdk` debe ser ≥ 21 (mobile_scanner 7 lo exige); si es menor, subirlo a 21 y ledgerlo.

- [ ] **Step 2: Write the failing tests**

`test/support/lector_falso.dart`:

```dart
import 'package:app_ventas/servicios/lector_codigo.dart';
import 'package:flutter/widgets.dart';

/// Devuelve [codigos] en orden, uno por lectura; null cuando se acaban.
class LectorFalso implements LectorCodigo {
  LectorFalso(this.codigos);

  final List<String?> codigos;
  int lecturas = 0;

  @override
  Future<String?> leer(BuildContext context) async =>
      lecturas < codigos.length ? codigos[lecturas++] : null;
}
```

`test/screens/escaner/codigo_escrito_test.dart`:

```dart
import 'package:app_ventas/screens/escaner/escaner_screen.dart';
import 'package:app_ventas/ui/tema_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<String?> abrir(WidgetTester tester, String escrito) async {
    String? resultado;
    await tester.pumpWidget(MaterialApp(
      theme: temaClaro(),
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => resultado = await pedirCodigoEscrito(context),
          child: const Text('abrir'),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('campo_codigo_escrito')), escrito);
    await tester.tap(find.byKey(const Key('boton_usar_codigo')));
    await tester.pumpAndSettle();
    return resultado;
  }

  testWidgets('escribir un código lo devuelve recortado', (tester) async {
    expect(await abrir(tester, ' 7702004003508 '), '7702004003508');
  });

  testWidgets('vacío no devuelve nada', (tester) async {
    expect(await abrir(tester, '   '), isNull);
  });
}
```

- [ ] **Step 3: Run to verify it fails**

Run: `flutter test test/screens/escaner/codigo_escrito_test.dart`
Expected: FAIL (no existe el archivo).

- [ ] **Step 4: Implement**

`lib/servicios/lector_codigo.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../screens/escaner/escaner_screen.dart';

/// Obtiene un código de barras (cámara o escrito). Null si se canceló.
abstract class LectorCodigo {
  Future<String?> leer(BuildContext context);
}

/// Abre el escáner de cámara.
class LectorCamara implements LectorCodigo {
  @override
  Future<String?> leer(BuildContext context) => Navigator.of(context)
      .push<String>(MaterialPageRoute(builder: (_) => const EscanerScreen()));
}

final lectorCodigoProvider = Provider<LectorCodigo>((ref) => LectorCamara());
```

`lib/screens/escaner/escaner_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../ui/boton_principal.dart';
import '../../ui/colores_app.dart';
import '../../ui/vibracion.dart';

/// Diálogo para escribir el código cuando la cámara no lo lee. Devuelve el
/// código recortado, o null si se canceló o quedó vacío.
Future<String?> pedirCodigoEscrito(BuildContext context) async {
  final controlador = TextEditingController();
  final codigo = await showDialog<String>(
    context: context,
    builder: (contexto) => AlertDialog(
      title: const Text('Escribir código'),
      content: TextField(
        key: const Key('campo_codigo_escrito'),
        controller: controlador,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Código de barras'),
        onSubmitted: (t) => Navigator.pop(contexto, t),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(contexto),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const Key('boton_usar_codigo'),
          onPressed: () => Navigator.pop(contexto, controlador.text),
          child: const Text('Usar'),
        ),
      ],
    ),
  );
  controlador.dispose();
  final limpio = codigo?.trim();
  return limpio == null || limpio.isEmpty ? null : limpio;
}

/// Cámara a pantalla completa que se cierra con el primer código leído.
class EscanerScreen extends StatefulWidget {
  const EscanerScreen({super.key});

  @override
  State<EscanerScreen> createState() => _EscanerScreenState();
}

class _EscanerScreenState extends State<EscanerScreen> {
  final _controlador = MobileScannerController(
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.code128,
    ],
  );
  bool _leido = false;

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  void _alDetectar(BarcodeCapture captura) {
    if (_leido) return;
    final codigo = captura.barcodes
        .map((b) => b.rawValue?.trim())
        .whereType<String>()
        .where((c) => c.isNotEmpty)
        .firstOrNull;
    if (codigo == null) return;
    _leido = true;
    Vibracion.exito();
    Navigator.of(context).pop(codigo);
  }

  Future<void> _escribir() async {
    final codigo = await pedirCodigoEscrito(context);
    if (codigo != null && mounted) Navigator.of(context).pop(codigo);
  }

  @override
  Widget build(BuildContext context) {
    final c = ColoresApp.of(context);
    return Scaffold(
      backgroundColor: c.velo,
      appBar: AppBar(
        title: const Text('Escanear'),
        actions: [
          IconButton(
            tooltip: 'Linterna',
            icon: const Icon(Icons.flashlight_on_rounded),
            onPressed: () => _controlador.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controlador,
            onDetect: _alDetectar,
            errorBuilder: (context, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No podemos usar la cámara',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: ColoresApp.blancoMarca, fontSize: 18),
                ),
              ),
            ),
          ),
          Center(
            child: Container(
              width: 260,
              height: 160,
              decoration: BoxDecoration(
                border: Border.all(color: ColoresApp.blancoMarca, width: 3),
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Apunta al código de barras',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: ColoresApp.blancoMarca, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  BotonPrincipal(
                    key: const Key('boton_escribir_codigo'),
                    texto: 'Escribir código',
                    icono: Icons.keyboard_rounded,
                    variante: VarianteBoton.contorno,
                    onPressed: _escribir,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

(Si la firma de `errorBuilder` de mobile_scanner 7.4.2 difiere — p. ej. recibe un tercer argumento — ajustarla a la del paquete y ledgerlo. El botón contorno sobre `velo` debe leerse: si `contorno` usa `primario` y no contrasta, usar `VarianteBoton.primario`.)

- [ ] **Step 5: Run to verify it passes**

Run: `flutter test test/screens/escaner/codigo_escrito_test.dart && flutter analyze lib/screens/escaner lib/servicios`
Expected: PASS, sin problemas.

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/servicios/lector_codigo.dart lib/screens/escaner test/screens/escaner test/support/lector_falso.dart
git commit -m "Add a camera barcode scanner with a typed fallback"
```

---

### Task 5: Ficha de producto con código y detalles

**Files:**
- Create: `lib/screens/configuracion/campos_detalle_producto.dart`
- Modify: `lib/screens/configuracion/producto_screen.dart`
- Test: `test/screens/configuracion/productos_screen_test.dart`

**Interfaces:**
- Consumes: `DetallesProducto`, `CodigoRepetido`, `marcasUsadas` (T1); `tiposProducto`, `envasesProducto`, `detalleProducto` (T2); `consultaProductoProvider`, `DatosProducto` (T3); `lectorCodigoProvider` (T4).
- Produces: `CamposDetalleProducto({required TextEditingController marca, required TextEditingController tamano, required String? envase, required String? tipo, required ValueChanged<String?> onEnvase, required ValueChanged<String?> onTipo, required List<String> marcas, String sufijo = ''})` — claves `campo_marca$sufijo`, `campo_tamano$sufijo`, `selector_envase$sufijo`, `selector_tipo$sufijo`.
- Produces: `final marcasUsadasProvider = FutureProvider.autoDispose<List<String>>(...)` en `lib/providers/productos_providers.dart`.

- [ ] **Step 1: Write the failing tests**

En `productos_screen_test.dart` (antes del cierre de `main`, no al final del archivo: tiene clases auxiliares al final), con imports `package:app_ventas/servicios/open_food_facts.dart`, `package:app_ventas/servicios/lector_codigo.dart`, `../../support/lector_falso.dart`:

```dart
  /// Consulta que responde lo dado; cuenta las búsquedas.
  ConsultaProducto consulta(DatosProducto? datos) => _ConsultaFalsa(datos);

  testWidgets('escanear en un producto nuevo llena solo lo vacío',
      (tester) async {
    await montar(tester, overrides: [
      lectorCodigoProvider.overrideWithValue(LectorFalso(['7702004003508'])),
      consultaProductoProvider.overrideWithValue(consulta(const DatosProducto(
          nombre: 'Gaseosa Colombiana',
          marca: 'Postobón',
          tamano: '1,5 L',
          envase: 'botella_plastica',
          tipo: 'bebidas'))),
    ]);
    await tester.tap(find.byKey(const Key('boton_agregar_producto')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('campo_tamano')), '2 L');
    await tester.tap(find.byKey(const Key('boton_escanear_producto')));
    await tester.pumpAndSettle();

    String texto(String clave) =>
        tester.widget<TextField>(find.byKey(Key(clave))).controller!.text;
    expect(texto('campo_codigo_producto'), '7702004003508');
    expect(texto('campo_nombre_producto'), 'Gaseosa Colombiana');
    expect(texto('campo_marca'), 'Postobón');
    expect(texto('campo_tamano'), '2 L'); // ya estaba escrito
    expect(find.text('Botella plástica'), findsOneWidget);
    expect(find.text('Bebidas'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('campo_precio_producto')), '4.500');
    await guardar(tester);
    final p = await db.select(db.productos).getSingle();
    expect((p.codigoBarras, p.marca, p.tamano, p.envase, p.tipo),
        ('7702004003508', 'Postobón', '2 L', 'botella_plastica', 'bebidas'));
  });

  testWidgets('si Open Food Facts no lo tiene, avisa', (tester) async {
    await montar(tester, overrides: [
      lectorCodigoProvider.overrideWithValue(LectorFalso(['111'])),
      consultaProductoProvider.overrideWithValue(consulta(null)),
    ]);
    await tester.tap(find.byKey(const Key('boton_agregar_producto')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('boton_escanear_producto')));
    await tester.pumpAndSettle();
    expect(find.text('No lo encontramos, llénalo a mano'), findsOneWidget);
  });

  testWidgets('un código de otro producto muestra el error y no guarda',
      (tester) async {
    await ProductoRepository(db).guardarProducto(
        nombre: 'Pan',
        precio: 500,
        detalles: const DetallesProducto(codigoBarras: '123'));
    await montar(tester);
    await tester.tap(find.byKey(const Key('boton_agregar_producto')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('campo_nombre_producto')), 'Leche');
    await tester.enterText(find.byKey(const Key('campo_precio_producto')), '3.000');
    await tester.enterText(find.byKey(const Key('campo_codigo_producto')), '123');
    await guardar(tester);
    expect(find.text('Ese código ya es de Pan'), findsOneWidget);
    expect((await db.select(db.productos).get()).length, 1);
  });

  testWidgets('la consulta que llega tarde no pisa el nombre escrito',
      (tester) async {
    final lenta = _ConsultaLenta(const DatosProducto(nombre: 'De internet'));
    await montar(tester, overrides: [
      lectorCodigoProvider.overrideWithValue(LectorFalso(['999'])),
      consultaProductoProvider.overrideWithValue(lenta),
    ]);
    await tester.tap(find.byKey(const Key('boton_agregar_producto')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('boton_escanear_producto')));
    await tester.pump();
    expect(find.byKey(const Key('texto_buscando_producto')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('campo_nombre_producto')), 'Mío');
    lenta.completar();
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TextField>(find.byKey(const Key('campo_nombre_producto')))
            .controller!
            .text,
        'Mío');
  });
```

y al final del archivo (después de las clases auxiliares existentes):

```dart
class _ConsultaFalsa implements ConsultaProducto {
  _ConsultaFalsa(this.datos);
  final DatosProducto? datos;
  @override
  Future<DatosProducto?> buscar(String codigo) async => datos;
}

class _ConsultaLenta implements ConsultaProducto {
  _ConsultaLenta(this.datos);
  final DatosProducto datos;
  final _listo = Completer<void>();
  void completar() => _listo.complete();
  @override
  Future<DatosProducto?> buscar(String codigo) async {
    await _listo.future;
    return datos;
  }
}
```

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/screens/configuracion/productos_screen_test.dart`
Expected: FAIL (no existen las claves nuevas).

- [ ] **Step 3: Implement**

`lib/providers/productos_providers.dart`:

```dart
/// Marcas ya usadas, para sugerirlas al escribir.
final marcasUsadasProvider = FutureProvider.autoDispose<List<String>>(
    (ref) => ref.watch(productoRepositoryProvider).marcasUsadas());
```

`lib/screens/configuracion/campos_detalle_producto.dart`:

```dart
import 'package:flutter/material.dart';

import '../../util/catalogo_producto.dart';

/// Marca (con sugerencias), tamaño, envase y tipo. [sufijo] distingue las
/// claves cuando hay dos formularios (la hoja rápida usa "_rapido").
class CamposDetalleProducto extends StatelessWidget {
  const CamposDetalleProducto({
    super.key,
    required this.marca,
    required this.tamano,
    required this.envase,
    required this.tipo,
    required this.onEnvase,
    required this.onTipo,
    required this.marcas,
    this.sufijo = '',
  });

  final TextEditingController marca;
  final TextEditingController tamano;
  final String? envase;
  final String? tipo;
  final ValueChanged<String?> onEnvase;
  final ValueChanged<String?> onTipo;
  final List<String> marcas;
  final String sufijo;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RawAutocomplete<String>(
          textEditingController: marca,
          focusNode: FocusNode(),
          optionsBuilder: (valor) {
            final q = valor.text.trim().toLowerCase();
            if (q.isEmpty) return const Iterable<String>.empty();
            return marcas.where((m) => m.toLowerCase().contains(q));
          },
          fieldViewBuilder: (context, controlador, foco, alEnviar) => TextField(
            key: Key('campo_marca$sufijo'),
            controller: controlador,
            focusNode: foco,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Marca'),
          ),
          optionsViewBuilder: (context, alElegir, opciones) => Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200, maxWidth: 320),
                child: ListView(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  children: [
                    for (final o in opciones)
                      ListTile(title: Text(o), onTap: () => alElegir(o)),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: Key('campo_tamano$sufijo'),
          controller: tamano,
          decoration: const InputDecoration(
              labelText: 'Tamaño', hintText: '1,5 L · 400 ml · 500 g'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String?>(
          key: Key('selector_envase$sufijo'),
          initialValue: envase,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Envase'),
          items: [
            const DropdownMenuItem(value: null, child: Text('Sin elegir')),
            for (final MapEntry(:key, :value) in envasesProducto.entries)
              DropdownMenuItem(value: key, child: Text(value)),
          ],
          onChanged: onEnvase,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String?>(
          key: Key('selector_tipo$sufijo'),
          initialValue: tipo,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Tipo'),
          items: [
            const DropdownMenuItem(value: null, child: Text('Sin elegir')),
            for (final MapEntry(:key, :value) in tiposProducto.entries)
              DropdownMenuItem(value: key, child: Text(value)),
          ],
          onChanged: onTipo,
        ),
      ],
    );
  }
}
```

Notas: el `FocusNode` de `RawAutocomplete` debe vivir en el estado del padre si el analizador o una prueba lo exige — en ese caso convertir a `StatefulWidget` y crear/disponer el `FocusNode` ahí. `DropdownButtonFormField` en Flutter 3.47 usa `initialValue` (si el analizador pide `value`, usar `value`). Como `initialValue` solo se lee al crear, cuando la consulta cambie envase/tipo el padre debe reconstruir el selector con una `ValueKey` que incluya el valor: envolver cada selector así: `KeyedSubtree(key: ValueKey('envase$envase'), child: …)`.

`producto_screen.dart`:
- Estado nuevo:

```dart
  late final _codigo =
      TextEditingController(text: widget.producto?.codigoBarras ?? '');
  late final _marca = TextEditingController(text: widget.producto?.marca ?? '');
  late final _tamano =
      TextEditingController(text: widget.producto?.tamano ?? '');
  late String? _envase = widget.producto?.envase;
  late String? _tipo = widget.producto?.tipo;
  String? _errorCodigo;
  bool _buscando = false;
```

(dispose de `_codigo`, `_marca`, `_tamano`.)

- Métodos:

```dart
  Future<void> _escanear() async {
    final codigo = await ref.read(lectorCodigoProvider).leer(context);
    if (codigo == null || !mounted) return;
    setState(() {
      _codigo.text = codigo;
      _errorCodigo = null;
    });
    await _autocompletar(codigo);
  }

  /// Llena desde Open Food Facts solo los campos que sigan vacíos.
  Future<void> _autocompletar(String codigo) async {
    if (widget.producto != null && _nombre.text.trim().isNotEmpty) return;
    setState(() => _buscando = true);
    final datos = await ref.read(consultaProductoProvider).buscar(codigo);
    if (!mounted) return;
    setState(() {
      _buscando = false;
      if (datos == null) return;
      void llenar(TextEditingController c, String? valor) {
        if (c.text.trim().isEmpty && valor != null) c.text = valor;
      }
      llenar(_nombre, datos.nombre);
      llenar(_marca, datos.marca);
      llenar(_tamano, datos.tamano);
      _envase ??= datos.envase;
      _tipo ??= datos.tipo;
    });
    if (datos == null && mounted) {
      avisar(context, 'No lo encontramos, llénalo a mano');
    }
  }
```

- En la tarjeta `DATOS`, antes del campo de nombre:

```dart
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('campo_codigo_producto'),
                    controller: _codigo,
                    keyboardType: TextInputType.number,
                    onSubmitted: (t) {
                      if (t.trim().isNotEmpty) _autocompletar(t.trim());
                    },
                    decoration: InputDecoration(
                      labelText: 'Código de barras',
                      errorText: _errorCodigo,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  key: const Key('boton_escanear_producto'),
                  tooltip: 'Escanear',
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  onPressed: _escanear,
                ),
              ],
            ),
            if (_buscando)
              Padding(
                key: const Key('texto_buscando_producto'),
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                    const SizedBox(width: 8),
                    Text('Buscando…',
                        style: TextStyle(
                            color: ColoresApp.of(context).textoSecundario)),
                  ],
                ),
              ),
            const SizedBox(height: 12),
```

y después del campo de precio:

```dart
            const SizedBox(height: 12),
            CamposDetalleProducto(
              marca: _marca,
              tamano: _tamano,
              envase: _envase,
              tipo: _tipo,
              onEnvase: (v) => setState(() => _envase = v),
              onTipo: (v) => setState(() => _tipo = v),
              marcas: ref.watch(marcasUsadasProvider).valueOrNull ?? const [],
            ),
```

- Vista previa: bajo el nombre, si `detalle` (`[_marca.text.trim(), _tamano.text.trim()].where((t) => t.isNotEmpty).join(' · ')`) no es vacío, un `Text(detalle, style: TextStyle(fontSize: 13, color: c.textoSecundario))`; `_marca` y `_tamano` necesitan `addListener(() => setState(() {}))` en `initState` o `onChanged` para refrescarla.
- En `_guardar`: `_errorCodigo = null` al validar; pasar `detalles: DetallesProducto(codigoBarras: _codigo.text, marca: _marca.text, tamano: _tamano.text, envase: _envase, tipo: _tipo)` a `guardarProductoCompleto`; y antes de `on ArgumentError`:

```dart
    } on CodigoRepetido catch (e) {
      if (mounted) {
        setState(() => _errorCodigo = 'Ese código ya es de ${e.nombre}');
      }
```

- [ ] **Step 4: Run to verify they pass**

Run: `flutter test test/screens/configuracion test/screens/recorrido`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/configuracion lib/providers/productos_providers.dart test/screens/configuracion
git commit -m "Scan and autocomplete barcode, brand, size, package and type in the product form"
```

---

### Task 6: Productos: buscar por marca/código y filtrar por tipo

**Files:**
- Modify: `lib/screens/configuracion/productos_screen.dart`
- Test: `test/screens/configuracion/productos_screen_test.dart`

**Interfaces:**
- Consumes: `coincideBusqueda`, `detalleProducto` (T2); `nombreTipo` (T2); `DetallesProducto` (T1).

- [ ] **Step 1: Write the failing tests** (antes del cierre de `main`)

```dart
  testWidgets('el buscador encuentra por marca y por código', (tester) async {
    final repo = ProductoRepository(db);
    final coca = await repo.guardarProducto(
        nombre: 'Gaseosa',
        precio: 4500,
        detalles: const DetallesProducto(
            codigoBarras: '7702', marca: 'Postobón', tamano: '1,5 L'));
    final pan = await repo.guardarProducto(nombre: 'Pan', precio: 500);
    await montar(tester);
    expect(find.descendant(
            of: find.byKey(Key('detalle_producto_$coca')),
            matching: find.text('Postobón · 1,5 L')),
        findsOneWidget);
    await tester.enterText(
        find.byKey(const Key('campo_buscar_productos')), 'postobon');
    await tester.pumpAndSettle();
    expect(find.byKey(Key('producto_item_$coca')), findsOneWidget);
    expect(find.byKey(Key('producto_item_$pan')), findsNothing);
    await tester.enterText(find.byKey(const Key('campo_buscar_productos')), '7702');
    await tester.pumpAndSettle();
    expect(find.byKey(Key('producto_item_$coca')), findsOneWidget);
  });

  testWidgets('los chips de tipo filtran la lista', (tester) async {
    final repo = ProductoRepository(db);
    final coca = await repo.guardarProducto(
        nombre: 'Gaseosa',
        precio: 4500,
        detalles: const DetallesProducto(tipo: 'bebidas'));
    final leche = await repo.guardarProducto(
        nombre: 'Leche',
        precio: 3000,
        detalles: const DetallesProducto(tipo: 'lacteos'));
    final pan = await repo.guardarProducto(nombre: 'Pan', precio: 500);
    await montar(tester);
    await tester.tap(find.byKey(const Key('filtro_tipo_producto_bebidas')));
    await tester.pumpAndSettle();
    expect(find.byKey(Key('producto_item_$coca')), findsOneWidget);
    expect(find.byKey(Key('producto_item_$leche')), findsNothing);
    expect(find.byKey(Key('producto_item_$pan')), findsNothing);
    await tester.tap(find.byKey(const Key('filtro_tipo_producto_todos')));
    await tester.pumpAndSettle();
    expect(find.byKey(Key('producto_item_$pan')), findsOneWidget);
  });

  testWidgets('con un solo tipo en uso no hay chips', (tester) async {
    await ProductoRepository(db).guardarProducto(
        nombre: 'Gaseosa',
        precio: 4500,
        detalles: const DetallesProducto(tipo: 'bebidas'));
    await montar(tester);
    expect(find.byKey(const Key('filtro_tipo_producto_todos')), findsNothing);
  });
```

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/screens/configuracion/productos_screen_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement** (`productos_screen.dart`)
- Imports: `../../util/busqueda_producto.dart`, `../../util/catalogo_producto.dart`.
- Estado: `String? _tipo;`.
- Reemplazar `_coincide` por:

```dart
  bool _coincide(Producto p) =>
      coincideBusqueda(p, _busqueda) && (_tipo == null || p.tipo == _tipo);
```

- Después del `SizedBox(height: 12)` que sigue al buscador:

```dart
              if (tiposEnUso.length >= 2) ...[
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          key: const Key('filtro_tipo_producto_todos'),
                          label: const Text('Todos'),
                          selected: _tipo == null,
                          onSelected: (_) => setState(() => _tipo = null),
                        ),
                      ),
                      for (final t in tiposEnUso)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            key: Key('filtro_tipo_producto_$t'),
                            label: Text(nombreTipo(t)),
                            selected: _tipo == t,
                            onSelected: (_) => setState(() => _tipo = t),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
```

con, antes del `return ListView`:

```dart
          final tiposEnUso = [
            for (final t in tiposProducto.keys)
              if ([...productos, ...inactivos].any((p) => p.tipo == t)) t,
          ];
```

- En el `Wrap` del subtítulo de cada producto activo, agregar primero:

```dart
                                  if (detalleProducto(p) case final d?)
                                    Text(d,
                                        key: Key('detalle_producto_${p.id}'),
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: c.textoSecundario)),
```

- [ ] **Step 4: Run to verify they pass**

Run: `flutter test test/screens/configuracion`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/configuracion/productos_screen.dart test/screens/configuracion/productos_screen_test.dart
git commit -m "Search products by brand and code and filter them by type"
```

---

### Task 7: Vender escaneando

**Files:**
- Create: `lib/screens/venta/hoja_producto_rapido.dart`
- Modify: `lib/screens/venta/registrar_venta_screen.dart`
- Test: `test/screens/venta/registrar_venta_screen_test.dart`

**Interfaces:**
- Consumes: T1–T5 (`productoPorCodigo`, `DetallesProducto`, `consultaProductoProvider`, `lectorCodigoProvider`, `CamposDetalleProducto` con sufijo `_rapido`, `coincideBusqueda`, `nombreTipo`, `tiposProducto`).
- Produces: `Future<Producto?> mostrarHojaProductoRapido(BuildContext context, {required String codigo})` — claves `hoja_producto_rapido`, `campo_nombre_rapido`, `campo_precio_rapido`, `boton_guardar_producto_rapido`, `texto_buscando_rapido`.

- [ ] **Step 1: Write the failing tests**

En `registrar_venta_screen_test.dart` (imports: `package:app_ventas/repositories/producto_repository.dart`, `package:app_ventas/servicios/lector_codigo.dart`, `package:app_ventas/servicios/open_food_facts.dart`, `package:app_ventas/providers/ticket_provider.dart`, `../../support/lector_falso.dart`). El `setUp` crea el `container`; para estas pruebas se crea uno propio con overrides:

```dart
  Future<void> abrirVentaCon(WidgetTester tester,
      {required List<String?> codigos,
      DatosProducto? datos,
      String rol = 'admin'}) async {
    container.dispose();
    container = await containerConSesion(db, rol: rol, overrides: [
      lectorCodigoProvider.overrideWithValue(LectorFalso(codigos)),
      consultaProductoProvider.overrideWithValue(_Consulta(datos)),
    ]);
    await abrirVenta(tester);
  }

  Future<void> escanear(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('boton_escanear_venta')));
    await tester.pumpAndSettle();
  }

  testWidgets('escanear un producto conocido lo suma al ticket', (tester) async {
    final id = await ProductoRepository(db).guardarProducto(
        nombre: 'Gaseosa',
        precio: 4500,
        detalles: const DetallesProducto(codigoBarras: '7702'));
    await abrirVentaCon(tester, codigos: ['7702']);
    await escanear(tester);
    expect(container.read(ticketProvider).cantidadDe('p$id'), 1);
    expect(find.text('Gaseosa agregado'), findsOneWidget);
  });

  testWidgets('el mismo código dos veces seguidas solo suma uno',
      (tester) async {
    final id = await ProductoRepository(db).guardarProducto(
        nombre: 'Gaseosa',
        precio: 4500,
        detalles: const DetallesProducto(codigoBarras: '7702'));
    await abrirVentaCon(tester, codigos: ['7702', '7702']);
    await escanear(tester);
    await escanear(tester);
    expect(container.read(ticketProvider).cantidadDe('p$id'), 1);
  });

  testWidgets('un código desconocido abre la hoja, pide precio y lo agrega',
      (tester) async {
    await abrirVentaCon(tester,
        codigos: ['7702'],
        datos: const DatosProducto(
            nombre: 'Gaseosa Colombiana', marca: 'Postobón', tipo: 'bebidas'));
    await escanear(tester);
    expect(find.byKey(const Key('hoja_producto_rapido')), findsOneWidget);
    expect(
        tester
            .widget<TextField>(find.byKey(const Key('campo_nombre_rapido')))
            .controller!
            .text,
        'Gaseosa Colombiana');
    await tester.tap(find.byKey(const Key('boton_guardar_producto_rapido')));
    await tester.pumpAndSettle();
    expect(find.text('Escribe un precio válido'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('campo_precio_rapido')), '4.500');
    await tester.tap(find.byKey(const Key('boton_guardar_producto_rapido')));
    await tester.pumpAndSettle();

    final p = await db.select(db.productos).getSingle();
    expect((p.nombre, p.precio, p.codigoBarras, p.marca, p.tipo),
        ('Gaseosa Colombiana', 4500, '7702', 'Postobón', 'bebidas'));
    expect(container.read(ticketProvider).cantidadDe('p${p.id}'), 1);
  });

  testWidgets('un vendedor también puede crear el producto escaneado',
      (tester) async {
    await abrirVentaCon(tester, codigos: ['555'], rol: 'vendedor');
    await escanear(tester);
    await tester.enterText(find.byKey(const Key('campo_nombre_rapido')), 'Arepa');
    await tester.enterText(find.byKey(const Key('campo_precio_rapido')), '2.000');
    await tester.tap(find.byKey(const Key('boton_guardar_producto_rapido')));
    await tester.pumpAndSettle();
    expect((await db.select(db.productos).getSingle()).codigoBarras, '555');
  });

  testWidgets('un código de un producto inactivo avisa y no crea otro',
      (tester) async {
    final repo = ProductoRepository(db);
    final id = await repo.guardarProducto(
        nombre: 'Pan viejo',
        precio: 500,
        detalles: const DetallesProducto(codigoBarras: '123'));
    await repo.desactivarProducto(id);
    await abrirVentaCon(tester, codigos: ['123']);
    await escanear(tester);
    expect(find.byKey(const Key('hoja_producto_rapido')), findsNothing);
    expect(find.text('Ese código es de Pan viejo (inactivo). Reactívalo en '
        'Productos'), findsOneWidget);
    expect((await db.select(db.productos).get()).length, 1);
  });

  testWidgets('código exacto + Enter en el buscador agrega el producto',
      (tester) async {
    await crearProductos(siete);
    final id = await ProductoRepository(db).guardarProducto(
        nombre: 'Gaseosa',
        precio: 4500,
        detalles: const DetallesProducto(codigoBarras: '7702'));
    await abrirVenta(tester);
    await tester.enterText(find.byKey(const Key('buscador_productos')), '7702\n');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(container.read(ticketProvider).cantidadDe('p$id'), 1);
    expect(
        tester
            .widget<TextField>(find.byKey(const Key('buscador_productos')))
            .controller!
            .text,
        '');
  });

  testWidgets('los chips de tipo filtran y el mosaico muestra el tamaño',
      (tester) async {
    await crearProductos(siete);
    final repo = ProductoRepository(db);
    final coca = await repo.guardarProducto(
        nombre: 'Gaseosa',
        precio: 4500,
        detalles: const DetallesProducto(tipo: 'bebidas', tamano: '1,5 L'));
    await repo.guardarProducto(
        nombre: 'Yogur',
        precio: 2500,
        detalles: const DetallesProducto(tipo: 'lacteos'));
    await abrirVenta(tester);
    expect(find.text(r'1,5 L · $4.500'), findsOneWidget);
    await tester.tap(find.byKey(const Key('filtro_tipo_venta_bebidas')));
    await tester.pumpAndSettle();
    expect(find.byKey(Key('producto_$coca')), findsOneWidget);
    expect(find.text('Yogur'), findsNothing);
    expect(find.text('Pan'), findsNothing);
  });
```

y una clase al final del archivo:

```dart
class _Consulta implements ConsultaProducto {
  _Consulta(this.datos);
  final DatosProducto? datos;
  @override
  Future<DatosProducto?> buscar(String codigo) async => datos;
}
```

(Si `container` es `late final` en el archivo, cambiarlo a `late`. El `tearDown` ya hace `container.dispose()`.)

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/screens/venta/registrar_venta_screen_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

`lib/screens/venta/hoja_producto_rapido.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../providers/productos_providers.dart';
import '../../providers/repository_providers.dart';
import '../../repositories/producto_repository.dart';
import '../../servicios/open_food_facts.dart';
import '../../ui/boton_principal.dart';
import '../../ui/colores_app.dart';
import '../../ui/hoja_inferior.dart';
import '../../util/formato_moneda.dart';
import '../configuracion/campos_detalle_producto.dart';

/// Crea un producto para [codigo] (autocompletado desde Open Food Facts) y
/// lo devuelve; null si se cerró sin guardar.
Future<Producto?> mostrarHojaProductoRapido(BuildContext context,
        {required String codigo}) =>
    mostrarHojaInferior<Producto>(
      context,
      titulo: 'Nuevo producto',
      builder: (_) => _HojaProductoRapido(codigo: codigo),
    );

class _HojaProductoRapido extends ConsumerStatefulWidget {
  const _HojaProductoRapido({required this.codigo});

  final String codigo;

  @override
  ConsumerState<_HojaProductoRapido> createState() =>
      _HojaProductoRapidoState();
}

class _HojaProductoRapidoState extends ConsumerState<_HojaProductoRapido> {
  final _nombre = TextEditingController();
  final _precio = TextEditingController();
  final _marca = TextEditingController();
  final _tamano = TextEditingController();
  String? _envase;
  String? _tipo;
  String? _errorNombre;
  String? _errorPrecio;
  String? _error;
  bool _buscando = true;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _autocompletar();
  }

  @override
  void dispose() {
    for (final c in [_nombre, _precio, _marca, _tamano]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _autocompletar() async {
    final datos = await ref.read(consultaProductoProvider).buscar(widget.codigo);
    if (!mounted) return;
    setState(() {
      _buscando = false;
      if (datos == null) return;
      void llenar(TextEditingController c, String? v) {
        if (c.text.trim().isEmpty && v != null) c.text = v;
      }
      llenar(_nombre, datos.nombre);
      llenar(_marca, datos.marca);
      llenar(_tamano, datos.tamano);
      _envase ??= datos.envase;
      _tipo ??= datos.tipo;
    });
  }

  Future<void> _guardar() async {
    if (_guardando) return;
    final nombre = _nombre.text.trim();
    final precio = parsearMonto(_precio.text);
    setState(() {
      _errorNombre = nombre.isEmpty ? 'Escribe un nombre' : null;
      _errorPrecio =
          precio == null || precio <= 0 ? 'Escribe un precio válido' : null;
      _error = null;
    });
    if (_errorNombre != null || _errorPrecio != null) return;
    setState(() => _guardando = true);
    try {
      final repo = ref.read(productoRepositoryProvider);
      final id = await repo.guardarProducto(
        nombre: nombre,
        precio: precio!,
        detalles: DetallesProducto(
          codigoBarras: widget.codigo,
          marca: _marca.text,
          tamano: _tamano.text,
          envase: _envase,
          tipo: _tipo,
        ),
      );
      final producto = await repo.productoPorCodigo(widget.codigo);
      if (mounted) Navigator.of(context).pop(producto?.id == id ? producto : null);
    } on CodigoRepetido catch (e) {
      if (mounted) setState(() => _error = 'Ese código ya es de ${e.nombre}');
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo guardar, intenta de nuevo');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = ColoresApp.of(context);
    return Column(
      key: const Key('hoja_producto_rapido'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Código ${widget.codigo}',
            style: TextStyle(color: c.textoSecundario)),
        if (_buscando)
          Padding(
            key: const Key('texto_buscando_rapido'),
            padding: const EdgeInsets.only(top: 8),
            child: Text('Buscando…', style: TextStyle(color: c.textoSecundario)),
          ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('campo_nombre_rapido'),
          controller: _nombre,
          textCapitalization: TextCapitalization.sentences,
          decoration:
              InputDecoration(labelText: 'Nombre', errorText: _errorNombre),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('campo_precio_rapido'),
          controller: _precio,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
              labelText: 'Precio de venta', errorText: _errorPrecio),
        ),
        const SizedBox(height: 12),
        CamposDetalleProducto(
          marca: _marca,
          tamano: _tamano,
          envase: _envase,
          tipo: _tipo,
          onEnvase: (v) => setState(() => _envase = v),
          onTipo: (v) => setState(() => _tipo = v),
          marcas: ref.watch(marcasUsadasProvider).valueOrNull ?? const [],
          sufijo: '_rapido',
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_error!, style: TextStyle(color: c.sale)),
          ),
        const SizedBox(height: 16),
        BotonPrincipal(
          key: const Key('boton_guardar_producto_rapido'),
          texto: 'Guardar y agregar',
          onPressed: _guardando ? null : _guardar,
        ),
      ],
    );
  }
}
```

(Si `mostrarHojaInferior` no hace desplazable su contenido, envolver la `Column` en `SingleChildScrollView`; la hoja es alta con el teclado abierto.)

`registrar_venta_screen.dart`:
- Imports: `../../providers/repository_providers.dart` (si falta), `../../servicios/lector_codigo.dart`, `../../util/busqueda_producto.dart`, `../../util/catalogo_producto.dart`, `hoja_producto_rapido.dart`.
- Estado: `String? _tipo; String? _ultimoCodigo; DateTime? _ultimaLectura;`.
- Métodos:

```dart
  Future<void> _escanear() async {
    final codigo = await ref.read(lectorCodigoProvider).leer(context);
    if (codigo == null || !mounted) return;
    await _usarCodigo(codigo);
  }

  /// Agrega el producto con [codigo]; si no existe, ofrece crearlo.
  Future<void> _usarCodigo(String codigo) async {
    final limpio = codigo.trim();
    final ahora = DateTime.now();
    if (limpio == _ultimoCodigo &&
        _ultimaLectura != null &&
        ahora.difference(_ultimaLectura!) < const Duration(milliseconds: 1500)) {
      return;
    }
    _ultimoCodigo = limpio;
    _ultimaLectura = ahora;
    final notifier = ref.read(ticketProvider.notifier);
    final producto =
        await ref.read(productoRepositoryProvider).productoPorCodigo(limpio);
    if (!mounted) return;
    if (producto != null && producto.activo) {
      notifier.agregarProducto(producto);
      avisar(context, '${producto.nombre} agregado');
    } else if (producto != null) {
      avisar(
        context,
        'Ese código es de ${producto.nombre} (inactivo). Reactívalo en '
        'Productos',
        error: true,
      );
    } else {
      final nuevo = await mostrarHojaProductoRapido(context, codigo: limpio);
      if (nuevo != null && mounted) notifier.agregarProducto(nuevo);
    }
  }
```

- `AppBar(title: const Text('Nueva venta'), actions: [IconButton(key: const Key('boton_escanear_venta'), tooltip: 'Escanear', icon: const Icon(Icons.qr_code_scanner_rounded), onPressed: _escanear)])`.
- Filtro de visibles: `if (coincideBusqueda(p, _busqueda.text) && (_tipo == null || p.tipo == _tipo)) p` (en lugar de `sinTildes(p.nombre).contains(_filtro)`; `_filtro` se mantiene para la ✕ y "Sin resultados").
- `TextField` del buscador fijo: `textInputAction: TextInputAction.search`, y

```dart
                      onSubmitted: (t) async {
                        final p = await ref
                            .read(productoRepositoryProvider)
                            .productoPorCodigo(t);
                        if (p == null || !p.activo || !mounted) return;
                        ref.read(ticketProvider.notifier).agregarProducto(p);
                        _busqueda.clear();
                        setState(() => _filtro = '');
                      },
```

- Bajo el buscador fijo (dentro del mismo `if (conBuscador)`), si hay ≥ 2 tipos en uso entre los productos activos, una fila de `ChoiceChip` desplazable horizontal (alto 48, padding horizontal 16) con `filtro_tipo_venta_todos` ("Todos") y `filtro_tipo_venta_{clave}` (`nombreTipo(clave)`), que cambian `_tipo`.
- Mosaico: `subtitulo: p.tamano == null ? formatoMoneda(p.precio) : '${p.tamano} · ${formatoMoneda(p.precio)}'`.

- [ ] **Step 4: Run to verify they pass**

Run: `flutter test test/screens/venta test/screens/recorrido`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/venta test/screens/venta
git commit -m "Sell by scanning, with a quick product sheet for unknown barcodes"
```

---

### Task 8: Modo oscuro, letra grande y documentos

**Files:**
- Modify: `test/screens/administracion_oscuro_test.dart`, `docs/hoja-de-ruta.md`, la spec (estado)

- [ ] **Step 1: Add the tests**

En `administracion_oscuro_test.dart`, en `datos`, darle al producto `coca` detalles (`DetallesProducto(codigoBarras: '7702004003508', marca: 'Postobón', tamano: '1,5 litros familiar', envase: 'botella_plastica', tipo: 'bebidas')` con `ProductoRepository(db).guardarProducto(id: coca, …)` repitiendo nombre, precio y proveedores) y otro producto con `tipo: 'lacteos'`, y agregar al mapa `pantallas`:

```dart
    'nueva venta con chips': (_) => const RegistrarVentaScreen(),
```

más una prueba para la hoja rápida:

```dart
  testWidgets('la hoja de producto rápido en oscuro con letra 2,0× no desborda',
      (tester) async {
    await montar(
        tester,
        (_) => Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () =>
                      mostrarHojaProductoRapido(context, codigo: '999'),
                  child: const Text('abrir'),
                ),
              ),
            ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
```

`montar` debe sobreescribir `consultaProductoProvider` con una consulta que devuelva `null` al instante (para no salir a internet en pruebas): agregar el override en `containerConSesion(db, overrides: [...])` dentro de `montar`.

- [ ] **Step 2: Run**

Run: `flutter test test/screens/administracion_oscuro_test.dart`
Expected: PASS. Si algo desborda, corregir el widget (no la prueba).

- [ ] **Step 3: Docs**

`docs/hoja-de-ruta.md`: en "Hecho", "- Código de barras — escanear para crear (autocompleta desde Open Food Facts) y para vender; marca, tamaño, envase y tipo para buscar y filtrar." y en "Pendiente de verificar" agregar "código de barras con productos reales (cámara)". Spec: `**Estado:** Implementado (falta probar la cámara con productos reales)`.

- [ ] **Step 4: Full suite**

Run: `flutter test` y `flutter analyze`
Expected: todo pasa; sin problemas.

- [ ] **Step 5: Commit**

```bash
git add test/screens/administracion_oscuro_test.dart docs
git commit -m "Check barcode screens in dark mode at large text and mark the feature implemented"
```
