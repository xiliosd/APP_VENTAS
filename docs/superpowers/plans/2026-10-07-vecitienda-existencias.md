# Fase 4B — Existencias y "Por pedir" Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Los productos que el tendero elija llevan existencias (calculadas desde el último conteo, más lo recibido, menos lo vendido); se recibe mercancía por proveedor actualizando precios, se ajusta por conteo, y una pestaña "Inventario" muestra todo y lo que hay que pedir.

**Architecture:** Esquema v6: `productos.controlaExistencias`/`minimo` y tablas `conteos_inventario`, `entradas_mercancia`, `lineas_entrada`. `InventarioRepository` calcula existencias sin tocar ventas/corrección/anulación (consultas sobre líneas posteriores al último conteo), registra conteos y entradas (en transacción, actualizando `productos_proveedores`) y arma "Por pedir" e historial. UI: pestaña Inventario (todos los usuarios), detalle de producto, hoja de ajuste, Recibir mercancía, detalle de entrada, sección "Existencias" en Producto.

**Tech Stack:** Flutter 3.47 / Dart ^3.13, flutter_riverpod 2.6, Drift 2.34 (+ build_runner), sqlite3 3.5. Sin dependencias nuevas.

**Spec:** `docs/superpowers/specs/2026-10-07-vecitienda-existencias-design.md`

## Global Constraints

- `schemaVersion = 6`; migración `desde < 6`: `addColumn(productos, controlaExistencias)`, `addColumn(productos, minimo)` (la tabla existe desde v1) y `createTable` de las tres tablas nuevas. `CopiaBaseDatos.tablas` no cambia.
- Después de cada cambio en `lib/data/database.dart`: `dart run build_runner build --delete-conflicting-outputs`.
- Existencias = último conteo + Σ líneas de entradas no anuladas con `fecha > conteo.fecha` − Σ líneas de ventas no anuladas con `fecha > conteo.fecha`. Drift guarda las fechas en segundos: algo con la **misma** fecha que el conteo se considera ya contado (comparación estricta `>`).
- Sin control (o sin conteo) → existencias null. Pueden ser negativas. La venta nunca se bloquea.
- Validaciones (`ArgumentError`, nada cambia): conteo < 0, mínimo < 0, ajustar sin control, entrada sin líneas, cantidad ≤ 0, precio ≤ 0, producto repetido en la entrada, proveedor inactivo o inexistente, anular una entrada ya anulada.
- Recibir actualiza `productos_proveedores` en la misma transacción: precio cambiado → se actualiza; sin vínculo → se crea (preferido si el producto no tenía ninguno).
- Por pedir: productos **activos** con control y existencias ≤ mínimo; grupos por proveedor preferido (por nombre, sin distinguir mayúsculas; "Sin proveedor" al final); dentro: negativos primero, luego (existencias − mínimo) ascendente, luego nombre.
- Textos exactos: "Inventario", "Recibir mercancía", "Por pedir (N)", "Todos", "12 u", "−2 u" (signo U+2212), "mín. 5", "Postobón · 3 productos" (`plural`), "Sin proveedor", "quedan 2 · mín. 6", "Nada por pedir", "Entradas recibidas", "Aún no controlas existencias", "Actívalo en Ajustes → Productos", "Ajustar conteo", "Según la app hay 12. ¿Cuántas hay?", "Nota", "Conteo guardado", "Escribe cuántas hay", "Historial", "Ana · conteo inicial 12", "Ana · 12 → 9 (−3)", "Postobón · +24", "Anular entrada", "¿Anular esta entrada?", "Las existencias se descuentan; los precios actualizados no cambian.", "Entrada anulada", "Proveedor", "Agregar producto", "Precio de compra", "Total $X", "Mercancía recibida · $X", "Existencias", "Controlar existencias", "Hay ahora", "Mínimo", "Hay 12 u", "Escribe un mínimo válido", "¿Dejar de controlar existencias?", "El historial se conserva.", "Dejar de controlar".
- Recibir, ajustar y anular entradas: cualquier usuario (queda quién). Activar/desactivar control y mínimo: en Ajustes → Producto (administrador).
- Trabajar en una rama nueva `fase4b-existencias` desde `master`.

## Review Focus

1. Una venta con la misma fecha (segundo) que el conteo → no se descuenta (ya estaba contada) (prueba en Task 2).
2. Corregir una venta quitando la línea de un producto controlado → sus existencias se recuperan (prueba en Task 2).
3. Desactivar y reactivar el control → las existencias arrancan del conteo nuevo, no del viejo (prueba en Task 2).
4. Anular una entrada dos veces → se rechaza y las existencias no bajan dos veces (prueba en Task 3).
5. Producto inactivo con existencias bajas → no aparece en "Por pedir" (prueba en Task 4).

---

### Task 1: Esquema v6

**Files:**
- Create: `lib/data/inventario.dart`
- Modify: `lib/data/database.dart`
- Regenerate: `lib/data/database.g.dart`
- Create: `test/support/esquema_v5.dart`
- Modify: `test/data/migracion_test.dart`
- Modify: `test/respaldo/copia_base_datos_test.dart` (`versionMaxima: 5` → `6`)

**Interfaces:**
- Produces: `enum TipoConteo { inicial, ajuste }` (exportado por `database.dart`); `Producto.controlaExistencias` (`bool`), `Producto.minimo` (`int`); `db.conteosInventario` (`ConteoInventario { id, productoId, cantidad, anterior?, tipo, nota?, usuarioId, fecha }`); `db.entradasMercancia` (`EntradaMercancia { id, proveedorId, usuarioId, fecha, total, nota?, anulada, anuladaPorId? }`); `db.lineasEntrada` (`LineaEntrada { id, entradaId, productoId, cantidad, precioCompra }`) con sus `Companion.insert`.

- [ ] **Step 1: Crear la rama**

```bash
git checkout master
git checkout -b fase4b-existencias
```

- [ ] **Step 2: Fixture v5**

`test/support/esquema_v5.dart`:

```dart
import 'package:sqlite3/sqlite3.dart';

import 'esquema_v4.dart';

/// Crea en [ruta] una base con el esquema v5 de la app (4A, antes de la 4B):
/// el de v4 más proveedores, costo en líneas y nombre de la tienda, con un
/// producto.
void crearBaseV5(String ruta) {
  crearBaseV4(ruta);
  sqlite3.open(ruta)
    ..execute('''
      CREATE TABLE proveedores (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL, telefono TEXT NULL, notas TEXT NULL,
        activo INTEGER NOT NULL DEFAULT 1 CHECK (activo IN (0, 1)));
      CREATE TABLE productos_proveedores (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        producto_id INTEGER NOT NULL REFERENCES productos (id),
        proveedor_id INTEGER NOT NULL REFERENCES proveedores (id),
        precio_compra INTEGER NOT NULL,
        preferido INTEGER NOT NULL DEFAULT 0 CHECK (preferido IN (0, 1)),
        UNIQUE (producto_id, proveedor_id));
      ALTER TABLE lineas_venta ADD COLUMN costo_unitario INTEGER NULL;
      ALTER TABLE configuracion_tienda ADD COLUMN nombre_tienda TEXT NULL;
      INSERT INTO productos (nombre, precio) VALUES ('Arepa', 3500);
    ''')
    ..userVersion = 5
    ..close();
}
```

- [ ] **Step 3: Escribir las pruebas que fallan**

En `test/data/migracion_test.dart`: agregar `import '../support/esquema_v5.dart';`, cambiar `expect(db.schemaVersion, 5);` por `expect(db.schemaVersion, 6);` y agregar dentro de `main()`:

```dart
  test('una base v5 abre en v6 con productos sin control de existencias',
      () async {
    final archivo = File('${carpeta.path}/v5.sqlite');
    crearBaseV5(archivo.path);

    final db = AppDatabase(NativeDatabase(archivo));
    addTearDown(db.close);

    final producto = await db.select(db.productos).getSingle();
    expect(producto.controlaExistencias, isFalse);
    expect(producto.minimo, 0);
    expect(await db.select(db.conteosInventario).get(), isEmpty);
    expect(await db.select(db.entradasMercancia).get(), isEmpty);
    expect(await db.select(db.lineasEntrada).get(), isEmpty);
  });

  for (final (version, crear) in [
    (1, crearBaseV1),
    (2, crearBaseV2),
    (3, crearBaseV3),
    (4, crearBaseV4),
  ]) {
    test('una base v$version abre en v6 y acepta conteos', () async {
      final archivo = File('${carpeta.path}/inv$version.sqlite');
      crear(archivo.path);

      final db = AppDatabase(NativeDatabase(archivo));
      addTearDown(db.close);

      final producto = await db
          .into(db.productos)
          .insert(ProductosCompanion.insert(nombre: 'Pan', precio: 500));
      final usuario = (await db.select(db.usuarios).get()).first.id;
      await db.into(db.conteosInventario).insert(
          ConteosInventarioCompanion.insert(
            productoId: producto,
            cantidad: 10,
            tipo: TipoConteo.inicial,
            usuarioId: usuario,
            fecha: DateTime(2026, 10, 7),
          ));
      expect((await db.select(db.conteosInventario).getSingle()).tipo,
          TipoConteo.inicial);
    });
  }
```

En `test/respaldo/copia_base_datos_test.dart` cambiar `versionMaxima: 5` por `versionMaxima: 6`.

- [ ] **Step 4: Correr y ver que falla**

Run: `flutter test test/data/migracion_test.dart`
Expected: FAIL de compilación (`controlaExistencias`, `conteosInventario`, `TipoConteo` no existen).

- [ ] **Step 5: Implementar**

`lib/data/inventario.dart`:

```dart
/// Un conteo inicial (al activar el control) o un ajuste por conteo físico.
enum TipoConteo { inicial, ajuste }
```

En `lib/data/database.dart`:
- `import 'inventario.dart';` y `export 'inventario.dart';` junto a los otros.
- en `Productos`, después de `activo`:

```dart

  /// Lleva conteo de existencias (Fase 4B).
  BoolColumn get controlaExistencias =>
      boolean().withDefault(const Constant(false))();

  /// Con existencias en este número o menos, el producto pasa a "Por pedir".
  IntColumn get minimo => integer().withDefault(const Constant(0))();
```

- después de `ProductosProveedores`:

```dart
/// Cuántas unidades de un producto se contaron y cuándo.
@DataClassName('ConteoInventario')
class ConteosInventario extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get productoId => integer().references(Productos, #id)();
  IntColumn get cantidad => integer()();

  /// Existencias según la app al contar; null en el conteo inicial.
  IntColumn get anterior => integer().nullable()();
  TextColumn get tipo => textEnum<TipoConteo>()();
  TextColumn get nota => text().nullable()();
  IntColumn get usuarioId => integer().references(Usuarios, #id)();
  DateTimeColumn get fecha => dateTime()();
}

/// Mercancía recibida de un proveedor.
@DataClassName('EntradaMercancia')
class EntradasMercancia extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get proveedorId => integer().references(Proveedores, #id)();
  IntColumn get usuarioId => integer().references(Usuarios, #id)();
  DateTimeColumn get fecha => dateTime()();
  IntColumn get total => integer()();
  TextColumn get nota => text().nullable()();
  BoolColumn get anulada => boolean().withDefault(const Constant(false))();
  IntColumn get anuladaPorId =>
      integer().nullable().references(Usuarios, #id)();
}

/// Un producto de una entrada de mercancía.
@DataClassName('LineaEntrada')
class LineasEntrada extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get entradaId => integer().references(EntradasMercancia, #id)();
  IntColumn get productoId => integer().references(Productos, #id)();
  IntColumn get cantidad => integer()();
  IntColumn get precioCompra => integer()();
}
```

- en `tables:`, después de `ProductosProveedores,`: `ConteosInventario,`, `EntradasMercancia,`, `LineasEntrada,`.
- `int get schemaVersion => 6;`
- en `onUpgrade`, después del bloque `if (desde < 5) {...}`:

```dart
          if (desde < 6) {
            await m.addColumn(productos, productos.controlaExistencias);
            await m.addColumn(productos, productos.minimo);
            await m.createTable(conteosInventario);
            await m.createTable(entradasMercancia);
            await m.createTable(lineasEntrada);
          }
```

Run: `dart run build_runner build --delete-conflicting-outputs`

- [ ] **Step 6: Correr y ver que pasa**

Run: `flutter test test/data test/respaldo`
Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add lib/data test/support/esquema_v5.dart test/data/migracion_test.dart test/respaldo/copia_base_datos_test.dart
git commit -m "Add stock control, counts and goods receipts (schema v6)"
```

---

### Task 2: Existencias, control y conteos

**Files:**
- Create: `lib/repositories/inventario_repository.dart`
- Modify: `lib/providers/repository_providers.dart`
- Test: `test/repositories/inventario_existencias_test.dart`

**Interfaces:**
- Consumes: tablas de Task 1; `VentaRepository.registrarVenta(lineas:)`, `LineaNueva`, `eliminarVenta`; `CorreccionRepository.anularVenta`, `corregirVenta(cantidades:)`.
- Produces: `InventarioRepository(AppDatabase db, {DateTime Function()? reloj})` con `Future<int?> existencias(int productoId)`, `Future<Map<int, int>> existenciasDe(Iterable<int> productoIds)` (solo los que tienen control y conteo), `Future<void> activarControl(int productoId, {required int cantidad, required int minimo, required Usuario por})`, `Future<void> desactivarControl(int productoId)`, `Future<void> cambiarMinimo(int productoId, int minimo)`, `Future<void> ajustarConteo(int productoId, {required int cantidad, String? nota, required Usuario por})`; `inventarioRepositoryProvider`.

- [ ] **Step 1: Escribir la prueba que falla**

`test/repositories/inventario_existencias_test.dart`:

```dart
import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/repositories/correccion_repository.dart';
import 'package:app_ventas/repositories/inventario_repository.dart';
import 'package:app_ventas/repositories/venta_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late InventarioRepository repo;
  late VentaRepository ventas;
  late Usuario ana;
  late int arepa;
  var ahora = DateTime(2026, 10, 7, 8);

  setUp(() async {
    ahora = DateTime(2026, 10, 7, 8);
    db = AppDatabase(NativeDatabase.memory());
    repo = InventarioRepository(db, reloj: () => ahora);
    ventas = VentaRepository(db);
    final id = await db.into(db.usuarios).insert(
        UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'x'));
    ana = await (db.select(db.usuarios)..where((u) => u.id.equals(id)))
        .getSingle();
    arepa = await db
        .into(db.productos)
        .insert(ProductosCompanion.insert(nombre: 'Arepa', precio: 3500));
  });

  tearDown(() => db.close());

  Future<int> vender(int cantidad, DateTime fecha) => ventas.registrarVenta(
        monto: 3500 * cantidad,
        esFiado: false,
        usuarioId: ana.id,
        fecha: fecha,
        lineas: [
          LineaNueva(
              productoId: arepa,
              descripcion: 'Arepa',
              precioUnitario: 3500,
              cantidad: cantidad),
        ],
      );

  test('sin control no hay existencias', () async {
    expect(await repo.existencias(arepa), isNull);
    expect(await repo.existenciasDe([arepa]), isEmpty);
  });

  test('el conteo inicial menos lo vendido después', () async {
    await vender(5, DateTime(2026, 10, 7, 7)); // antes de activar
    await repo.activarControl(arepa, cantidad: 20, minimo: 5, por: ana);
    await vender(3, DateTime(2026, 10, 7, 9));

    expect(await repo.existencias(arepa), 17);
    final p = await (db.select(db.productos)..where((x) => x.id.equals(arepa)))
        .getSingle();
    expect(p.controlaExistencias, isTrue);
    expect(p.minimo, 5);
  });

  test('una venta en el mismo segundo del conteo ya estaba contada',
      () async {
    await repo.activarControl(arepa, cantidad: 20, minimo: 5, por: ana);
    await vender(3, DateTime(2026, 10, 7, 8));

    expect(await repo.existencias(arepa), 20);
  });

  test('anular, corregir y deshacer se reflejan solos', () async {
    await repo.activarControl(arepa, cantidad: 20, minimo: 5, por: ana);
    final anulada = await vender(4, DateTime(2026, 10, 7, 9));
    final corregida = await vender(5, DateTime(2026, 10, 7, 10));
    final deshecha = await vender(2, DateTime(2026, 10, 7, 11));
    expect(await repo.existencias(arepa), 9);

    final correcciones = CorreccionRepository(db);
    await correcciones.anularVenta(anulada, por: ana);
    final linea = (await ventas.lineasDeVenta(corregida)).single;
    await correcciones.corregirVenta(corregida,
        monto: 0, esFiado: false, cantidades: {linea.id: 1}, por: ana);
    await ventas.eliminarVenta(deshecha);

    expect(await repo.existencias(arepa), 19);
  });

  test('quitar la línea al corregir devuelve las unidades', () async {
    final otro = await db
        .into(db.productos)
        .insert(ProductosCompanion.insert(nombre: 'Pan', precio: 500));
    await repo.activarControl(arepa, cantidad: 10, minimo: 0, por: ana);
    final venta = await ventas.registrarVenta(
      monto: 7500,
      esFiado: false,
      usuarioId: ana.id,
      fecha: DateTime(2026, 10, 7, 9),
      lineas: [
        LineaNueva(
            productoId: arepa,
            descripcion: 'Arepa',
            precioUnitario: 3500,
            cantidad: 2),
        LineaNueva(
            productoId: otro, descripcion: 'Pan', precioUnitario: 500, cantidad: 1),
      ],
    );
    expect(await repo.existencias(arepa), 8);

    final lineas = await ventas.lineasDeVenta(venta);
    await CorreccionRepository(db).corregirVenta(venta,
        monto: 0, esFiado: false, cantidades: {lineas[0].id: 0}, por: ana);

    expect(await repo.existencias(arepa), 10);
  });

  test('un ajuste deja atrás lo vendido antes y guarda lo anterior',
      () async {
    await repo.activarControl(arepa, cantidad: 20, minimo: 5, por: ana);
    await vender(3, DateTime(2026, 10, 7, 9));
    ahora = DateTime(2026, 10, 7, 10);
    await repo.ajustarConteo(arepa, cantidad: 15, nota: 'Revisión', por: ana);
    await vender(1, DateTime(2026, 10, 7, 11));

    expect(await repo.existencias(arepa), 14);
    final ajuste = (await db.select(db.conteosInventario).get()).last;
    expect(ajuste.tipo, TipoConteo.ajuste);
    expect(ajuste.anterior, 17);
    expect(ajuste.nota, 'Revisión');
  });

  test('puede quedar en negativo', () async {
    await repo.activarControl(arepa, cantidad: 1, minimo: 0, por: ana);
    await vender(3, DateTime(2026, 10, 7, 9));
    expect(await repo.existencias(arepa), -2);
  });

  test('desactivar quita las existencias y reactivar parte de un conteo nuevo',
      () async {
    await repo.activarControl(arepa, cantidad: 20, minimo: 5, por: ana);
    await vender(3, DateTime(2026, 10, 7, 9));
    await repo.desactivarControl(arepa);
    expect(await repo.existencias(arepa), isNull);

    ahora = DateTime(2026, 10, 7, 12);
    await repo.activarControl(arepa, cantidad: 6, minimo: 2, por: ana);
    await vender(1, DateTime(2026, 10, 7, 13));
    expect(await repo.existencias(arepa), 5);
  });

  test('cambiar el mínimo', () async {
    await repo.activarControl(arepa, cantidad: 20, minimo: 5, por: ana);
    await repo.cambiarMinimo(arepa, 8);
    final p = await (db.select(db.productos)..where((x) => x.id.equals(arepa)))
        .getSingle();
    expect(p.minimo, 8);
  });

  test('valores inválidos se rechazan sin cambiar nada', () async {
    await expectLater(
        repo.activarControl(arepa, cantidad: -1, minimo: 0, por: ana),
        throwsArgumentError);
    await expectLater(
        repo.activarControl(arepa, cantidad: 1, minimo: -1, por: ana),
        throwsArgumentError);
    await expectLater(repo.ajustarConteo(arepa, cantidad: 3, por: ana),
        throwsArgumentError); // sin control
    await expectLater(repo.cambiarMinimo(arepa, -2), throwsArgumentError);
    expect(await db.select(db.conteosInventario).get(), isEmpty);

    await repo.activarControl(arepa, cantidad: 4, minimo: 1, por: ana);
    await expectLater(repo.ajustarConteo(arepa, cantidad: -1, por: ana),
        throwsArgumentError);
    expect(await db.select(db.conteosInventario).get(), hasLength(1));
  });
}
```

- [ ] **Step 2: Correr y ver que falla**

Run: `flutter test test/repositories/inventario_existencias_test.dart`
Expected: FAIL (`inventario_repository.dart` no existe).

- [ ] **Step 3: Implementar**

`lib/repositories/inventario_repository.dart`:

```dart
import 'package:drift/drift.dart';

import '../data/database.dart';

/// Existencias, conteos y entradas de mercancía. Las existencias no se
/// guardan: salen del último conteo, más lo recibido y menos lo vendido
/// después de él.
class InventarioRepository {
  InventarioRepository(this._db, {DateTime Function()? reloj})
      : _reloj = reloj ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _reloj;

  // ---- Existencias ----

  Future<int?> existencias(int productoId) async =>
      (await existenciasDe([productoId]))[productoId];

  /// Existencias de los productos de [productoIds] que tienen control y
  /// conteo (los demás no aparecen).
  Future<Map<int, int>> existenciasDe(Iterable<int> productoIds) async {
    final resultado = <int, int>{};
    for (final id in productoIds) {
      final producto = await (_db.select(_db.productos)
            ..where((p) => p.id.equals(id)))
          .getSingleOrNull();
      if (producto == null || !producto.controlaExistencias) continue;
      final conteo = await _ultimoConteo(id);
      if (conteo == null) continue;

      final recibidas = await (_db.select(_db.lineasEntrada).join([
        innerJoin(_db.entradasMercancia,
            _db.entradasMercancia.id.equalsExp(_db.lineasEntrada.entradaId)),
      ])
            ..where(_db.lineasEntrada.productoId.equals(id) &
                _db.entradasMercancia.anulada.equals(false) &
                _db.entradasMercancia.fecha.isBiggerThanValue(conteo.fecha)))
          .get();
      final vendidas = await (_db.select(_db.lineasVenta).join([
        innerJoin(_db.ventas, _db.ventas.id.equalsExp(_db.lineasVenta.ventaId)),
      ])
            ..where(_db.lineasVenta.productoId.equals(id) &
                _db.ventas.anulado.equals(false) &
                _db.ventas.fecha.isBiggerThanValue(conteo.fecha)))
          .get();

      resultado[id] = conteo.cantidad +
          recibidas.fold<int>(
              0, (s, f) => s + f.readTable(_db.lineasEntrada).cantidad) -
          vendidas.fold<int>(
              0, (s, f) => s + f.readTable(_db.lineasVenta).cantidad);
    }
    return resultado;
  }

  Future<ConteoInventario?> _ultimoConteo(int productoId) =>
      (_db.select(_db.conteosInventario)
            ..where((c) => c.productoId.equals(productoId))
            ..orderBy([
              (c) => OrderingTerm.desc(c.fecha),
              (c) => OrderingTerm.desc(c.id),
            ])
            ..limit(1))
          .getSingleOrNull();

  // ---- Control y conteos ----

  /// Activa el control con [cantidad] unidades hoy y [minimo].
  Future<void> activarControl(
    int productoId, {
    required int cantidad,
    required int minimo,
    required Usuario por,
  }) async {
    if (cantidad < 0) throw ArgumentError('Escribe cuántas hay');
    if (minimo < 0) throw ArgumentError('Escribe un mínimo válido');
    await _db.transaction(() async {
      await (_db.update(_db.productos)..where((p) => p.id.equals(productoId)))
          .write(ProductosCompanion(
              controlaExistencias: const Value(true), minimo: Value(minimo)));
      await _db.into(_db.conteosInventario).insert(
            ConteosInventarioCompanion.insert(
              productoId: productoId,
              cantidad: cantidad,
              tipo: TipoConteo.inicial,
              usuarioId: por.id,
              fecha: _reloj(),
            ),
          );
    });
  }

  /// Deja de controlar existencias; el historial se conserva.
  Future<void> desactivarControl(int productoId) =>
      (_db.update(_db.productos)..where((p) => p.id.equals(productoId))).write(
          const ProductosCompanion(controlaExistencias: Value(false)));

  Future<void> cambiarMinimo(int productoId, int minimo) async {
    if (minimo < 0) throw ArgumentError('Escribe un mínimo válido');
    await (_db.update(_db.productos)..where((p) => p.id.equals(productoId)))
        .write(ProductosCompanion(minimo: Value(minimo)));
  }

  /// Registra que hay [cantidad] unidades; guarda lo que decía la app.
  Future<void> ajustarConteo(
    int productoId, {
    required int cantidad,
    String? nota,
    required Usuario por,
  }) async {
    if (cantidad < 0) throw ArgumentError('Escribe cuántas hay');
    final anterior = await existencias(productoId);
    if (anterior == null) {
      throw ArgumentError('El producto no controla existencias');
    }
    final limpia = nota?.trim() ?? '';
    await _db.into(_db.conteosInventario).insert(
          ConteosInventarioCompanion.insert(
            productoId: productoId,
            cantidad: cantidad,
            anterior: Value(anterior),
            tipo: TipoConteo.ajuste,
            nota: Value(limpia.isEmpty ? null : limpia),
            usuarioId: por.id,
            fecha: _reloj(),
          ),
        );
  }
}
```

En `lib/providers/repository_providers.dart` agregar `import '../repositories/inventario_repository.dart';` y:

```dart
final inventarioRepositoryProvider = Provider(
  (ref) => InventarioRepository(ref.watch(databaseProvider)),
);
```

- [ ] **Step 4: Correr y ver que pasa**

Run: `flutter test test/repositories/inventario_existencias_test.dart` y `flutter analyze lib`
Expected: PASS y "No issues found!"

- [ ] **Step 5: Commit**

```bash
git add lib/repositories/inventario_repository.dart lib/providers/repository_providers.dart test/repositories/inventario_existencias_test.dart
git commit -m "Compute stock from the last count and add stock control and counts"
```

---

### Task 3: Recibir mercancía y anular entradas

**Files:**
- Modify: `lib/repositories/inventario_repository.dart`
- Test: `test/repositories/inventario_entradas_test.dart`

**Interfaces:**
- Consumes: Task 2; `ProductoRepository.guardarProducto`, `proveedoresDe`, `costoDe`, `ProveedorDeProducto`; `ProveedorRepository.crear`, `desactivar`.
- Produces: `class LineaRecibida { const LineaRecibida({required int productoId, required int cantidad, required int precioCompra}); }`; `class EntradaResumen { final EntradaMercancia entrada; final String proveedor; final String usuario; }`; `Future<int> recibirMercancia({required int proveedorId, required List<LineaRecibida> lineas, String? nota, required Usuario por})`; `Future<void> anularEntrada(int entradaId, {required Usuario por})`; `Future<List<EntradaResumen>> entradasRecientes({int limite = 20})`; `Future<({EntradaResumen resumen, List<({LineaEntrada linea, String producto})> lineas})> detalleEntrada(int entradaId)`.

- [ ] **Step 1: Escribir la prueba que falla**

`test/repositories/inventario_entradas_test.dart`:

```dart
import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/repositories/inventario_repository.dart';
import 'package:app_ventas/repositories/producto_repository.dart';
import 'package:app_ventas/repositories/proveedor_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late InventarioRepository repo;
  late ProductoRepository productos;
  late Usuario ana;
  late int postobon;
  late int alpina;
  late int arepa; // con Postobón $2.500 preferido
  late int avena; // sin proveedores
  var ahora = DateTime(2026, 10, 7, 8);

  setUp(() async {
    ahora = DateTime(2026, 10, 7, 8);
    db = AppDatabase(NativeDatabase.memory());
    repo = InventarioRepository(db, reloj: () => ahora);
    productos = ProductoRepository(db);
    final id = await db.into(db.usuarios).insert(
        UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'x'));
    ana = await (db.select(db.usuarios)..where((u) => u.id.equals(id)))
        .getSingle();
    final proveedores = ProveedorRepository(db);
    postobon = await proveedores.crear(nombre: 'Postobón');
    alpina = await proveedores.crear(nombre: 'Alpina');
    arepa = await productos.guardarProducto(
      nombre: 'Arepa',
      precio: 3500,
      proveedores: [
        ProveedorDeProducto(
            proveedorId: postobon, precioCompra: 2500, preferido: true),
      ],
    );
    avena = await productos.guardarProducto(nombre: 'Avena', precio: 2000);
  });

  tearDown(() => db.close());

  test('recibir suma existencias y guarda la entrada con su total', () async {
    await repo.activarControl(arepa, cantidad: 5, minimo: 2, por: ana);
    ahora = DateTime(2026, 10, 7, 9);

    final id = await repo.recibirMercancia(
      proveedorId: postobon,
      lineas: [LineaRecibida(productoId: arepa, cantidad: 24, precioCompra: 2500)],
      nota: ' Factura 123 ',
      por: ana,
    );

    expect(await repo.existencias(arepa), 29);
    final entrada = await db.select(db.entradasMercancia).getSingle();
    expect(entrada.id, id);
    expect(entrada.total, 60000);
    expect(entrada.nota, 'Factura 123');
    expect(entrada.usuarioId, ana.id);
  });

  test('un precio distinto actualiza el del proveedor y el costo', () async {
    await repo.recibirMercancia(
      proveedorId: postobon,
      lineas: [LineaRecibida(productoId: arepa, cantidad: 10, precioCompra: 2600)],
      por: ana,
    );
    expect(await productos.costoDe(arepa), 2600);
  });

  test('un proveedor nuevo para el producto se agrega', () async {
    await repo.recibirMercancia(
      proveedorId: alpina,
      lineas: [
        LineaRecibida(productoId: avena, cantidad: 6, precioCompra: 1500),
        LineaRecibida(productoId: arepa, cantidad: 2, precioCompra: 2400),
      ],
      por: ana,
    );

    final deAvena = await productos.proveedoresDe(avena);
    expect(deAvena.single.proveedorId, alpina);
    expect(deAvena.single.preferido, isTrue);
    expect(await productos.costoDe(avena), 1500);
    final deArepa = await productos.proveedoresDe(arepa);
    expect(deArepa, hasLength(2));
    expect(await productos.costoDe(arepa), 2500);
  });

  test('un producto sin control registra la entrada pero no existencias',
      () async {
    await repo.recibirMercancia(
      proveedorId: alpina,
      lineas: [LineaRecibida(productoId: avena, cantidad: 6, precioCompra: 1500)],
      por: ana,
    );
    expect(await db.select(db.lineasEntrada).get(), hasLength(1));
    expect(await repo.existencias(avena), isNull);
  });

  test('anular descuenta existencias, no revierte precios y no se repite',
      () async {
    await repo.activarControl(arepa, cantidad: 5, minimo: 2, por: ana);
    ahora = DateTime(2026, 10, 7, 9);
    final id = await repo.recibirMercancia(
      proveedorId: postobon,
      lineas: [LineaRecibida(productoId: arepa, cantidad: 24, precioCompra: 2600)],
      por: ana,
    );

    await repo.anularEntrada(id, por: ana);

    expect(await repo.existencias(arepa), 5);
    expect(await productos.costoDe(arepa), 2600);
    final entrada = await db.select(db.entradasMercancia).getSingle();
    expect(entrada.anulada, isTrue);
    expect(entrada.anuladaPorId, ana.id);
    await expectLater(repo.anularEntrada(id, por: ana), throwsArgumentError);
    expect(await repo.existencias(arepa), 5);
  });

  test('entradas recientes y detalle traen nombres', () async {
    ahora = DateTime(2026, 10, 7, 9);
    final id = await repo.recibirMercancia(
      proveedorId: postobon,
      lineas: [LineaRecibida(productoId: arepa, cantidad: 24, precioCompra: 2500)],
      por: ana,
    );

    final recientes = await repo.entradasRecientes();
    expect(recientes.single.proveedor, 'Postobón');
    expect(recientes.single.usuario, 'Ana');
    final detalle = await repo.detalleEntrada(id);
    expect(detalle.lineas.single.producto, 'Arepa');
    expect(detalle.lineas.single.linea.cantidad, 24);
  });

  test('entradas inválidas se rechazan sin guardar nada', () async {
    final invalidas = <(int, List<LineaRecibida>)>[
      (postobon, []),
      (postobon, [LineaRecibida(productoId: arepa, cantidad: 0, precioCompra: 2500)]),
      (postobon, [LineaRecibida(productoId: arepa, cantidad: 3, precioCompra: 0)]),
      (
        postobon,
        [
          LineaRecibida(productoId: arepa, cantidad: 3, precioCompra: 2500),
          LineaRecibida(productoId: arepa, cantidad: 1, precioCompra: 2500),
        ]
      ),
      (999, [LineaRecibida(productoId: arepa, cantidad: 3, precioCompra: 2500)]),
    ];
    for (final (proveedor, lineas) in invalidas) {
      await expectLater(
          repo.recibirMercancia(proveedorId: proveedor, lineas: lineas, por: ana),
          throwsArgumentError);
    }
    await ProveedorRepository(db).desactivar(alpina);
    await expectLater(
        repo.recibirMercancia(
            proveedorId: alpina,
            lineas: [LineaRecibida(productoId: avena, cantidad: 1, precioCompra: 1)],
            por: ana),
        throwsArgumentError);

    expect(await db.select(db.entradasMercancia).get(), isEmpty);
    expect(await db.select(db.lineasEntrada).get(), isEmpty);
    expect(await productos.costoDe(arepa), 2500);
  });
}
```

- [ ] **Step 2: Correr y ver que falla**

Run: `flutter test test/repositories/inventario_entradas_test.dart`
Expected: FAIL (`LineaRecibida`, `recibirMercancia` no existen).

- [ ] **Step 3: Implementar**

En `lib/repositories/inventario_repository.dart`, antes de la clase:

```dart
/// Un producto recibido en una entrada.
class LineaRecibida {
  const LineaRecibida({
    required this.productoId,
    required this.cantidad,
    required this.precioCompra,
  });

  final int productoId;
  final int cantidad;
  final int precioCompra;
}

/// Una entrada con los nombres de su proveedor y de quien la recibió.
class EntradaResumen {
  const EntradaResumen({
    required this.entrada,
    required this.proveedor,
    required this.usuario,
  });

  final EntradaMercancia entrada;
  final String proveedor;
  final String usuario;
}
```

y dentro de la clase, al final:

```dart
  // ---- Entradas de mercancía ----

  /// Registra mercancía de [proveedorId] y actualiza los precios de ese
  /// proveedor en cada producto (o lo agrega). Devuelve el id de la entrada.
  Future<int> recibirMercancia({
    required int proveedorId,
    required List<LineaRecibida> lineas,
    String? nota,
    required Usuario por,
  }) async {
    if (lineas.isEmpty) throw ArgumentError('Agrega al menos un producto');
    if (lineas.any((l) => l.cantidad <= 0 || l.precioCompra <= 0)) {
      throw ArgumentError('Cantidad o precio inválido');
    }
    if (lineas.map((l) => l.productoId).toSet().length != lineas.length) {
      throw ArgumentError('Producto repetido');
    }
    return _db.transaction(() async {
      final proveedor = await (_db.select(_db.proveedores)
            ..where((p) => p.id.equals(proveedorId)))
          .getSingleOrNull();
      if (proveedor == null || !proveedor.activo) {
        throw ArgumentError('Proveedor inactivo');
      }
      final limpia = nota?.trim() ?? '';
      final id = await _db.into(_db.entradasMercancia).insert(
            EntradasMercanciaCompanion.insert(
              proveedorId: proveedorId,
              usuarioId: por.id,
              fecha: _reloj(),
              total: lineas.fold(0, (s, l) => s + l.cantidad * l.precioCompra),
              nota: Value(limpia.isEmpty ? null : limpia),
            ),
          );
      for (final l in lineas) {
        await _db.into(_db.lineasEntrada).insert(LineasEntradaCompanion.insert(
              entradaId: id,
              productoId: l.productoId,
              cantidad: l.cantidad,
              precioCompra: l.precioCompra,
            ));
        final vinculo = await (_db.select(_db.productosProveedores)
              ..where((v) =>
                  v.productoId.equals(l.productoId) &
                  v.proveedorId.equals(proveedorId)))
            .getSingleOrNull();
        if (vinculo != null) {
          if (vinculo.precioCompra != l.precioCompra) {
            await (_db.update(_db.productosProveedores)
                  ..where((v) => v.id.equals(vinculo.id)))
                .write(ProductosProveedoresCompanion(
                    precioCompra: Value(l.precioCompra)));
          }
        } else {
          final tienePreferido = await (_db.select(_db.productosProveedores)
                    ..where((v) =>
                        v.productoId.equals(l.productoId) &
                        v.preferido.equals(true)))
                  .get()
                  .then((f) => f.isNotEmpty);
          await _db.into(_db.productosProveedores).insert(
                ProductosProveedoresCompanion.insert(
                  productoId: l.productoId,
                  proveedorId: proveedorId,
                  precioCompra: l.precioCompra,
                  preferido: Value(!tienePreferido),
                ),
              );
        }
      }
      return id;
    });
  }

  /// La entrada deja de sumar existencias; los precios no se revierten.
  Future<void> anularEntrada(int entradaId, {required Usuario por}) async {
    await _db.transaction(() async {
      final entrada = await (_db.select(_db.entradasMercancia)
            ..where((e) => e.id.equals(entradaId)))
          .getSingle();
      if (entrada.anulada) throw ArgumentError('La entrada ya está anulada');
      await (_db.update(_db.entradasMercancia)
            ..where((e) => e.id.equals(entradaId)))
          .write(EntradasMercanciaCompanion(
              anulada: const Value(true), anuladaPorId: Value(por.id)));
    });
  }

  /// Las [limite] entradas más recientes, con nombres.
  Future<List<EntradaResumen>> entradasRecientes({int limite = 20}) async {
    final filas = await (_db.select(_db.entradasMercancia).join([
      innerJoin(_db.proveedores,
          _db.proveedores.id.equalsExp(_db.entradasMercancia.proveedorId)),
      innerJoin(_db.usuarios,
          _db.usuarios.id.equalsExp(_db.entradasMercancia.usuarioId)),
    ])
          ..orderBy([
            OrderingTerm.desc(_db.entradasMercancia.fecha),
            OrderingTerm.desc(_db.entradasMercancia.id),
          ])
          ..limit(limite))
        .get();
    return [
      for (final f in filas)
        EntradaResumen(
          entrada: f.readTable(_db.entradasMercancia),
          proveedor: f.readTable(_db.proveedores).nombre,
          usuario: f.readTable(_db.usuarios).nombre,
        ),
    ];
  }

  /// Una entrada con sus líneas y el nombre de cada producto.
  Future<({EntradaResumen resumen, List<({LineaEntrada linea, String producto})> lineas})>
      detalleEntrada(int entradaId) async {
    final f = await (_db.select(_db.entradasMercancia).join([
      innerJoin(_db.proveedores,
          _db.proveedores.id.equalsExp(_db.entradasMercancia.proveedorId)),
      innerJoin(_db.usuarios,
          _db.usuarios.id.equalsExp(_db.entradasMercancia.usuarioId)),
    ])
          ..where(_db.entradasMercancia.id.equals(entradaId)))
        .getSingle();
    final lineas = await (_db.select(_db.lineasEntrada).join([
      innerJoin(
          _db.productos, _db.productos.id.equalsExp(_db.lineasEntrada.productoId)),
    ])
          ..where(_db.lineasEntrada.entradaId.equals(entradaId))
          ..orderBy([OrderingTerm.asc(_db.lineasEntrada.id)]))
        .get();
    return (
      resumen: EntradaResumen(
        entrada: f.readTable(_db.entradasMercancia),
        proveedor: f.readTable(_db.proveedores).nombre,
        usuario: f.readTable(_db.usuarios).nombre,
      ),
      lineas: [
        for (final l in lineas)
          (
            linea: l.readTable(_db.lineasEntrada),
            producto: l.readTable(_db.productos).nombre,
          ),
      ],
    );
  }
```

- [ ] **Step 4: Correr y ver que pasa**

Run: `flutter test test/repositories` y `flutter analyze lib`
Expected: PASS y "No issues found!"

- [ ] **Step 5: Commit**

```bash
git add lib/repositories/inventario_repository.dart test/repositories/inventario_entradas_test.dart
git commit -m "Receive goods by supplier, update purchase prices and void receipts"
```

---

### Task 4: "Por pedir" e historial

**Files:**
- Modify: `lib/repositories/inventario_repository.dart`
- Test: `test/repositories/inventario_por_pedir_test.dart`

**Interfaces:**
- Consumes: Tasks 2–3.
- Produces: `class ProductoPorPedir { final Producto producto; final int existencias; }`; `class GrupoPorPedir { final Proveedor? proveedor; final List<ProductoPorPedir> productos; }`; `Future<List<GrupoPorPedir>> porPedir()`; `enum TipoMovimientoInventario { conteoInicial, ajuste, entrada }`; `class MovimientoInventario { final TipoMovimientoInventario tipo; final DateTime fecha; final int cantidad; final int? anterior; final String quien; final bool anulada; }` (`quien` = usuario en conteos, proveedor en entradas); `Future<List<MovimientoInventario>> historial(int productoId, {int limite = 30})` (más reciente primero); `Future<List<({Producto producto, int existencias})>> productosConControl()` (activos con control, por nombre).

- [ ] **Step 1: Escribir la prueba que falla**

`test/repositories/inventario_por_pedir_test.dart`:

```dart
import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/repositories/inventario_repository.dart';
import 'package:app_ventas/repositories/producto_repository.dart';
import 'package:app_ventas/repositories/proveedor_repository.dart';
import 'package:app_ventas/repositories/venta_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late InventarioRepository repo;
  late ProductoRepository productos;
  late Usuario ana;
  late int postobon;
  late int alpina;
  var ahora = DateTime(2026, 10, 7, 8);

  setUp(() async {
    ahora = DateTime(2026, 10, 7, 8);
    db = AppDatabase(NativeDatabase.memory());
    repo = InventarioRepository(db, reloj: () => ahora);
    productos = ProductoRepository(db);
    final id = await db.into(db.usuarios).insert(
        UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'x'));
    ana = await (db.select(db.usuarios)..where((u) => u.id.equals(id)))
        .getSingle();
    postobon = await ProveedorRepository(db).crear(nombre: 'Postobón');
    alpina = await ProveedorRepository(db).crear(nombre: 'alpina');
  });

  tearDown(() => db.close());

  Future<int> producto(String nombre, {int? proveedor}) =>
      productos.guardarProducto(
        nombre: nombre,
        precio: 1000,
        proveedores: proveedor == null
            ? const []
            : [
                ProveedorDeProducto(
                    proveedorId: proveedor, precioCompra: 500, preferido: true),
              ],
      );

  Future<void> controlar(int id, int hay, int minimo) =>
      repo.activarControl(id, cantidad: hay, minimo: minimo, por: ana);

  test('agrupa por proveedor preferido y ordena', () async {
    final coca = await producto('Coca', proveedor: postobon);
    final pepsi = await producto('Pepsi', proveedor: postobon);
    final colombiana = await producto('Colombiana', proveedor: postobon);
    final leche = await producto('Leche', proveedor: alpina);
    final pan = await producto('Pan');
    final sobra = await producto('Sobra', proveedor: postobon);
    await controlar(coca, 2, 6); // −4
    await controlar(pepsi, 5, 6); // −1
    await controlar(colombiana, 1, 0); // tiene suficiente: 1 > 0
    await controlar(leche, 0, 3);
    await controlar(pan, 1, 1);
    await controlar(sobra, 50, 5);
    // Colombiana queda en negativo con una venta.
    await VentaRepository(db).registrarVenta(
      monto: 3000,
      esFiado: false,
      usuarioId: ana.id,
      fecha: DateTime(2026, 10, 7, 9),
      lineas: [
        LineaNueva(
            productoId: colombiana,
            descripcion: 'Colombiana',
            precioUnitario: 1000,
            cantidad: 3),
      ],
    );

    final grupos = await repo.porPedir();

    expect(grupos.map((g) => g.proveedor?.nombre), ['alpina', 'Postobón', null]);
    expect(grupos[1].productos.map((p) => p.producto.nombre),
        ['Colombiana', 'Coca', 'Pepsi']);
    expect(grupos[1].productos.first.existencias, -2);
    expect(grupos[2].productos.single.producto.nombre, 'Pan');
  });

  test('un producto inactivo o sin control no aparece', () async {
    final coca = await producto('Coca', proveedor: postobon);
    final pepsi = await producto('Pepsi', proveedor: postobon);
    await controlar(coca, 0, 5);
    await productos.desactivarProducto(coca);
    await producto('Pan');

    expect(await repo.porPedir(), isEmpty);
    expect(pepsi, isPositive);
  });

  test('productos con control por nombre con sus existencias', () async {
    final pepsi = await producto('Pepsi');
    final coca = await producto('Coca');
    await producto('Pan');
    await controlar(pepsi, 4, 1);
    await controlar(coca, 9, 1);

    final lista = await repo.productosConControl();
    expect(lista.map((p) => (p.producto.nombre, p.existencias)),
        [('Coca', 9), ('Pepsi', 4)]);
  });

  test('el historial mezcla conteos y entradas, el más reciente primero',
      () async {
    final coca = await producto('Coca', proveedor: postobon);
    await controlar(coca, 12, 2);
    ahora = DateTime(2026, 10, 7, 9);
    final entrada = await repo.recibirMercancia(
      proveedorId: postobon,
      lineas: [LineaRecibida(productoId: coca, cantidad: 24, precioCompra: 500)],
      por: ana,
    );
    ahora = DateTime(2026, 10, 7, 10);
    await repo.ajustarConteo(coca, cantidad: 30, por: ana);
    await repo.anularEntrada(entrada, por: ana);

    final h = await repo.historial(coca);
    expect(h.map((m) => m.tipo), [
      TipoMovimientoInventario.ajuste,
      TipoMovimientoInventario.entrada,
      TipoMovimientoInventario.conteoInicial,
    ]);
    expect((h[0].anterior, h[0].cantidad, h[0].quien), (36, 30, 'Ana'));
    expect((h[1].cantidad, h[1].quien), (24, 'Postobón'));
    expect(h[1].anulada, isTrue);
    expect((h[2].cantidad, h[2].quien), (12, 'Ana'));
  });
}
```

- [ ] **Step 2: Correr y ver que falla**

Run: `flutter test test/repositories/inventario_por_pedir_test.dart`
Expected: FAIL (`porPedir`, `historial`, `productosConControl` no existen).

- [ ] **Step 3: Implementar**

En `lib/repositories/inventario_repository.dart`, antes de la clase:

```dart
/// Un producto en "Por pedir".
class ProductoPorPedir {
  const ProductoPorPedir({required this.producto, required this.existencias});

  final Producto producto;
  final int existencias;
}

/// Productos por pedir de un mismo proveedor preferido (null = sin proveedor).
class GrupoPorPedir {
  const GrupoPorPedir({required this.proveedor, required this.productos});

  final Proveedor? proveedor;
  final List<ProductoPorPedir> productos;
}

enum TipoMovimientoInventario { conteoInicial, ajuste, entrada }

/// Un evento del historial de existencias de un producto.
class MovimientoInventario {
  const MovimientoInventario({
    required this.tipo,
    required this.fecha,
    required this.cantidad,
    required this.quien,
    this.anterior,
    this.anulada = false,
  });

  final TipoMovimientoInventario tipo;
  final DateTime fecha;
  final int cantidad;

  /// Usuario que contó, o proveedor de la entrada.
  final String quien;

  /// Solo en ajustes: lo que decía la app.
  final int? anterior;

  /// Solo en entradas.
  final bool anulada;
}
```

y dentro de la clase, al final:

```dart
  // ---- Listas ----

  /// Productos activos con control, por nombre, con sus existencias.
  Future<List<({Producto producto, int existencias})>>
      productosConControl() async {
    final lista = await (_db.select(_db.productos)
          ..where((p) =>
              p.activo.equals(true) & p.controlaExistencias.equals(true))
          ..orderBy([(p) => OrderingTerm.asc(p.nombre)]))
        .get();
    final existencias = await existenciasDe(lista.map((p) => p.id));
    return [
      for (final p in lista)
        if (existencias[p.id] != null)
          (producto: p, existencias: existencias[p.id]!),
    ];
  }

  /// Productos activos con control y existencias ≤ mínimo, por proveedor
  /// preferido.
  Future<List<GrupoPorPedir>> porPedir() async {
    final faltan = [
      for (final p in await productosConControl())
        if (p.existencias <= p.producto.minimo)
          ProductoPorPedir(producto: p.producto, existencias: p.existencias),
    ];
    final preferidos = {
      for (final v in await (_db.select(_db.productosProveedores)
            ..where((v) => v.preferido.equals(true)))
          .get())
        v.productoId: v.proveedorId,
    };
    final proveedores = {
      for (final p in await _db.select(_db.proveedores).get()) p.id: p,
    };
    final grupos = <int?, List<ProductoPorPedir>>{};
    for (final p in faltan) {
      grupos.putIfAbsent(preferidos[p.producto.id], () => []).add(p);
    }
    int orden(ProductoPorPedir a, ProductoPorPedir b) {
      final negA = a.existencias < 0 ? 0 : 1;
      final negB = b.existencias < 0 ? 0 : 1;
      if (negA != negB) return negA - negB;
      final falta = (a.existencias - a.producto.minimo)
          .compareTo(b.existencias - b.producto.minimo);
      if (falta != 0) return falta;
      return a.producto.nombre.compareTo(b.producto.nombre);
    }

    final resultado = [
      for (final e in grupos.entries)
        GrupoPorPedir(
          proveedor: e.key == null ? null : proveedores[e.key],
          productos: e.value..sort(orden),
        ),
    ]..sort((a, b) {
        if (a.proveedor == null) return 1;
        if (b.proveedor == null) return -1;
        return a.proveedor!.nombre
            .toLowerCase()
            .compareTo(b.proveedor!.nombre.toLowerCase());
      });
    return resultado;
  }

  /// Conteos y entradas del producto, del más reciente al más viejo.
  Future<List<MovimientoInventario>> historial(
    int productoId, {
    int limite = 30,
  }) async {
    final usuarios = {
      for (final u in await _db.select(_db.usuarios).get()) u.id: u.nombre,
    };
    final conteos = await (_db.select(_db.conteosInventario)
          ..where((c) => c.productoId.equals(productoId)))
        .get();
    final entradas = await (_db.select(_db.lineasEntrada).join([
      innerJoin(_db.entradasMercancia,
          _db.entradasMercancia.id.equalsExp(_db.lineasEntrada.entradaId)),
      innerJoin(_db.proveedores,
          _db.proveedores.id.equalsExp(_db.entradasMercancia.proveedorId)),
    ])
          ..where(_db.lineasEntrada.productoId.equals(productoId)))
        .get();
    final movimientos = [
      for (final c in conteos)
        MovimientoInventario(
          tipo: c.tipo == TipoConteo.inicial
              ? TipoMovimientoInventario.conteoInicial
              : TipoMovimientoInventario.ajuste,
          fecha: c.fecha,
          cantidad: c.cantidad,
          anterior: c.anterior,
          quien: usuarios[c.usuarioId] ?? '',
        ),
      for (final f in entradas)
        MovimientoInventario(
          tipo: TipoMovimientoInventario.entrada,
          fecha: f.readTable(_db.entradasMercancia).fecha,
          cantidad: f.readTable(_db.lineasEntrada).cantidad,
          quien: f.readTable(_db.proveedores).nombre,
          anulada: f.readTable(_db.entradasMercancia).anulada,
        ),
    ]..sort((a, b) => b.fecha.compareTo(a.fecha));
    return movimientos.take(limite).toList();
  }
```

- [ ] **Step 4: Correr y ver que pasa**

Run: `flutter test test/repositories` y `flutter analyze lib`
Expected: PASS y "No issues found!"

- [ ] **Step 5: Commit**

```bash
git add lib/repositories/inventario_repository.dart test/repositories/inventario_por_pedir_test.dart
git commit -m "Add the reorder list grouped by preferred supplier and stock history"
```

---

### Task 5: Providers y hoja "Ajustar conteo"

**Files:**
- Create: `lib/providers/inventario_providers.dart`
- Create: `lib/screens/inventario/hoja_ajuste_conteo.dart`
- Test: `test/screens/inventario/hoja_ajuste_conteo_test.dart`

**Interfaces:**
- Consumes: `InventarioRepository` (Tasks 2–4), `sesionProvider`, `mostrarHojaInferior`, `avisar`, `BotonPrincipal`.
- Produces: providers `productosConControlProvider`, `porPedirProvider`, `entradasRecientesProvider`, `existenciasProductoProvider` (family `int?` por id), `historialInventarioProvider` (family por id), `detalleEntradaProvider` (family por id), todos recalculados con `tableUpdates()`; `Future<void> mostrarHojaAjusteConteo(BuildContext context, {required Producto producto})`; llaves `texto_segun_app`, `campo_conteo`, `campo_nota_conteo`, `boton_guardar_conteo`.

- [ ] **Step 1: Escribir la prueba que falla**

`test/screens/inventario/hoja_ajuste_conteo_test.dart`:

```dart
import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/sesion_provider.dart';
import 'package:app_ventas/repositories/inventario_repository.dart';
import 'package:app_ventas/screens/inventario/hoja_ajuste_conteo.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/montaje.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<Producto> conControl(Usuario ana, int hay) async {
    final id = await db
        .into(db.productos)
        .insert(ProductosCompanion.insert(nombre: 'Arepa', precio: 3500));
    await InventarioRepository(db, reloj: () => DateTime(2026, 10, 7, 8))
        .activarControl(id, cantidad: hay, minimo: 2, por: ana);
    return (db.select(db.productos)..where((p) => p.id.equals(id)))
        .getSingle();
  }

  Future<void> abrir(WidgetTester tester, Producto producto, container) async {
    await tester.pumpWidget(appDePrueba(
      container,
      inicio: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                mostrarHojaAjusteConteo(context, producto: producto),
            child: const Text('abrir'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  testWidgets('muestra lo que dice la app y guarda el conteo',
      (tester) async {
    final container = await containerConSesion(db);
    addTearDown(container.dispose);
    final ana = container.read(sesionProvider).usuarioActivo!;
    final producto = await conControl(ana, 12);
    await abrir(tester, producto, container);

    expect(find.text('Según la app hay 12. ¿Cuántas hay?'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('campo_conteo')), '9');
    await tester.enterText(find.byKey(const Key('campo_nota_conteo')), 'Rotas');
    await tester.tap(find.byKey(const Key('boton_guardar_conteo')));
    await tester.pumpAndSettle();

    expect(find.text('Conteo guardado'), findsOneWidget);
    final ajuste = (await db.select(db.conteosInventario).get()).last;
    expect((ajuste.cantidad, ajuste.anterior, ajuste.nota), (9, 12, 'Rotas'));
  });

  testWidgets('sin cantidad o negativa muestra el error', (tester) async {
    final container = await containerConSesion(db);
    addTearDown(container.dispose);
    final ana = container.read(sesionProvider).usuarioActivo!;
    final producto = await conControl(ana, 12);
    await abrir(tester, producto, container);

    await tester.tap(find.byKey(const Key('boton_guardar_conteo')));
    await tester.pumpAndSettle();
    expect(find.text('Escribe cuántas hay'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('campo_conteo')), '-3');
    await tester.tap(find.byKey(const Key('boton_guardar_conteo')));
    await tester.pumpAndSettle();
    expect(find.text('Escribe cuántas hay'), findsOneWidget);
    expect(await db.select(db.conteosInventario).get(), hasLength(1));
  });
}
```

- [ ] **Step 2: Correr y ver que falla**

Run: `flutter test test/screens/inventario/hoja_ajuste_conteo_test.dart`
Expected: FAIL (`hoja_ajuste_conteo.dart` no existe).

- [ ] **Step 3: Providers**

`lib/providers/inventario_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../repositories/inventario_repository.dart';
import 'database_provider.dart';
import 'repository_providers.dart';

/// Emite con cada cambio en la base (mismo patrón que fiado_providers).
final _cambiosInventarioProvider = StreamProvider<void>((ref) {
  return ref.watch(databaseProvider).tableUpdates().map((_) {});
});

final productosConControlProvider =
    FutureProvider<List<({Producto producto, int existencias})>>((ref) {
  ref.watch(_cambiosInventarioProvider);
  return ref.watch(inventarioRepositoryProvider).productosConControl();
});

final porPedirProvider = FutureProvider<List<GrupoPorPedir>>((ref) {
  ref.watch(_cambiosInventarioProvider);
  return ref.watch(inventarioRepositoryProvider).porPedir();
});

final entradasRecientesProvider = FutureProvider<List<EntradaResumen>>((ref) {
  ref.watch(_cambiosInventarioProvider);
  return ref.watch(inventarioRepositoryProvider).entradasRecientes();
});

final existenciasProductoProvider =
    FutureProvider.autoDispose.family<int?, int>((ref, productoId) {
  ref.watch(_cambiosInventarioProvider);
  return ref.watch(inventarioRepositoryProvider).existencias(productoId);
});

final historialInventarioProvider = FutureProvider.autoDispose
    .family<List<MovimientoInventario>, int>((ref, productoId) {
  ref.watch(_cambiosInventarioProvider);
  return ref.watch(inventarioRepositoryProvider).historial(productoId);
});

final detalleEntradaProvider = FutureProvider.autoDispose.family<
    ({EntradaResumen resumen, List<({LineaEntrada linea, String producto})> lineas}),
    int>((ref, entradaId) {
  ref.watch(_cambiosInventarioProvider);
  return ref.watch(inventarioRepositoryProvider).detalleEntrada(entradaId);
});
```

- [ ] **Step 4: Hoja**

`lib/screens/inventario/hoja_ajuste_conteo.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../providers/inventario_providers.dart';
import '../../providers/repository_providers.dart';
import '../../providers/sesion_provider.dart';
import '../../ui/avisos.dart';
import '../../ui/boton_principal.dart';
import '../../ui/hoja_inferior.dart';

/// Pide cuántas unidades hay de verdad y guarda el ajuste.
Future<void> mostrarHojaAjusteConteo(
  BuildContext context, {
  required Producto producto,
}) async {
  final guardado = await mostrarHojaInferior<bool>(
    context,
    titulo: 'Ajustar conteo · ${producto.nombre}',
    builder: (_) => _HojaAjusteConteo(producto: producto),
  );
  if (guardado == true && context.mounted) avisar(context, 'Conteo guardado');
}

class _HojaAjusteConteo extends ConsumerStatefulWidget {
  const _HojaAjusteConteo({required this.producto});

  final Producto producto;

  @override
  ConsumerState<_HojaAjusteConteo> createState() => _HojaAjusteConteoState();
}

class _HojaAjusteConteoState extends ConsumerState<_HojaAjusteConteo> {
  final _cantidad = TextEditingController();
  final _nota = TextEditingController();
  String? _error;
  bool _guardando = false;

  @override
  void dispose() {
    _cantidad.dispose();
    _nota.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_guardando) return;
    final cantidad = int.tryParse(_cantidad.text.trim());
    if (cantidad == null || cantidad < 0) {
      setState(() => _error = 'Escribe cuántas hay');
      return;
    }
    setState(() => _guardando = true);
    try {
      await ref.read(inventarioRepositoryProvider).ajustarConteo(
            widget.producto.id,
            cantidad: cantidad,
            nota: _nota.text,
            por: ref.read(sesionProvider).usuarioActivo!,
          );
      if (mounted) Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hay =
        ref.watch(existenciasProductoProvider(widget.producto.id)).valueOrNull;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hay != null)
          Text('Según la app hay $hay. ¿Cuántas hay?',
              key: const Key('texto_segun_app')),
        const SizedBox(height: 12),
        TextField(
          key: const Key('campo_conteo'),
          controller: _cantidad,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: 'Hay', errorText: _error),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('campo_nota_conteo'),
          controller: _nota,
          decoration: const InputDecoration(labelText: 'Nota'),
        ),
        const SizedBox(height: 16),
        BotonPrincipal(
          key: const Key('boton_guardar_conteo'),
          texto: 'Guardar',
          onPressed: _guardando ? null : _guardar,
        ),
      ],
    );
  }
}
```

- [ ] **Step 5: Correr y ver que pasa**

Run: `flutter test test/screens/inventario` y `flutter analyze lib test`
Expected: PASS y "No issues found!"

- [ ] **Step 6: Commit**

```bash
git add lib/providers/inventario_providers.dart lib/screens/inventario/hoja_ajuste_conteo.dart test/screens/inventario/hoja_ajuste_conteo_test.dart
git commit -m "Add inventory providers and the stock count adjustment sheet"
```

---

### Task 6: Sección "Existencias" en Producto

**Files:**
- Modify: `lib/screens/configuracion/producto_screen.dart`
- Modify: `test/screens/configuracion/productos_screen_test.dart`

**Interfaces:**
- Consumes: `InventarioRepository.activarControl`, `desactivarControl`, `cambiarMinimo`, `existenciasProductoProvider`, `mostrarHojaAjusteConteo` (Tasks 2, 5); `sesionProvider`.
- Produces: llaves `interruptor_existencias`, `campo_hay_ahora`, `campo_minimo`, `texto_existencias_producto`, `boton_ajustar_conteo_producto`, `confirmar_dejar_de_controlar`.

- [ ] **Step 1: Escribir las pruebas que fallan**

En `test/screens/configuracion/productos_screen_test.dart` agregar `import 'package:app_ventas/repositories/inventario_repository.dart';` y dentro de `main()` (antes del cierre; las clases auxiliares van después):

```dart
  testWidgets('activar el control pide cuántas hay y el mínimo',
      (tester) async {
    await montar(tester);

    await tester.tap(find.byKey(const Key('boton_agregar_producto')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('campo_nombre_producto')), 'Arepa');
    await tester.enterText(
        find.byKey(const Key('campo_precio_producto')), '3.500');
    await tester.ensureVisible(find.byKey(const Key('interruptor_existencias')));
    await tester.tap(find.byKey(const Key('interruptor_existencias')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('campo_hay_ahora')), '20');
    await tester.enterText(find.byKey(const Key('campo_minimo')), '5');
    await guardar(tester);

    final p = await db.select(db.productos).getSingle();
    expect(p.controlaExistencias, isTrue);
    expect(p.minimo, 5);
    expect(await InventarioRepository(db).existencias(p.id), 20);
  });

  testWidgets('sin "Hay ahora" no deja activar el control', (tester) async {
    await montar(tester);

    await tester.tap(find.byKey(const Key('boton_agregar_producto')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('campo_nombre_producto')), 'Arepa');
    await tester.enterText(
        find.byKey(const Key('campo_precio_producto')), '3.500');
    await tester.ensureVisible(find.byKey(const Key('interruptor_existencias')));
    await tester.tap(find.byKey(const Key('interruptor_existencias')));
    await tester.pumpAndSettle();
    await guardar(tester);

    expect(find.text('Escribe cuántas hay'), findsOneWidget);
    expect(await db.select(db.productos).get(), isEmpty);
  });

  testWidgets('con control muestra existencias, cambia el mínimo y desactiva',
      (tester) async {
    final id = await crearArepa();
    final container = await containerConSesion(db, nombre: 'Beto');
    final beto = container.read(sesionProvider).usuarioActivo!;
    container.dispose();
    await InventarioRepository(db)
        .activarControl(id, cantidad: 12, minimo: 3, por: beto);
    await montar(tester);

    await tester.tap(find.byKey(Key('producto_item_$id')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('interruptor_existencias')));
    expect(find.text('Hay 12 u'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('campo_minimo')), '4');
    await guardar(tester);
    expect((await db.select(db.productos).getSingle()).minimo, 4);

    await tester.tap(find.byKey(Key('producto_item_$id')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('interruptor_existencias')));
    await tester.tap(find.byKey(const Key('interruptor_existencias')));
    await tester.pumpAndSettle();
    expect(find.text('¿Dejar de controlar existencias?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirmar_dejar_de_controlar')));
    await tester.pumpAndSettle();
    await guardar(tester);

    expect((await db.select(db.productos).getSingle()).controlaExistencias,
        isFalse);
  });
```

(agregar `import 'package:app_ventas/providers/sesion_provider.dart';` si falta).

- [ ] **Step 2: Correr y ver que falla**

Run: `flutter test test/screens/configuracion/productos_screen_test.dart`
Expected: FAIL (`interruptor_existencias` no existe).

- [ ] **Step 3: Implementar**

En `lib/screens/configuracion/producto_screen.dart`:
- imports `../../providers/inventario_providers.dart`, `../../providers/sesion_provider.dart`, `../inventario/hoja_ajuste_conteo.dart`.
- estado nuevo (después de `final List<_Fila> _filas = [];`):

```dart
  late bool _controla = widget.producto?.controlaExistencias ?? false;
  late final bool _controlabaAlAbrir =
      widget.producto?.controlaExistencias ?? false;
  final _hayAhora = TextEditingController();
  late final _minimo =
      TextEditingController(text: '${widget.producto?.minimo ?? 0}');
  String? _errorHay;
  String? _errorMinimo;
```

  (y `_hayAhora.dispose(); _minimo.dispose();` en `dispose`).
- en `_guardar`, ampliar la validación inicial (dentro del primer `setState`, y salir si hay errores):

```dart
      final hay = int.tryParse(_hayAhora.text.trim());
      final minimo = int.tryParse(_minimo.text.trim());
      _errorHay = _controla && !_controlabaAlAbrir && (hay == null || hay < 0)
          ? 'Escribe cuántas hay'
          : null;
      _errorMinimo =
          _controla && (minimo == null || minimo < 0)
              ? 'Escribe un mínimo válido'
              : null;
```

  con `if (_errorNombre != null || _errorPrecio != null || _errorHay != null || _errorMinimo != null) return;` (declarar `hay` y `minimo` fuera del `setState` para usarlos después).
- reemplazar la llamada `await ref.read(productoRepositoryProvider).guardarProducto(...)` por `final productoId = await ref.read(productoRepositoryProvider).guardarProducto(...)` y, justo después:

```dart
      final inventario = ref.read(inventarioRepositoryProvider);
      if (_controla && !_controlabaAlAbrir) {
        await inventario.activarControl(productoId,
            cantidad: hay!,
            minimo: minimo!,
            por: ref.read(sesionProvider).usuarioActivo!);
      } else if (_controla) {
        await inventario.cambiarMinimo(productoId, minimo!);
      } else if (_controlabaAlAbrir) {
        await inventario.desactivarControl(productoId);
      }
```

- método nuevo:

```dart
  Future<void> _cambiarControl(bool valor) async {
    if (!valor && _controlabaAlAbrir) {
      final confirmado = await showDialog<bool>(
        context: context,
        builder: (contexto) => AlertDialog(
          title: const Text('¿Dejar de controlar existencias?'),
          content: const Text('El historial se conserva.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(contexto, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              key: const Key('confirmar_dejar_de_controlar'),
              style: TextButton.styleFrom(foregroundColor: ColoresApp.sale),
              onPressed: () => Navigator.pop(contexto, true),
              child: const Text('Dejar de controlar'),
            ),
          ],
        ),
      );
      if (confirmado != true) return;
    }
    if (mounted) setState(() => _controla = valor);
  }
```

- en el `ListView` de `build`, antes de `if (_error != null)` / del botón Guardar (después de `_resumen()`):

```dart
          const SizedBox(height: 24),
          const Text('Existencias',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          SwitchListTile(
            key: const Key('interruptor_existencias'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Controlar existencias'),
            value: _controla,
            onChanged: _cargando ? null : _cambiarControl,
          ),
          if (_controla && _controlabaAlAbrir && widget.producto != null) ...[
            Text(
              'Hay ${ref.watch(existenciasProductoProvider(widget.producto!.id)).valueOrNull ?? 0} u',
              key: const Key('texto_existencias_producto'),
            ),
            TextButton(
              key: const Key('boton_ajustar_conteo_producto'),
              onPressed: () =>
                  mostrarHojaAjusteConteo(context, producto: widget.producto!),
              child: const Text('Ajustar conteo'),
            ),
          ],
          if (_controla && !_controlabaAlAbrir)
            TextField(
              key: const Key('campo_hay_ahora'),
              controller: _hayAhora,
              keyboardType: TextInputType.number,
              decoration:
                  InputDecoration(labelText: 'Hay ahora', errorText: _errorHay),
            ),
          if (_controla)
            TextField(
              key: const Key('campo_minimo'),
              controller: _minimo,
              keyboardType: TextInputType.number,
              decoration:
                  InputDecoration(labelText: 'Mínimo', errorText: _errorMinimo),
            ),
```

- [ ] **Step 4: Correr y ver que pasa**

Run: `flutter test test/screens/configuracion` y `flutter analyze lib test`
Expected: PASS y "No issues found!"

- [ ] **Step 5: Commit**

```bash
git add lib/screens/configuracion/producto_screen.dart test/screens/configuracion/productos_screen_test.dart
git commit -m "Turn stock control on or off and set the minimum from the product screen"
```

---

### Task 7: Recibir mercancía

**Files:**
- Create: `lib/screens/inventario/recibir_mercancia_screen.dart`
- Test: `test/screens/inventario/recibir_mercancia_screen_test.dart`

**Interfaces:**
- Consumes: `InventarioRepository.recibirMercancia`, `LineaRecibida` (Task 3); `proveedoresActivosProvider`, `productosActivosProvider`; `ProductoRepository.proveedoresDe`, `costoDe`; `sesionProvider`.
- Produces: `RecibirMercanciaScreen` (al guardar hace `pop(total)` con el total en pesos); llaves `opcion_proveedor_recibir_<id>`, `boton_agregar_producto_recibir`, `campo_buscar_producto`, `opcion_producto_recibir_<id>`, `restar_recibir_<pid>`, `sumar_recibir_<pid>`, `cantidad_recibir_<pid>`, `precio_recibir_<pid>`, `quitar_recibir_<pid>`, `total_recibir`, `campo_nota_recibir`, `boton_guardar_recibir`.

- [ ] **Step 1: Escribir la prueba que falla**

`test/screens/inventario/recibir_mercancia_screen_test.dart`:

```dart
import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/sesion_provider.dart';
import 'package:app_ventas/repositories/inventario_repository.dart';
import 'package:app_ventas/repositories/producto_repository.dart';
import 'package:app_ventas/repositories/proveedor_repository.dart';
import 'package:app_ventas/screens/inventario/recibir_mercancia_screen.dart';
import 'package:app_ventas/ui/boton_principal.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/montaje.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  bool guardarHabilitado(WidgetTester tester) =>
      tester
          .widget<BotonPrincipal>(find.byKey(const Key('boton_guardar_recibir')))
          .onPressed !=
      null;

  testWidgets('recibir de punta a punta suma existencias y actualiza el costo',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final container = await containerConSesion(db);
    addTearDown(container.dispose);
    final ana = container.read(sesionProvider).usuarioActivo!;
    final postobon = await ProveedorRepository(db).crear(nombre: 'Postobón');
    final arepa = await ProductoRepository(db).guardarProducto(
      nombre: 'Arepa',
      precio: 3500,
      proveedores: [
        ProveedorDeProducto(
            proveedorId: postobon, precioCompra: 2500, preferido: true),
      ],
    );
    await InventarioRepository(db, reloj: () => DateTime(2026, 10, 7, 8))
        .activarControl(arepa, cantidad: 5, minimo: 2, por: ana);
    int? devuelto;
    await tester.pumpWidget(appDePrueba(
      container,
      inicio: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              devuelto = await Navigator.of(context).push<int>(
                  MaterialPageRoute(
                      builder: (_) => const RecibirMercanciaScreen()));
            },
            child: const Text('abrir'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(guardarHabilitado(tester), isFalse);

    await tester.tap(find.byKey(Key('opcion_proveedor_recibir_$postobon')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('boton_agregar_producto_recibir')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('campo_buscar_producto')), 'are');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('opcion_producto_recibir_$arepa')));
    await tester.pumpAndSettle();

    expect(
        tester
            .widget<TextField>(find.byKey(Key('precio_recibir_$arepa')))
            .controller!
            .text,
        '2500');
    await tester.tap(find.byKey(Key('sumar_recibir_$arepa')));
    await tester.tap(find.byKey(Key('sumar_recibir_$arepa')));
    await tester.enterText(
        find.byKey(Key('precio_recibir_$arepa')), '2.600');
    await tester.pumpAndSettle();
    expect(find.text(r'Total $7.800'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('boton_guardar_recibir')));
    await tester.tap(find.byKey(const Key('boton_guardar_recibir')));
    await tester.pumpAndSettle();

    expect(devuelto, 7800);
    expect(find.byType(RecibirMercanciaScreen), findsNothing);
    expect(await InventarioRepository(db).existencias(arepa), 8);
    expect(await ProductoRepository(db).costoDe(arepa), 2600);
  });

  testWidgets('sin precio sugerido no deja guardar hasta escribirlo',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final container = await containerConSesion(db);
    addTearDown(container.dispose);
    final alpina = await ProveedorRepository(db).crear(nombre: 'Alpina');
    final avena =
        await ProductoRepository(db).guardarProducto(nombre: 'Avena', precio: 2000);
    await tester.pumpWidget(
        appDePrueba(container, inicio: const RecibirMercanciaScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(Key('opcion_proveedor_recibir_$alpina')));
    await tester.tap(find.byKey(const Key('boton_agregar_producto_recibir')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('opcion_producto_recibir_$avena')));
    await tester.pumpAndSettle();
    expect(guardarHabilitado(tester), isFalse);

    await tester.enterText(find.byKey(Key('precio_recibir_$avena')), '1.500');
    await tester.pumpAndSettle();
    expect(guardarHabilitado(tester), isTrue);
  });
}
```

- [ ] **Step 2: Correr y ver que falla**

Run: `flutter test test/screens/inventario/recibir_mercancia_screen_test.dart`
Expected: FAIL (`recibir_mercancia_screen.dart` no existe).

- [ ] **Step 3: Implementar**

`lib/screens/inventario/recibir_mercancia_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../providers/productos_providers.dart';
import '../../providers/proveedores_providers.dart';
import '../../providers/repository_providers.dart';
import '../../providers/sesion_provider.dart';
import '../../repositories/inventario_repository.dart';
import '../../ui/boton_principal.dart';
import '../../ui/colores_app.dart';
import '../../ui/hoja_inferior.dart';
import '../../util/formato_moneda.dart';

class _Linea {
  _Linea(this.producto, String precio)
      : precio = TextEditingController(text: precio);

  final Producto producto;
  int cantidad = 1;
  final TextEditingController precio;

  int? get precioValido {
    final p = parsearMonto(precio.text);
    return p == null || p <= 0 ? null : p;
  }
}

/// Registra la mercancía que trajo un proveedor. Al guardar se cierra
/// devolviendo el total.
class RecibirMercanciaScreen extends ConsumerStatefulWidget {
  const RecibirMercanciaScreen({super.key});

  @override
  ConsumerState<RecibirMercanciaScreen> createState() =>
      _RecibirMercanciaScreenState();
}

class _RecibirMercanciaScreenState
    extends ConsumerState<RecibirMercanciaScreen> {
  Proveedor? _proveedor;
  final List<_Linea> _lineas = [];
  final _nota = TextEditingController();
  bool _guardando = false;

  @override
  void dispose() {
    for (final l in _lineas) {
      l.precio.dispose();
    }
    _nota.dispose();
    super.dispose();
  }

  Future<String> _precioSugerido(int productoId) async {
    final repo = ref.read(productoRepositoryProvider);
    final proveedor = _proveedor;
    if (proveedor != null) {
      final vinculo = (await repo.proveedoresDe(productoId))
          .where((v) => v.proveedorId == proveedor.id)
          .firstOrNull;
      if (vinculo != null) return '${vinculo.precioCompra}';
    }
    final costo = await repo.costoDe(productoId);
    return costo == null ? '' : '$costo';
  }

  Future<void> _agregarProducto() async {
    final producto = await mostrarHojaInferior<Producto>(
      context,
      titulo: 'Agregar producto',
      builder: (_) => _HojaProductos(
          excluir: {for (final l in _lineas) l.producto.id}),
    );
    if (producto == null) return;
    final precio = await _precioSugerido(producto.id);
    if (!mounted) return;
    setState(() => _lineas.add(_Linea(producto, precio)));
  }

  int get _total => _lineas.fold(
      0, (s, l) => s + l.cantidad * (l.precioValido ?? 0));

  bool get _puedeGuardar =>
      !_guardando &&
      _proveedor != null &&
      _lineas.isNotEmpty &&
      _lineas.every((l) => l.precioValido != null);

  Future<void> _guardar() async {
    if (!_puedeGuardar) return;
    setState(() => _guardando = true);
    try {
      final total = _total;
      await ref.read(inventarioRepositoryProvider).recibirMercancia(
            proveedorId: _proveedor!.id,
            lineas: [
              for (final l in _lineas)
                LineaRecibida(
                  productoId: l.producto.id,
                  cantidad: l.cantidad,
                  precioCompra: l.precioValido!,
                ),
            ],
            nota: _nota.text,
            por: ref.read(sesionProvider).usuarioActivo!,
          );
      if (mounted) Navigator.of(context).pop(total);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final proveedores =
        ref.watch(proveedoresActivosProvider).valueOrNull ?? const <Proveedor>[];
    return Scaffold(
      appBar: AppBar(title: const Text('Recibir mercancía')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Proveedor',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in proveedores)
                ChoiceChip(
                  key: Key('opcion_proveedor_recibir_${p.id}'),
                  label: Text(p.nombre),
                  selected: _proveedor?.id == p.id,
                  onSelected: (_) => setState(() => _proveedor = p),
                ),
            ],
          ),
          const SizedBox(height: 16),
          for (final l in _lineas)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(l.producto.nombre,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                        ),
                        IconButton(
                          key: Key('quitar_recibir_${l.producto.id}'),
                          tooltip: 'Quitar',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => setState(() {
                            _lineas.remove(l);
                            l.precio.dispose();
                          }),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          key: Key('restar_recibir_${l.producto.id}'),
                          tooltip: 'Restar',
                          icon: const Icon(Icons.remove_rounded),
                          onPressed: l.cantidad > 1
                              ? () => setState(() => l.cantidad--)
                              : null,
                        ),
                        Text('${l.cantidad}',
                            key: Key('cantidad_recibir_${l.producto.id}')),
                        IconButton(
                          key: Key('sumar_recibir_${l.producto.id}'),
                          tooltip: 'Sumar',
                          icon: const Icon(Icons.add_rounded),
                          onPressed: () => setState(() => l.cantidad++),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            key: Key('precio_recibir_${l.producto.id}'),
                            controller: l.precio,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                                labelText: 'Precio de compra'),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      formatoMoneda(l.cantidad * (l.precioValido ?? 0)),
                      textAlign: TextAlign.right,
                      style:
                          const TextStyle(color: ColoresApp.textoSecundario),
                    ),
                  ],
                ),
              ),
            ),
          TextButton.icon(
            key: const Key('boton_agregar_producto_recibir'),
            onPressed: _agregarProducto,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Agregar producto'),
          ),
          const SizedBox(height: 12),
          Text('Total ${formatoMoneda(_total)}',
              key: const Key('total_recibir'),
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          TextField(
            key: const Key('campo_nota_recibir'),
            controller: _nota,
            decoration: const InputDecoration(labelText: 'Nota'),
          ),
          const SizedBox(height: 24),
          BotonPrincipal(
            key: const Key('boton_guardar_recibir'),
            texto: 'Guardar',
            onPressed: _puedeGuardar ? _guardar : null,
          ),
        ],
      ),
    );
  }
}

/// Buscador de productos activos que aún no están en la entrada.
class _HojaProductos extends ConsumerStatefulWidget {
  const _HojaProductos({required this.excluir});

  final Set<int> excluir;

  @override
  ConsumerState<_HojaProductos> createState() => _HojaProductosState();
}

class _HojaProductosState extends ConsumerState<_HojaProductos> {
  String _busqueda = '';

  @override
  Widget build(BuildContext context) {
    final buscado = _busqueda.trim().toLowerCase();
    final productos = (ref.watch(productosActivosProvider).valueOrNull ??
            const <Producto>[])
        .where((p) =>
            !widget.excluir.contains(p.id) &&
            p.nombre.toLowerCase().contains(buscado))
        .toList()
      ..sort((a, b) => a.nombre.compareTo(b.nombre));
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('campo_buscar_producto'),
          autofocus: true,
          decoration: const InputDecoration(
              labelText: 'Buscar producto',
              prefixIcon: Icon(Icons.search_rounded)),
          onChanged: (v) => setState(() => _busqueda = v),
        ),
        const SizedBox(height: 8),
        for (final p in productos.take(20))
          ListTile(
            key: Key('opcion_producto_recibir_${p.id}'),
            title: Text(p.nombre),
            onTap: () => Navigator.of(context).pop(p),
          ),
      ],
    );
  }
}
```

- [ ] **Step 4: Correr y ver que pasa**

Run: `flutter test test/screens/inventario` y `flutter analyze lib test`
Expected: PASS y "No issues found!"

- [ ] **Step 5: Commit**

```bash
git add lib/screens/inventario/recibir_mercancia_screen.dart test/screens/inventario/recibir_mercancia_screen_test.dart
git commit -m "Add the Recibir mercancía screen"
```

---

### Task 8: Pestaña Inventario, detalle de producto y de entrada

**Files:**
- Create: `lib/screens/inventario/inventario_screen.dart`
- Create: `lib/screens/inventario/detalle_inventario_screen.dart`
- Create: `lib/screens/inventario/detalle_entrada_screen.dart`
- Modify: `lib/screens/home/home_screen.dart` (pestaña)
- Test: `test/screens/inventario/inventario_screen_test.dart`

**Interfaces:**
- Consumes: providers de Task 5; `mostrarHojaAjusteConteo`; `InventarioRepository.anularEntrada`; `RecibirMercanciaScreen` (Task 7, devuelve el total con `pop`).
- Produces: `InventarioScreen`, `DetalleInventarioScreen({required int productoId})`, `DetalleEntradaScreen({required int entradaId})`; llaves `boton_recibir_mercancia`, `selector_inventario`, `inventario_item_<id>`, `existencias_<id>`, `grupo_por_pedir_<proveedorId|sin>`, `por_pedir_<id>`, `texto_nada_por_pedir`, `entrada_<id>`, `existencias_detalle`, `boton_ajustar_conteo`, `boton_anular_entrada`, `confirmar_anular_entrada`; pestaña "Inventario" en `HomeScreen` (entre Fiado e Historial).

- [ ] **Step 1: Escribir la prueba que falla**

`test/screens/inventario/inventario_screen_test.dart`:

```dart
import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/sesion_provider.dart';
import 'package:app_ventas/repositories/configuracion_repository.dart';
import 'package:app_ventas/repositories/inventario_repository.dart';
import 'package:app_ventas/repositories/producto_repository.dart';
import 'package:app_ventas/repositories/proveedor_repository.dart';
import 'package:app_ventas/screens/home/home_screen.dart';
import 'package:app_ventas/screens/inventario/detalle_inventario_screen.dart';
import 'package:app_ventas/screens/inventario/inventario_screen.dart';
import 'package:app_ventas/ui/colores_app.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/montaje.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<(ProviderContainer, Usuario)> montar(WidgetTester tester,
      {String rol = 'admin'}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final container = await containerConSesion(db, rol: rol);
    addTearDown(container.dispose);
    final usuario = container.read(sesionProvider).usuarioActivo!;
    return (container, usuario);
  }

  Future<void> pintar(WidgetTester tester, ProviderContainer container,
      {Widget inicio = const Scaffold(body: InventarioScreen())}) async {
    await tester.pumpWidget(appDePrueba(container, inicio: inicio));
    await tester.pumpAndSettle();
  }

  Future<int> producto(String nombre, {int? proveedor}) =>
      ProductoRepository(db).guardarProducto(
        nombre: nombre,
        precio: 1000,
        proveedores: proveedor == null
            ? const []
            : [
                ProveedorDeProducto(
                    proveedorId: proveedor, precioCompra: 500, preferido: true),
              ],
      );

  testWidgets('sin productos con control muestra el estado vacío',
      (tester) async {
    final (container, _) = await montar(tester);
    await pintar(tester, container);
    expect(find.text('Aún no controlas existencias'), findsOneWidget);
    expect(find.byKey(const Key('boton_recibir_mercancia')), findsOneWidget);
  });

  testWidgets('abre en Por pedir y Todos marca en rojo lo que falta',
      (tester) async {
    final (container, ana) = await montar(tester);
    final postobon = await ProveedorRepository(db).crear(nombre: 'Postobón');
    final coca = await producto('Coca', proveedor: postobon);
    final pan = await producto('Pan');
    final inv = InventarioRepository(db);
    await inv.activarControl(coca, cantidad: 2, minimo: 6, por: ana);
    await inv.activarControl(pan, cantidad: 12, minimo: 5, por: ana);
    await pintar(tester, container);

    expect(find.text('Por pedir (1)'), findsOneWidget);
    expect(find.text('Postobón · 1 producto'), findsOneWidget);
    expect(find.text('quedan 2 · mín. 6'), findsOneWidget);

    await tester.tap(find.text('Todos'));
    await tester.pumpAndSettle();
    final deCoca = tester.widget<Text>(find.byKey(Key('existencias_$coca')));
    final dePan = tester.widget<Text>(find.byKey(Key('existencias_$pan')));
    expect(deCoca.data, '2 u');
    expect(deCoca.style?.color, ColoresApp.sale);
    expect(dePan.data, '12 u');
    expect(dePan.style?.color, isNot(ColoresApp.sale));
  });

  testWidgets('sin nada por pedir abre en Todos', (tester) async {
    final (container, ana) = await montar(tester);
    final pan = await producto('Pan');
    await InventarioRepository(db)
        .activarControl(pan, cantidad: 12, minimo: 5, por: ana);
    await pintar(tester, container);

    expect(find.text('Todos'), findsOneWidget);
    expect(find.text('12 u'), findsOneWidget);
    await tester.tap(find.text('Por pedir (0)'));
    await tester.pumpAndSettle();
    expect(find.text('Nada por pedir'), findsOneWidget);
  });

  testWidgets('el detalle muestra historial y ajusta el conteo',
      (tester) async {
    final (container, ana) = await montar(tester);
    final pan = await producto('Pan');
    await InventarioRepository(db, reloj: () => DateTime(2026, 10, 7, 8))
        .activarControl(pan, cantidad: 12, minimo: 5, por: ana);
    await pintar(tester, container);

    await tester.tap(find.byKey(Key('inventario_item_$pan')));
    await tester.pumpAndSettle();
    expect(find.byType(DetalleInventarioScreen), findsOneWidget);
    expect(find.text('Ana · conteo inicial 12'), findsOneWidget);

    await tester.tap(find.byKey(const Key('boton_ajustar_conteo')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('campo_conteo')), '9');
    await tester.tap(find.byKey(const Key('boton_guardar_conteo')));
    await tester.pumpAndSettle();

    expect(find.text('Ana · 12 → 9 (−3)'), findsOneWidget);
    expect(find.text('9 u'), findsOneWidget);
  });

  testWidgets('anular una entrada desde su detalle', (tester) async {
    final (container, ana) = await montar(tester);
    final postobon = await ProveedorRepository(db).crear(nombre: 'Postobón');
    final pan = await producto('Pan', proveedor: postobon);
    final inv = InventarioRepository(db, reloj: () => DateTime(2026, 10, 7, 8));
    await inv.activarControl(pan, cantidad: 2, minimo: 0, por: ana);
    final entrada = await InventarioRepository(db,
            reloj: () => DateTime(2026, 10, 7, 9))
        .recibirMercancia(
      proveedorId: postobon,
      lineas: [LineaRecibida(productoId: pan, cantidad: 24, precioCompra: 400)],
      por: ana,
    );
    await pintar(tester, container);

    await tester.scrollUntilVisible(find.byKey(Key('entrada_$entrada')), 200);
    await tester.tap(find.byKey(Key('entrada_$entrada')));
    await tester.pumpAndSettle();
    expect(find.text(r'24 × Pan · $400'), findsOneWidget);
    await tester.tap(find.byKey(const Key('boton_anular_entrada')));
    await tester.pumpAndSettle();
    expect(find.text('¿Anular esta entrada?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirmar_anular_entrada')));
    await tester.pumpAndSettle();

    expect(find.text('Entrada anulada'), findsWidgets);
    expect(await InventarioRepository(db).existencias(pan), 2);
  });

  testWidgets('el vendedor ve la pestaña Inventario', (tester) async {
    await ConfiguracionRepository(db).guardarNombreTienda('La Esquina');
    final (container, _) = await montar(tester, rol: 'vendedor');
    await pintar(tester, container, inicio: const HomeScreen());

    expect(find.text('Inventario'), findsOneWidget);
    await tester.tap(find.text('Inventario'));
    await tester.pumpAndSettle();
    expect(find.byType(InventarioScreen), findsOneWidget);
  });
}
```

- [ ] **Step 2: Correr y ver que falla**

Run: `flutter test test/screens/inventario/inventario_screen_test.dart`
Expected: FAIL (`inventario_screen.dart` no existe).

- [ ] **Step 3: Implementar la pestaña**

`lib/screens/inventario/inventario_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/inventario_providers.dart';
import '../../ui/avisos.dart';
import '../../ui/boton_principal.dart';
import '../../ui/colores_app.dart';
import '../../ui/estado_vacio.dart';
import '../../ui/selector_segmentado.dart';
import '../../util/fecha_util.dart';
import '../../util/formato_moneda.dart';
import '../../util/texto_util.dart';
import 'detalle_entrada_screen.dart';
import 'detalle_inventario_screen.dart';
import 'recibir_mercancia_screen.dart';

/// "12 u" o "−2 u".
String textoExistencias(int existencias) =>
    '${existencias < 0 ? '−${-existencias}' : existencias} u';

enum _Vista { porPedir, todos }

/// Existencias de los productos con control, lo que hay que pedir y las
/// entradas de mercancía.
class InventarioScreen extends ConsumerStatefulWidget {
  const InventarioScreen({super.key});

  @override
  ConsumerState<InventarioScreen> createState() => _InventarioScreenState();
}

class _InventarioScreenState extends ConsumerState<InventarioScreen> {
  _Vista? _vista;

  Future<void> _recibir() async {
    final total = await Navigator.of(context).push<int>(
      MaterialPageRoute(builder: (_) => const RecibirMercanciaScreen()),
    );
    if (total != null && mounted) {
      avisar(context, 'Mercancía recibida · ${formatoMoneda(total)}');
    }
  }

  void _abrir(Widget pantalla) => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => pantalla));

  @override
  Widget build(BuildContext context) {
    final controlados =
        ref.watch(productosConControlProvider).valueOrNull ?? const [];
    final grupos = ref.watch(porPedirProvider).valueOrNull ?? const [];
    final entradas = ref.watch(entradasRecientesProvider).valueOrNull ?? const [];
    final nPorPedir = grupos.fold<int>(0, (s, g) => s + g.productos.length);
    final vista = _vista ?? (nPorPedir > 0 ? _Vista.porPedir : _Vista.todos);
    const gris = TextStyle(color: ColoresApp.textoSecundario);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        BotonPrincipal(
          key: const Key('boton_recibir_mercancia'),
          texto: 'Recibir mercancía',
          icono: Icons.local_shipping_outlined,
          onPressed: _recibir,
        ),
        const SizedBox(height: 12),
        if (controlados.isEmpty)
          const EstadoVacio(
            icono: Icons.inventory_2_outlined,
            titulo: 'Aún no controlas existencias',
            mensaje: 'Actívalo en Ajustes → Productos',
          )
        else ...[
          SelectorSegmentado<_Vista>(
            key: const Key('selector_inventario'),
            opciones: {
              _Vista.porPedir: 'Por pedir ($nPorPedir)',
              _Vista.todos: 'Todos',
            },
            valor: vista,
            onCambio: (v) => setState(() => _vista = v),
          ),
          const SizedBox(height: 12),
          if (vista == _Vista.todos)
            Card(
              child: Column(
                children: [
                  for (final c in controlados)
                    ListTile(
                      key: Key('inventario_item_${c.producto.id}'),
                      title: Text(c.producto.nombre,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('mín. ${c.producto.minimo}'),
                      trailing: Text(
                        textoExistencias(c.existencias),
                        key: Key('existencias_${c.producto.id}'),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: c.existencias <= c.producto.minimo
                              ? ColoresApp.sale
                              : ColoresApp.texto,
                        ),
                      ),
                      onTap: () => _abrir(
                          DetalleInventarioScreen(productoId: c.producto.id)),
                    ),
                ],
              ),
            )
          else if (grupos.isEmpty)
            const Text('Nada por pedir',
                key: Key('texto_nada_por_pedir'), style: gris)
          else
            for (final g in grupos) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                child: Text(
                  '${g.proveedor?.nombre ?? 'Sin proveedor'} · '
                  '${plural(g.productos.length, 'producto', 'productos')}',
                  key: Key('grupo_por_pedir_${g.proveedor?.id ?? 'sin'}'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Card(
                child: Column(
                  children: [
                    for (final p in g.productos)
                      ListTile(
                        key: Key('por_pedir_${p.producto.id}'),
                        title: Text(p.producto.nombre),
                        subtitle: Text(
                            'quedan ${textoExistencias(p.existencias).replaceAll(' u', '')} · '
                            'mín. ${p.producto.minimo}'),
                        onTap: () => _abrir(
                            DetalleInventarioScreen(productoId: p.producto.id)),
                      ),
                  ],
                ),
              ),
            ],
        ],
        if (entradas.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 24, 4, 8),
            child: Text('Entradas recibidas',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
          Card(
            child: Column(
              children: [
                for (final e in entradas)
                  ListTile(
                    key: Key('entrada_${e.entrada.id}'),
                    title: Text(
                      '${e.proveedor} · ${formatoMoneda(e.entrada.total)}',
                      style: TextStyle(
                        decoration: e.entrada.anulada
                            ? TextDecoration.lineThrough
                            : null,
                        color: e.entrada.anulada
                            ? ColoresApp.textoSecundario
                            : null,
                      ),
                    ),
                    subtitle: Text(
                        '${formatoFechaHora(e.entrada.fecha)} · ${e.usuario}'),
                    onTap: () =>
                        _abrir(DetalleEntradaScreen(entradaId: e.entrada.id)),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
```

`lib/screens/inventario/detalle_inventario_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/inventario_providers.dart';
import '../../repositories/inventario_repository.dart';
import '../../ui/boton_principal.dart';
import '../../ui/colores_app.dart';
import '../../util/fecha_util.dart';
import 'hoja_ajuste_conteo.dart';
import 'inventario_screen.dart';

String _textoMovimiento(MovimientoInventario m) {
  switch (m.tipo) {
    case TipoMovimientoInventario.conteoInicial:
      return '${m.quien} · conteo inicial ${m.cantidad}';
    case TipoMovimientoInventario.ajuste:
      final diferencia = m.cantidad - (m.anterior ?? 0);
      final signo = diferencia > 0
          ? '+$diferencia'
          : diferencia < 0
              ? '−${-diferencia}'
              : '0';
      return '${m.quien} · ${m.anterior} → ${m.cantidad} ($signo)';
    case TipoMovimientoInventario.entrada:
      return '${m.quien} · +${m.cantidad}${m.anulada ? ' (anulada)' : ''}';
  }
}

/// Existencias, mínimo e historial de un producto.
class DetalleInventarioScreen extends ConsumerWidget {
  const DetalleInventarioScreen({super.key, required this.productoId});

  final int productoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = (ref.watch(productosConControlProvider).valueOrNull ?? const [])
        .where((c) => c.producto.id == productoId)
        .firstOrNull;
    final historial =
        ref.watch(historialInventarioProvider(productoId)).valueOrNull ??
            const <MovimientoInventario>[];
    if (item == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(item.producto.nombre)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            textoExistencias(item.existencias),
            key: const Key('existencias_detalle'),
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: item.existencias <= item.producto.minimo
                  ? ColoresApp.sale
                  : ColoresApp.texto,
            ),
          ),
          Text('mín. ${item.producto.minimo}',
              style: const TextStyle(color: ColoresApp.textoSecundario)),
          const SizedBox(height: 16),
          BotonPrincipal(
            key: const Key('boton_ajustar_conteo'),
            texto: 'Ajustar conteo',
            onPressed: () =>
                mostrarHojaAjusteConteo(context, producto: item.producto),
          ),
          const SizedBox(height: 24),
          const Text('Historial',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          for (final m in historial)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(_textoMovimiento(m)),
              subtitle: Text(formatoFechaHora(m.fecha)),
            ),
        ],
      ),
    );
  }
}
```

`lib/screens/inventario/detalle_entrada_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/inventario_providers.dart';
import '../../providers/repository_providers.dart';
import '../../providers/sesion_provider.dart';
import '../../ui/avisos.dart';
import '../../ui/colores_app.dart';
import '../../util/fecha_util.dart';
import '../../util/formato_moneda.dart';

/// Líneas de una entrada de mercancía y "Anular entrada".
class DetalleEntradaScreen extends ConsumerWidget {
  const DetalleEntradaScreen({super.key, required this.entradaId});

  final int entradaId;

  Future<void> _anular(BuildContext context, WidgetRef ref) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('¿Anular esta entrada?'),
        content: const Text(
            'Las existencias se descuentan; los precios actualizados no cambian.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(contexto, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            key: const Key('confirmar_anular_entrada'),
            style: TextButton.styleFrom(foregroundColor: ColoresApp.sale),
            onPressed: () => Navigator.pop(contexto, true),
            child: const Text('Anular'),
          ),
        ],
      ),
    );
    if (confirmado != true) return;
    await ref.read(inventarioRepositoryProvider).anularEntrada(entradaId,
        por: ref.read(sesionProvider).usuarioActivo!);
    if (context.mounted) avisar(context, 'Entrada anulada');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detalle = ref.watch(detalleEntradaProvider(entradaId)).valueOrNull;
    if (detalle == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final entrada = detalle.resumen.entrada;
    return Scaffold(
      appBar: AppBar(title: Text(detalle.resumen.proveedor)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('${formatoFechaHora(entrada.fecha)} · ${detalle.resumen.usuario}',
              style: const TextStyle(color: ColoresApp.textoSecundario)),
          const SizedBox(height: 12),
          for (final l in detalle.lineas)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                  '${l.linea.cantidad} × ${l.producto} · '
                  '${formatoMoneda(l.linea.precioCompra)}'),
            ),
          const SizedBox(height: 8),
          Text('Total ${formatoMoneda(entrada.total)}',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          if (entrada.nota != null) ...[
            const SizedBox(height: 8),
            Text(entrada.nota!),
          ],
          const SizedBox(height: 24),
          if (entrada.anulada)
            const Text('Entrada anulada',
                style: TextStyle(color: ColoresApp.sale))
          else
            TextButton(
              key: const Key('boton_anular_entrada'),
              style: TextButton.styleFrom(foregroundColor: ColoresApp.sale),
              onPressed: () => _anular(context, ref),
              child: const Text('Anular entrada'),
            ),
        ],
      ),
    );
  }
}
```

En `lib/screens/home/home_screen.dart`: import `../inventario/inventario_screen.dart` y, entre la pestaña Fiado y la de Historial:

```dart
      const _Pestana('Inventario', Icons.inventory_2_outlined,
          Icons.inventory_2_rounded, InventarioScreen()),
```

- [ ] **Step 4: Correr y ver que pasa**

Run: `flutter test test/screens` y `flutter analyze lib test`
Expected: PASS y "No issues found!"

- [ ] **Step 5: Commit**

```bash
git add lib/screens/inventario lib/screens/home/home_screen.dart test/screens/inventario/inventario_screen_test.dart
git commit -m "Add the Inventario tab with stock, reorder list, history and receipts"
```

---

### Task 9: Verificación final

**Files:**
- Modify: `docs/superpowers/specs/2026-10-07-vecitienda-existencias-design.md` (`**Estado:**`)
- Modify: `docs/hoja-de-ruta.md`

- [ ] **Step 1: Análisis y suite completa**

Run: `flutter analyze` y `flutter test`
Expected: "No issues found!" y todas las pruebas pasan. (Si alguna prueba vieja de `HomeScreen` cuenta pestañas o toca por posición, ajustarla con su Ruling.)

- [ ] **Step 2: Compilar**

Run: `flutter build apk --debug`
Expected: "Built build\app\outputs\flutter-apk\app-debug.apk".

- [ ] **Step 3: Documentación**

- Especificación: `**Estado:** Diseño aprobado, pendiente de plan` → `**Estado:** Implementado (falta el recorrido manual en un celular real)`.
- `docs/hoja-de-ruta.md`: en "Hecho" agregar "- Fase 4B — existencias, recibir mercancía, ajustes por conteo y \"Por pedir\"."; en "En curso" dejar "- Siguiente: Fase 4C (pedidos por proveedor)."; en "Pendiente de verificar" agregar " e inventario (4B)" al final.

- [ ] **Step 4: Commit**

```bash
git add docs/superpowers/specs/2026-10-07-vecitienda-existencias-design.md docs/hoja-de-ruta.md
git commit -m "Mark Fase 4B as implemented"
```
