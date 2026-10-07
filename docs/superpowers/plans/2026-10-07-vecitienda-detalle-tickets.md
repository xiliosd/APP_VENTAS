# Fase 3C — Detalle de tickets, productos más vendidos y horas Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Cada venta guarda sus líneas (producto o monto suelto, precio y cantidad); la corrección edita cantidades; Reportes muestra el top 10 de productos y las horas de más venta.

**Architecture:** Esquema v4 con la tabla `lineas_venta`; la venta conserva su `monto` (= suma de líneas). `VentaRepository.registrarVenta` guarda venta y líneas en una transacción; `CorreccionRepository.corregirVenta` recibe cambios de cantidad por línea y recalcula el monto. `ReporteRepository` agrega ranking (join líneas–ventas no anuladas) y ventas por hora. Las barras se generalizan (`Barras`) para días y horas.

**Tech Stack:** Flutter 3.47 / Dart ^3.13, flutter_riverpod 2.6, Drift 2.34 (+ build_runner), sqlite3 3.5. Sin dependencias nuevas.

**Spec:** `docs/superpowers/specs/2026-10-07-vecitienda-detalle-tickets-design.md`

## Global Constraints

- `schemaVersion = 4`; migración `desde < 4`: solo `createTable(lineasVenta)`. `CopiaBaseDatos.tablas` no cambia.
- Después de cada cambio en `lib/data/database.dart`: `dart run build_runner build --delete-conflicting-outputs`.
- Invariante: venta con líneas ⇒ `monto == Σ precioUnitario × cantidad`.
- Venta y líneas se guardan, corrigen y borran (Deshacer) en una sola transacción.
- Corregir con líneas: solo cambiar cantidades o quitar líneas (0 = quitar); debe quedar ≥ 1 línea; el `monto` recibido se ignora. Sin líneas: igual que hoy.
- `antes` con productos: `$8.200 · Contado · Efectivo · 2× Arepa, 1× Cocacola` (montos sueltos `1× $5.000`).
- Ranking: por `productoId`, nombre actual del producto (si no existe, la `descripcion` de la línea); orden unidades desc, dinero desc, nombre asc; máximo 10; líneas sin producto suman a "Otros montos". Nada anulado cuenta.
- Horas: ventas no anuladas del periodo por hora local de `fecha`; hora pico = más dinero, empate la más temprana.
- Etiquetas de hora: 0 → "12 a. m.", 1–11 → "N a. m.", 12 → "12 m.", 13–23 → "N p. m.".
- Textos exactos: "Productos más vendidos", "Horas de más venta", "1. Arepa · 42 u · $147.000", "Otros montos · $85.000", "Aún no hay ventas con detalle de productos en este periodo", "Hora pico: 6 p. m. · $85.000", "Para quitar todo, anula la venta", líneas en el detalle "2× Arepa · $7.000".
- Trabajar en una rama nueva `fase3c-detalle-tickets` desde `master`.

## Review Focus

1. Ticket con el mismo monto rápido tocado dos veces ($5.000 ×2) → una línea "2× $5.000", no dos (prueba en Task 2).
2. Producto renombrado después de vender → el ranking lo muestra con su nombre actual y suma todo su historial (prueba en Task 5).
3. Corregir una venta y quitar todas sus líneas → Guardar deshabilitado y el repositorio lo rechaza sin cambiar nada (pruebas en Tasks 3 y 4).
4. Deshacer justo después de cobrar un ticket con productos → no quedan líneas huérfanas (prueba en Task 2).
5. Periodo con ventas viejas sin detalle → el ranking muestra el mensaje de "sin detalle" pero las horas sí aparecen (prueba en Task 6).

---

### Task 1: Esquema v4 — tabla `lineas_venta`

**Files:**
- Modify: `lib/data/database.dart`
- Regenerate: `lib/data/database.g.dart`
- Create: `test/support/esquema_v3.dart`
- Modify: `test/data/migracion_test.dart`
- Modify: `test/respaldo/copia_base_datos_test.dart` (línea con `versionMaxima: 3`)

**Interfaces:**
- Produces: tabla `db.lineasVenta` con data class `LineaVenta { int id; int ventaId; int? productoId; String descripcion; int precioUnitario; int cantidad; }` y `LineasVentaCompanion.insert({required int ventaId, Value<int?> productoId, required String descripcion, required int precioUnitario, required int cantidad})`.

- [ ] **Step 1: Crear la rama**

```bash
git checkout master
git checkout -b fase3c-detalle-tickets
```

- [ ] **Step 2: Fixture v3**

`test/support/esquema_v3.dart`:

```dart
import 'package:sqlite3/sqlite3.dart';

import 'esquema_v2.dart';

/// Crea en [ruta] una base con el esquema v3 de la app (3A/3B, antes de la
/// 3C): el de v2 más `anulado` y la tabla `correcciones`.
void crearBaseV3(String ruta) {
  crearBaseV2(ruta);
  sqlite3.open(ruta)
    ..execute('''
      ALTER TABLE ventas ADD COLUMN anulado INTEGER NOT NULL DEFAULT 0
        CHECK (anulado IN (0, 1));
      ALTER TABLE pagos_fiado ADD COLUMN anulado INTEGER NOT NULL DEFAULT 0
        CHECK (anulado IN (0, 1));
      ALTER TABLE gastos ADD COLUMN anulado INTEGER NOT NULL DEFAULT 0
        CHECK (anulado IN (0, 1));
      CREATE TABLE correcciones (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        tipo_movimiento TEXT NOT NULL, movimiento_id INTEGER NOT NULL,
        accion TEXT NOT NULL,
        usuario_id INTEGER NOT NULL REFERENCES usuarios (id),
        fecha INTEGER NOT NULL, antes TEXT NOT NULL);
    ''')
    ..userVersion = 3
    ..close();
}
```

- [ ] **Step 3: Escribir las pruebas que fallan**

En `test/data/migracion_test.dart`: agregar `import '../support/esquema_v3.dart';`, cambiar `expect(db.schemaVersion, 3);` por `expect(db.schemaVersion, 4);` y agregar dentro de `main()`:

```dart
  test('una base v3 abre en v4 con lineas_venta vacía', () async {
    final archivo = File('${carpeta.path}/v3.sqlite');
    crearBaseV3(archivo.path);

    final db = AppDatabase(NativeDatabase(archivo));
    addTearDown(db.close);

    expect(await db.select(db.ventas).get(), hasLength(1));
    expect(await db.select(db.lineasVenta).get(), isEmpty);
  });

  test('una base nueva guarda líneas de venta', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final usuario = await db.into(db.usuarios).insert(
        UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'x'));
    final venta = await db.into(db.ventas).insert(VentasCompanion.insert(
        monto: 5000, fecha: DateTime(2026, 10, 7), usuarioId: usuario));

    await db.into(db.lineasVenta).insert(LineasVentaCompanion.insert(
          ventaId: venta,
          descripcion: r'$5.000',
          precioUnitario: 5000,
          cantidad: 1,
        ));

    final linea = await db.select(db.lineasVenta).getSingle();
    expect(linea.ventaId, venta);
    expect(linea.productoId, isNull);
    expect(linea.descripcion, r'$5.000');
  });
```

En `test/respaldo/copia_base_datos_test.dart` cambiar `versionMaxima: 3` por `versionMaxima: 4`.

- [ ] **Step 4: Correr y ver que falla**

Run: `flutter test test/data/migracion_test.dart`
Expected: FAIL de compilación (`lineasVenta` no existe).

- [ ] **Step 5: Implementar**

En `lib/data/database.dart`, después de la clase `Ventas`:

```dart
/// Un producto (o monto suelto) de una venta, tal como estaba al vender.
@DataClassName('LineaVenta')
class LineasVenta extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get ventaId => integer().references(Ventas, #id)();

  /// null = monto suelto ("+ Otro" o monto rápido).
  IntColumn get productoId =>
      integer().nullable().references(Productos, #id)();
  TextColumn get descripcion => text()();
  IntColumn get precioUnitario => integer()();
  IntColumn get cantidad => integer()();
}
```

- Agregar `LineasVenta,` a la lista `tables:` de `@DriftDatabase` (después de `Ventas,`).
- `int get schemaVersion => 4;`
- En `onUpgrade`, después del bloque `if (desde < 3) {...}`:

```dart
          if (desde < 4) {
            await m.createTable(lineasVenta);
          }
```

Run: `dart run build_runner build --delete-conflicting-outputs`

- [ ] **Step 6: Correr y ver que pasa**

Run: `flutter test test/data test/respaldo`
Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add lib/data test/support/esquema_v3.dart test/data/migracion_test.dart test/respaldo/copia_base_datos_test.dart
git commit -m "Add the sale lines table (schema v4)"
```

---

### Task 2: Guardar las líneas al cobrar

**Files:**
- Modify: `lib/repositories/venta_repository.dart`
- Modify: `lib/screens/venta/registrar_venta_screen.dart` (`_cobrar`)
- Test: `test/repositories/lineas_venta_test.dart`
- Modify: `test/screens/venta/registrar_venta_screen_test.dart`

**Interfaces:**
- Consumes: `db.lineasVenta` (Task 1); `LineaTicket { clave, etiqueta, precio, cantidad, productoId }` de `ticket_provider.dart`.
- Produces: `class LineaNueva { const LineaNueva({int? productoId, required String descripcion, required int precioUnitario, required int cantidad}); int get subtotal; }`; `registrarVenta(..., List<LineaNueva> lineas = const [])` (lanza `ArgumentError` si el monto no es la suma); `Future<List<LineaVenta>> lineasDeVenta(int ventaId)` (orden por id); `eliminarVenta` borra también las líneas.

- [ ] **Step 1: Escribir las pruebas que fallan**

`test/repositories/lineas_venta_test.dart`:

```dart
import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/repositories/venta_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late VentaRepository repo;
  late int ana;
  late int arepa;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = VentaRepository(db);
    ana = await db.into(db.usuarios).insert(
        UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'x'));
    arepa = await db
        .into(db.productos)
        .insert(ProductosCompanion.insert(nombre: 'Arepa', precio: 3500));
  });

  tearDown(() => db.close());

  List<LineaNueva> ticket() => [
        LineaNueva(
            productoId: arepa,
            descripcion: 'Arepa',
            precioUnitario: 3500,
            cantidad: 2),
        const LineaNueva(
            descripcion: r'$5.000', precioUnitario: 5000, cantidad: 1),
      ];

  test('registrarVenta guarda las líneas con la venta', () async {
    final id = await repo.registrarVenta(
        monto: 12000, esFiado: false, usuarioId: ana, lineas: ticket());

    final lineas = await repo.lineasDeVenta(id);
    expect(lineas, hasLength(2));
    expect(lineas[0].productoId, arepa);
    expect(lineas[0].cantidad, 2);
    expect(lineas[0].precioUnitario, 3500);
    expect(lineas[1].productoId, isNull);
    expect(lineas[1].descripcion, r'$5.000');
  });

  test('un monto que no es la suma de las líneas se rechaza', () async {
    await expectLater(
        repo.registrarVenta(
            monto: 9999, esFiado: false, usuarioId: ana, lineas: ticket()),
        throwsArgumentError);

    expect(await db.select(db.ventas).get(), isEmpty);
    expect(await db.select(db.lineasVenta).get(), isEmpty);
  });

  test('eliminarVenta borra también sus líneas', () async {
    final id = await repo.registrarVenta(
        monto: 12000, esFiado: false, usuarioId: ana, lineas: ticket());

    await repo.eliminarVenta(id);

    expect(await db.select(db.ventas).get(), isEmpty);
    expect(await db.select(db.lineasVenta).get(), isEmpty);
  });

  test('sin líneas funciona como antes', () async {
    final id =
        await repo.registrarVenta(monto: 3000, esFiado: false, usuarioId: ana);

    expect(await repo.lineasDeVenta(id), isEmpty);
  });
}
```

En `test/screens/venta/registrar_venta_screen_test.dart`, dentro de `main()`:

```dart
  testWidgets('cobrar un ticket guarda una línea por producto o monto',
      (tester) async {
    final arepa = await db.into(db.productos).insert(
          ProductosCompanion.insert(nombre: 'Arepa', precio: 3500),
        );
    await abrirVenta(tester);

    await tester.tap(find.byKey(Key('producto_$arepa')));
    await tester.tap(find.byKey(const Key('monto_rapido_5000')));
    await tester.tap(find.byKey(const Key('monto_rapido_5000')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('boton_cobrar')));
    await tester.pumpAndSettle();

    final venta = (await db.select(db.ventas).get()).single;
    expect(venta.monto, 13500);
    final lineas = await db.select(db.lineasVenta).get();
    expect(lineas, hasLength(2));
    final deArepa = lineas.singleWhere((l) => l.productoId == arepa);
    expect(deArepa.cantidad, 1);
    expect(deArepa.descripcion, 'Arepa');
    final suelto = lineas.singleWhere((l) => l.productoId == null);
    expect(suelto.cantidad, 2);
    expect(suelto.precioUnitario, 5000);
    expect(suelto.descripcion, r'$5.000');
  });

  testWidgets('Deshacer no deja líneas huérfanas', (tester) async {
    final arepa = await db.into(db.productos).insert(
          ProductosCompanion.insert(nombre: 'Arepa', precio: 3500),
        );
    await abrirVenta(tester);

    await tester.tap(find.byKey(Key('producto_$arepa')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('boton_cobrar')));
    await tester.pumpAndSettle();
    expect(await db.select(db.lineasVenta).get(), hasLength(1));

    await tester.tap(find.text('Deshacer'));
    await tester.pumpAndSettle();

    expect(await db.select(db.ventas).get(), isEmpty);
    expect(await db.select(db.lineasVenta).get(), isEmpty);
  });
```

- [ ] **Step 2: Correr y ver que falla**

Run: `flutter test test/repositories/lineas_venta_test.dart test/screens/venta`
Expected: FAIL (`LineaNueva` y `lineasDeVenta` no existen).

- [ ] **Step 3: Implementar el repositorio**

En `lib/repositories/venta_repository.dart`, antes de `class VentaRepository`:

```dart
/// Una línea de un ticket por guardar con su venta.
class LineaNueva {
  const LineaNueva({
    this.productoId,
    required this.descripcion,
    required this.precioUnitario,
    required this.cantidad,
  });

  /// null = monto suelto.
  final int? productoId;
  final String descripcion;
  final int precioUnitario;
  final int cantidad;

  int get subtotal => precioUnitario * cantidad;
}
```

Reemplazar `registrarVenta` y `eliminarVenta`, y agregar `lineasDeVenta`:

```dart
  /// Guarda la venta y sus [lineas] en una transacción. Con líneas, [monto]
  /// debe ser su suma.
  Future<int> registrarVenta({
    required int monto,
    int? productoId,
    required bool esFiado,
    int? clienteId,
    required int usuarioId,
    DateTime? fecha,
    MedioPago medioPago = MedioPago.efectivo,
    List<LineaNueva> lineas = const [],
  }) async {
    if (lineas.isNotEmpty) {
      final suma = lineas.fold<int>(0, (s, l) => s + l.subtotal);
      if (suma != monto) {
        throw ArgumentError(
            'El monto ($monto) no es la suma de las líneas ($suma)');
      }
    }
    return _db.transaction(() async {
      final id = await _db.into(_db.ventas).insert(
            VentasCompanion.insert(
              monto: monto,
              productoId: Value(productoId),
              fecha: fecha ?? DateTime.now(),
              esFiado: Value(esFiado),
              clienteId: Value(clienteId),
              usuarioId: usuarioId,
              medioPago: Value(medioPago),
            ),
          );
      for (final linea in lineas) {
        await _db.into(_db.lineasVenta).insert(LineasVentaCompanion.insert(
              ventaId: id,
              productoId: Value(linea.productoId),
              descripcion: linea.descripcion,
              precioUnitario: linea.precioUnitario,
              cantidad: linea.cantidad,
            ));
      }
      return id;
    });
  }

  /// Líneas de la venta [ventaId], en el orden en que se registraron.
  Future<List<LineaVenta>> lineasDeVenta(int ventaId) {
    return (_db.select(_db.lineasVenta)
          ..where((l) => l.ventaId.equals(ventaId))
          ..orderBy([(l) => OrderingTerm.asc(l.id)]))
        .get();
  }
```

```dart
  /// Solo para "Deshacer" justo después de cobrar; no es una función de
  /// anular ventas pasadas. Borra también las líneas.
  Future<void> eliminarVenta(int id) {
    return _db.transaction(() async {
      await (_db.delete(_db.lineasVenta)..where((l) => l.ventaId.equals(id)))
          .go();
      await (_db.delete(_db.ventas)..where((v) => v.id.equals(id))).go();
    });
  }
```

- [ ] **Step 4: Pasar las líneas al cobrar**

En `lib/screens/venta/registrar_venta_screen.dart`, en `_cobrar`, la llamada a `ventaRepo.registrarVenta(...)` agrega el argumento:

```dart
        lineas: [
          for (final linea in ticket.lineas)
            LineaNueva(
              productoId: linea.productoId,
              descripcion: linea.etiqueta,
              precioUnitario: linea.precio,
              cantidad: linea.cantidad,
            ),
        ],
```

y el import `import '../../repositories/venta_repository.dart';` (si no está).

- [ ] **Step 5: Correr y ver que pasa**

Run: `flutter test test/repositories test/screens/venta`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add lib/repositories/venta_repository.dart lib/screens/venta/registrar_venta_screen.dart test/repositories/lineas_venta_test.dart test/screens/venta/registrar_venta_screen_test.dart
git commit -m "Save each ticket line with its sale and remove them on undo"
```

---

### Task 3: Corregir cantidades en el repositorio

**Files:**
- Modify: `lib/repositories/correccion_repository.dart` (`anularVenta`, `corregirVenta`, `_antesVenta`)
- Test: `test/repositories/correccion_lineas_test.dart`

**Interfaces:**
- Consumes: `db.lineasVenta` (Task 1); `VentaRepository.registrarVenta(lineas:)`, `LineaNueva`, `lineasDeVenta` (Task 2).
- Produces: `corregirVenta(int id, {required int monto, required bool esFiado, int? clienteId, MedioPago medioPago = MedioPago.efectivo, Map<int, int>? cantidades, required Usuario por})` — `cantidades`: id de línea → nueva cantidad (0 = quitar; ausente = sin cambio). Con líneas: monto recalculado, ≥ 1 línea o `CorreccionInvalida('Para quitar todo, anula la venta')`. `antes` con productos.

- [ ] **Step 1: Escribir las pruebas que fallan**

`test/repositories/correccion_lineas_test.dart`:

```dart
import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/repositories/correccion_repository.dart';
import 'package:app_ventas/repositories/venta_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late CorreccionRepository repo;
  late VentaRepository ventas;
  late Usuario ana;
  late int ventaId;
  late LineaVenta deArepa;
  late LineaVenta deCoca;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = CorreccionRepository(db);
    ventas = VentaRepository(db);
    final id = await db.into(db.usuarios).insert(
        UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'x'));
    ana = await (db.select(db.usuarios)..where((u) => u.id.equals(id)))
        .getSingle();
    final arepa = await db
        .into(db.productos)
        .insert(ProductosCompanion.insert(nombre: 'Arepa', precio: 3500));
    final coca = await db
        .into(db.productos)
        .insert(ProductosCompanion.insert(nombre: 'Cocacola', precio: 1200));
    ventaId = await ventas.registrarVenta(
      monto: 8200,
      esFiado: false,
      usuarioId: ana.id,
      lineas: [
        LineaNueva(
            productoId: arepa,
            descripcion: 'Arepa',
            precioUnitario: 3500,
            cantidad: 2),
        LineaNueva(
            productoId: coca,
            descripcion: 'Cocacola',
            precioUnitario: 1200,
            cantidad: 1),
      ],
    );
    final lineas = await ventas.lineasDeVenta(ventaId);
    deArepa = lineas[0];
    deCoca = lineas[1];
  });

  tearDown(() => db.close());

  Future<Venta> venta() =>
      (db.select(db.ventas)..where((v) => v.id.equals(ventaId))).getSingle();

  test('cambiar cantidades recalcula el monto y guarda los productos antes',
      () async {
    await repo.corregirVenta(ventaId,
        monto: 1, // se ignora: la venta tiene líneas
        esFiado: false,
        cantidades: {deArepa.id: 3, deCoca.id: 0},
        por: ana);

    expect((await venta()).monto, 10500);
    final lineas = await ventas.lineasDeVenta(ventaId);
    expect(lineas.single.id, deArepa.id);
    expect(lineas.single.cantidad, 3);
    expect((await db.select(db.correcciones).getSingle()).antes,
        r'$8.200 · Contado · Efectivo · 2× Arepa, 1× Cocacola');
  });

  test('quitar todas las líneas se rechaza y nada cambia', () async {
    await expectLater(
        repo.corregirVenta(ventaId,
            monto: 8200,
            esFiado: false,
            cantidades: {deArepa.id: 0, deCoca.id: 0},
            por: ana),
        throwsA(isA<CorreccionInvalida>()
            .having((e) => e.mensaje, 'mensaje',
                'Para quitar todo, anula la venta')));

    expect((await venta()).monto, 8200);
    expect(await ventas.lineasDeVenta(ventaId), hasLength(2));
    expect(await db.select(db.correcciones).get(), isEmpty);
  });

  test('sin cambios de cantidad conserva las líneas y su total', () async {
    await repo.corregirVenta(ventaId,
        monto: 8200,
        esFiado: false,
        medioPago: MedioPago.transferencia,
        por: ana);

    final v = await venta();
    expect(v.monto, 8200);
    expect(v.medioPago, MedioPago.transferencia);
    expect(await ventas.lineasDeVenta(ventaId), hasLength(2));
  });

  test('anular guarda los productos en antes y conserva las líneas',
      () async {
    await repo.anularVenta(ventaId, por: ana);

    expect((await db.select(db.correcciones).getSingle()).antes,
        r'$8.200 · Contado · Efectivo · 2× Arepa, 1× Cocacola');
    expect(await ventas.lineasDeVenta(ventaId), hasLength(2));
  });

  test('una venta sin detalle se sigue corrigiendo por monto', () async {
    final vieja =
        await ventas.registrarVenta(monto: 4000, esFiado: false, usuarioId: ana.id);

    await repo.corregirVenta(vieja, monto: 4500, esFiado: false, por: ana);

    final v = await (db.select(db.ventas)..where((x) => x.id.equals(vieja)))
        .getSingle();
    expect(v.monto, 4500);
  });
}
```

- [ ] **Step 2: Correr y ver que falla**

Run: `flutter test test/repositories/correccion_lineas_test.dart`
Expected: FAIL (parámetro `cantidades` no existe).

- [ ] **Step 3: Implementar**

En `lib/repositories/correccion_repository.dart`:

- En `anularVenta`, cambiar `final antes = await _antesVenta(venta);` por:

```dart
      final antes = await _antesVenta(venta, await _lineas(id));
```

- Reemplazar `corregirVenta` completo:

```dart
  /// Una venta fiada guarda `efectivo` (no cuenta por medio de pago); una de
  /// contado queda sin cliente. Si la venta tiene líneas, [cantidades] (id de
  /// línea → nueva cantidad; 0 = quitar) las ajusta y el monto se recalcula
  /// con ellas ([monto] se ignora); debe quedar al menos una.
  Future<void> corregirVenta(
    int id, {
    required int monto,
    required bool esFiado,
    int? clienteId,
    MedioPago medioPago = MedioPago.efectivo,
    Map<int, int>? cantidades,
    required Usuario por,
  }) async {
    if (esFiado && clienteId == null) {
      throw const CorreccionInvalida('Una venta fiada necesita cliente');
    }
    await _db.transaction(() async {
      final venta = await _venta(id);
      _comprobar(por, venta.usuarioId, venta.fecha, venta.anulado);
      final lineas = await _lineas(id);
      final antes = await _antesVenta(venta, lineas);
      var montoFinal = monto;
      if (lineas.isEmpty) {
        _validarMonto(monto);
      } else {
        var suma = 0;
        var quedan = 0;
        for (final linea in lineas) {
          final cantidad = cantidades?[linea.id] ?? linea.cantidad;
          if (cantidad < 0) {
            throw const CorreccionInvalida('Cantidad inválida');
          }
          if (cantidad == 0) {
            await (_db.delete(_db.lineasVenta)
                  ..where((l) => l.id.equals(linea.id)))
                .go();
            continue;
          }
          if (cantidad != linea.cantidad) {
            await (_db.update(_db.lineasVenta)
                  ..where((l) => l.id.equals(linea.id)))
                .write(LineasVentaCompanion(cantidad: Value(cantidad)));
          }
          suma += linea.precioUnitario * cantidad;
          quedan++;
        }
        if (quedan == 0) {
          throw const CorreccionInvalida('Para quitar todo, anula la venta');
        }
        montoFinal = suma;
      }
      await (_db.update(_db.ventas)..where((v) => v.id.equals(id))).write(
        VentasCompanion(
          monto: Value(montoFinal),
          esFiado: Value(esFiado),
          clienteId: Value(esFiado ? clienteId : null),
          medioPago: Value(esFiado ? MedioPago.efectivo : medioPago),
        ),
      );
      await _registrar(
          TipoMovimiento.venta, id, AccionCorreccion.corregido, por, antes);
    });
  }
```

- Reemplazar `_antesVenta` y agregar `_lineas`:

```dart
  Future<List<LineaVenta>> _lineas(int ventaId) =>
      (_db.select(_db.lineasVenta)
            ..where((l) => l.ventaId.equals(ventaId))
            ..orderBy([(l) => OrderingTerm.asc(l.id)]))
          .get();

  Future<String> _antesVenta(Venta venta, List<LineaVenta> lineas) async {
    final monto = formatoMoneda(venta.monto);
    final String base;
    if (!venta.esFiado) {
      base = '$monto · Contado · ${_nombreMedio(venta.medioPago)}';
    } else {
      final clienteId = venta.clienteId;
      final cliente = clienteId == null
          ? null
          : await (_db.select(_db.clientes)
                ..where((c) => c.id.equals(clienteId)))
              .getSingleOrNull();
      base = '$monto · Fiado · ${cliente?.nombre ?? 'Sin cliente'}';
    }
    if (lineas.isEmpty) return base;
    final productos =
        lineas.map((l) => '${l.cantidad}× ${l.descripcion}').join(', ');
    return '$base · $productos';
  }
```

- [ ] **Step 4: Correr y ver que pasa**

Run: `flutter test test/repositories`
Expected: PASS (incluidas las pruebas de la 3A en `correccion_repository_test.dart`: monto 0 sin líneas sigue rechazándose).

- [ ] **Step 5: Commit**

```bash
git add lib/repositories/correccion_repository.dart test/repositories/correccion_lineas_test.dart
git commit -m "Correct sale line quantities and recompute the total in the same transaction"
```

---

### Task 4: Detalle y editor de cantidades en la hoja de movimiento

**Files:**
- Create: `lib/providers/lineas_venta_providers.dart`
- Modify: `lib/screens/correccion/hoja_movimiento.dart`
- Modify: `test/screens/correccion/hoja_movimiento_test.dart`

**Interfaces:**
- Consumes: `VentaRepository.lineasDeVenta`, `LineaNueva` (Task 2); `corregirVenta(cantidades:)` (Task 3); `ventaRepositoryProvider`.
- Produces: `lineasVentaProvider` (`FutureProvider.autoDispose.family<List<LineaVenta>, int>`); llaves `linea_<id>` (detalle), `restar_linea_<id>`, `sumar_linea_<id>`, `quitar_linea_<id>`, `cantidad_linea_<id>`, `total_correccion`, `texto_sin_lineas`.

- [ ] **Step 1: Escribir las pruebas que fallan**

En `test/screens/correccion/hoja_movimiento_test.dart` agregar dentro de `main()`:

```dart
  /// Venta de Ana con 2 Arepa ($3.500) y 1 Cocacola ($1.200) = $8.200.
  Future<(int, List<LineaVenta>)> ventaConLineas(Usuario ana) async {
    final arepa = await db
        .into(db.productos)
        .insert(ProductosCompanion.insert(nombre: 'Arepa', precio: 3500));
    final coca = await db
        .into(db.productos)
        .insert(ProductosCompanion.insert(nombre: 'Cocacola', precio: 1200));
    final repo = VentaRepository(db);
    final id = await repo.registrarVenta(
      monto: 8200,
      esFiado: false,
      usuarioId: ana.id,
      lineas: [
        LineaNueva(
            productoId: arepa,
            descripcion: 'Arepa',
            precioUnitario: 3500,
            cantidad: 2),
        LineaNueva(
            productoId: coca,
            descripcion: 'Cocacola',
            precioUnitario: 1200,
            cantidad: 1),
      ],
    );
    return (id, await repo.lineasDeVenta(id));
  }

  MovimientoEditable ventaDe8200(int id, Usuario ana) => MovimientoEditable(
        tipo: TipoMovimiento.venta,
        id: id,
        monto: 8200,
        fecha: DateTime.now(),
        usuarioId: ana.id,
      );

  testWidgets('el detalle muestra los productos de la venta', (tester) async {
    final (container, ana) = await sesion();
    final (id, _) = await ventaConLineas(ana);

    await abrir(tester, container, ventaDe8200(id, ana));

    expect(find.text(r'2× Arepa · $7.000'), findsOneWidget);
    expect(find.text(r'1× Cocacola · $1.200'), findsOneWidget);
  });

  testWidgets('corregir cantidades recalcula el total y lo guarda',
      (tester) async {
    final (container, ana) = await sesion();
    final (id, lineas) = await ventaConLineas(ana);
    await abrir(tester, container, ventaDe8200(id, ana));

    await tester.tap(find.byKey(const Key('boton_corregir')));
    await tester.pumpAndSettle();
    expect(find.byType(TecladoMonto), findsNothing);
    await tester.tap(find.byKey(Key('sumar_linea_${lineas[0].id}')));
    await tester.tap(find.byKey(Key('quitar_linea_${lineas[1].id}')));
    await tester.pump();

    expect(
        find.descendant(
            of: find.byKey(const Key('total_correccion')),
            matching: find.text(r'$10.500')),
        findsOneWidget);
    await tester.ensureVisible(
        find.byKey(const Key('boton_guardar_correccion')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('boton_guardar_correccion')));
    await tester.pumpAndSettle();

    expect((await venta(id)).monto, 10500);
    final quedan = await VentaRepository(db).lineasDeVenta(id);
    expect(quedan.single.cantidad, 3);
    expect(find.text('Venta corregida'), findsOneWidget);
  });

  testWidgets('quitar todas las líneas no deja guardar', (tester) async {
    final (container, ana) = await sesion();
    final (id, lineas) = await ventaConLineas(ana);
    await abrir(tester, container, ventaDe8200(id, ana));

    await tester.tap(find.byKey(const Key('boton_corregir')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('quitar_linea_${lineas[0].id}')));
    await tester.tap(find.byKey(Key('quitar_linea_${lineas[1].id}')));
    await tester.pump();

    expect(find.text('Para quitar todo, anula la venta'), findsOneWidget);
    expect(guardarHabilitado(tester), isFalse);
  });

  testWidgets('restar hasta 0 quita la línea', (tester) async {
    final (container, ana) = await sesion();
    final (id, lineas) = await ventaConLineas(ana);
    await abrir(tester, container, ventaDe8200(id, ana));

    await tester.tap(find.byKey(const Key('boton_corregir')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('restar_linea_${lineas[1].id}')));
    await tester.pump();

    expect(find.byKey(Key('cantidad_linea_${lineas[1].id}')), findsNothing);
    expect(
        find.descendant(
            of: find.byKey(const Key('total_correccion')),
            matching: find.text(r'$7.000')),
        findsOneWidget);
  });
```

Agregar los imports `import 'package:app_ventas/ui/teclado_monto.dart';` (`VentaRepository` ya está importado; `LineaNueva` viene del mismo archivo).

- [ ] **Step 2: Correr y ver que falla**

Run: `flutter test test/screens/correccion/hoja_movimiento_test.dart`
Expected: FAIL (no se muestran líneas; no existen las llaves de líneas).

- [ ] **Step 3: Provider de líneas**

`lib/providers/lineas_venta_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import 'repository_providers.dart';

/// Líneas de una venta (vacío si es una venta vieja sin detalle).
final lineasVentaProvider = FutureProvider.autoDispose
    .family<List<LineaVenta>, int>((ref, ventaId) {
  return ref.watch(ventaRepositoryProvider).lineasDeVenta(ventaId);
});
```

- [ ] **Step 4: Implementar en la hoja**

En `lib/screens/correccion/hoja_movimiento.dart`:

- import `import '../../providers/lineas_venta_providers.dart';`
- en el estado, después de `String? _error;`:

```dart
  /// Cantidades editadas por id de línea (las demás quedan como estaban).
  final Map<int, int> _cantidades = {};
```

- después de `MovimientoEditable get _m => widget.movimiento;`:

```dart
  /// Líneas de la venta (vacío para abonos, gastos o ventas sin detalle).
  List<LineaVenta> get _lineas => _m.tipo == TipoMovimiento.venta
      ? ref.read(lineasVentaProvider(_m.id)).valueOrNull ?? const []
      : const [];

  int _cantidad(LineaVenta linea) => _cantidades[linea.id] ?? linea.cantidad;

  /// Total a guardar: la suma de las líneas o, sin líneas, el monto tecleado.
  int get _total {
    final lineas = _lineas;
    if (lineas.isEmpty) return _monto;
    return lineas.fold(0, (s, l) => s + l.precioUnitario * _cantidad(l));
  }

  bool get _quedanLineas => _lineas.any((l) => _cantidad(l) > 0);
```

- en `_hayCambios`, reemplazar la primera línea `if (_monto != _m.monto) return true;` por:

```dart
    if (_total != _m.monto) return true;
    if (_lineas.any((l) => _cantidad(l) != l.cantidad)) return true;
```

- reemplazar `_valido`:

```dart
  bool get _valido =>
      _total > 0 &&
      (_lineas.isEmpty || _quedanLineas) &&
      (_m.tipo != TipoMovimiento.venta || !_esFiado || _clienteElegido != null);
```

- en `_guardar`, la llamada `repo.corregirVenta(...)` pasa a:

```dart
          await repo.corregirVenta(_m.id,
              monto: _total,
              esFiado: _esFiado,
              clienteId: clienteId,
              medioPago: _medio,
              cantidades: _lineas.isEmpty
                  ? null
                  : {for (final l in _lineas) l.id: _cantidad(l)},
              por: por);
```

- al inicio de `build`, antes del `return`, suscribirse a las líneas:

```dart
    if (_m.tipo == TipoMovimiento.venta) {
      ref.watch(lineasVentaProvider(_m.id));
    }
```

  (`build` hoy es `=> _editando ? _formulario() : _vistaDetalle();`; pasarlo a cuerpo con llaves.)

- en `_vistaDetalle`, justo después de `Text(_detalle, key: const Key('detalle_movimiento')),`:

```dart
        for (final linea in _lineas)
          Text(
            '${linea.cantidad}× ${linea.descripcion} · '
            '${formatoMoneda(linea.precioUnitario * linea.cantidad)}',
            key: Key('linea_${linea.id}'),
          ),
```

- en `_formulario`, reemplazar el bloque

```dart
        Center(child: Monto(_monto, tamano: 36)),
        ?error,
        const SizedBox(height: 12),
        TecladoMonto(
          onTecla: (tecla) => setState(() {
            _monto = aplicarTecla(_monto, tecla);
            _error = null;
          }),
        ),
```

  por:

```dart
        if (_lineas.isEmpty) ...[
          Center(child: Monto(_monto, tamano: 36)),
          ?error,
          const SizedBox(height: 12),
          TecladoMonto(
            onTecla: (tecla) => setState(() {
              _monto = aplicarTecla(_monto, tecla);
              _error = null;
            }),
          ),
        ] else ...[
          for (final linea in _lineas)
            if (_cantidad(linea) > 0) _filaLinea(linea),
          const SizedBox(height: 8),
          Center(
            child: KeyedSubtree(
              key: const Key('total_correccion'),
              child: Monto(_total, tamano: 36),
            ),
          ),
          if (!_quedanLineas)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'Para quitar todo, anula la venta',
                key: Key('texto_sin_lineas'),
                textAlign: TextAlign.center,
                style: TextStyle(color: ColoresApp.sale),
              ),
            ),
          ?error,
        ],
```

- agregar el método:

```dart
  Widget _filaLinea(LineaVenta linea) {
    final cantidad = _cantidad(linea);
    void cambiar(int nueva) => setState(() {
          _cantidades[linea.id] = nueva;
          _error = null;
        });
    return Row(
      children: [
        Expanded(child: Text(linea.descripcion)),
        IconButton(
          key: Key('restar_linea_${linea.id}'),
          tooltip: 'Restar',
          icon: const Icon(Icons.remove_rounded),
          onPressed: () => cambiar(cantidad - 1),
        ),
        Text('$cantidad', key: Key('cantidad_linea_${linea.id}')),
        IconButton(
          key: Key('sumar_linea_${linea.id}'),
          tooltip: 'Sumar',
          icon: const Icon(Icons.add_rounded),
          onPressed: () => cambiar(cantidad + 1),
        ),
        IconButton(
          key: Key('quitar_linea_${linea.id}'),
          tooltip: 'Quitar',
          icon: const Icon(Icons.delete_outline_rounded),
          color: ColoresApp.sale,
          onPressed: () => cambiar(0),
        ),
      ],
    );
  }
```

- [ ] **Step 5: Correr y ver que pasa**

Run: `flutter test test/screens/correccion test/screens/historial test/screens/fiado`
Expected: PASS (las pruebas viejas de la hoja usan ventas sin líneas: siguen con el teclado de monto).

- [ ] **Step 6: Commit**

```bash
git add lib/providers/lineas_venta_providers.dart lib/screens/correccion/hoja_movimiento.dart test/screens/correccion/hoja_movimiento_test.dart
git commit -m "Show a sale's products in the movement sheet and edit their quantities"
```

---

### Task 5: Ranking y horas en `ReporteRepository`

**Files:**
- Modify: `lib/repositories/reporte_repository.dart`
- Test: `test/repositories/reporte_ranking_test.dart`

**Interfaces:**
- Consumes: `db.lineasVenta` (Task 1); `VentaRepository.registrarVenta(lineas:)`, `LineaNueva` (Task 2).
- Produces: `class ProductoVendido { final int productoId; final String nombre; final int unidades; final int dinero; }`; `Reporte` gana `List<ProductoVendido> ranking`, `int otrosMontos`, `Map<int, int> ventasPorHora` (solo horas con ventas, claves en orden ascendente), `int? horaPico`.

- [ ] **Step 1: Escribir las pruebas que fallan**

`test/repositories/reporte_ranking_test.dart`:

```dart
import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/repositories/fiado_repository.dart';
import 'package:app_ventas/repositories/reporte_repository.dart';
import 'package:app_ventas/repositories/venta_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late ReporteRepository repo;
  late VentaRepository ventas;
  late int ana;
  final lunes = DateTime(2026, 10, 5);
  final domingo = DateTime(2026, 10, 11);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = ReporteRepository(db, FiadoRepository(db));
    ventas = VentaRepository(db);
    ana = await db.into(db.usuarios).insert(
        UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'x'));
  });

  tearDown(() => db.close());

  Future<int> producto(String nombre, int precio) => db
      .into(db.productos)
      .insert(ProductosCompanion.insert(nombre: nombre, precio: precio));

  LineaNueva de(int productoId, String nombre, int precio, int cantidad) =>
      LineaNueva(
          productoId: productoId,
          descripcion: nombre,
          precioUnitario: precio,
          cantidad: cantidad);

  Future<int> vender(DateTime fecha, List<LineaNueva> lineas) =>
      ventas.registrarVenta(
          monto: lineas.fold(0, (s, l) => s + l.subtotal),
          esFiado: false,
          usuarioId: ana,
          fecha: fecha,
          lineas: lineas);

  test('ordena por unidades, desempata por dinero y aparta los montos sueltos',
      () async {
    final arepa = await producto('Arepa', 3500);
    final coca = await producto('Cocacola', 1200);
    final pan = await producto('Pan', 500);
    await vender(DateTime(2026, 10, 5, 9),
        [de(arepa, 'Arepa', 3500, 2), de(coca, 'Cocacola', 1200, 1)]);
    await vender(DateTime(2026, 10, 6, 10), [
      de(coca, 'Cocacola', 1200, 1),
      const LineaNueva(descripcion: r'$5.000', precioUnitario: 5000, cantidad: 1),
    ]);
    await vender(DateTime(2026, 10, 6, 11), [de(pan, 'Pan', 500, 2)]);
    final anulada =
        await vender(DateTime(2026, 10, 7), [de(pan, 'Pan', 500, 10)]);
    await db.customStatement(
        'UPDATE ventas SET anulado = 1 WHERE id = ?', [anulada]);
    await vender(DateTime(2026, 10, 12), [de(pan, 'Pan', 500, 50)]);

    final r = await repo.reporte(lunes, domingo);

    expect(r.ranking.map((p) => p.nombre), ['Arepa', 'Cocacola', 'Pan']);
    expect(r.ranking.map((p) => p.unidades), [2, 2, 2]);
    expect(r.ranking.map((p) => p.dinero), [7000, 2400, 1000]);
    expect(r.otrosMontos, 5000);
  });

  test('un producto renombrado se agrupa con su nombre actual', () async {
    final arepa = await producto('Arepa', 3500);
    await vender(DateTime(2026, 10, 5), [de(arepa, 'Arepa', 3500, 1)]);
    await (db.update(db.productos)..where((p) => p.id.equals(arepa)))
        .write(const ProductosCompanion(nombre: Value('Arepa de queso')));
    await vender(DateTime(2026, 10, 6), [de(arepa, 'Arepa de queso', 4000, 2)]);

    final r = await repo.reporte(lunes, domingo);

    expect(r.ranking.single.nombre, 'Arepa de queso');
    expect(r.ranking.single.unidades, 3);
    expect(r.ranking.single.dinero, 11500);
  });

  test('el ranking se corta en 10', () async {
    for (var i = 1; i <= 12; i++) {
      final id = await producto('P$i', 100);
      await vender(DateTime(2026, 10, 5), [de(id, 'P$i', 100, i)]);
    }

    final r = await repo.reporte(lunes, domingo);

    expect(r.ranking, hasLength(10));
    expect(r.ranking.first.unidades, 12);
    expect(r.ranking.last.unidades, 3);
  });

  test('las horas suman por hora local y la pico es la de más dinero',
      () async {
    await ventas.registrarVenta(
        monto: 1000, esFiado: false, usuarioId: ana,
        fecha: DateTime(2026, 10, 5, 9, 15));
    await ventas.registrarVenta(
        monto: 2000, esFiado: false, usuarioId: ana,
        fecha: DateTime(2026, 10, 6, 9, 40));
    await ventas.registrarVenta(
        monto: 2500, esFiado: false, usuarioId: ana,
        fecha: DateTime(2026, 10, 6, 18, 5));
    final anulada = await ventas.registrarVenta(
        monto: 9000, esFiado: false, usuarioId: ana,
        fecha: DateTime(2026, 10, 6, 20));
    await db.customStatement(
        'UPDATE ventas SET anulado = 1 WHERE id = ?', [anulada]);

    final r = await repo.reporte(lunes, domingo);

    expect(r.ventasPorHora, {9: 3000, 18: 2500});
    expect(r.ventasPorHora.keys.toList(), [9, 18]);
    expect(r.horaPico, 9);
    expect(r.ranking, isEmpty);
    expect(r.otrosMontos, 0);
  });

  test('en un empate de horas gana la más temprana', () async {
    await ventas.registrarVenta(
        monto: 2000, esFiado: false, usuarioId: ana,
        fecha: DateTime(2026, 10, 5, 18));
    await ventas.registrarVenta(
        monto: 2000, esFiado: false, usuarioId: ana,
        fecha: DateTime(2026, 10, 5, 7));

    expect((await repo.reporte(lunes, domingo)).horaPico, 7);
  });

  test('sin ventas no hay hora pico', () async {
    final r = await repo.reporte(lunes, domingo);
    expect(r.ventasPorHora, isEmpty);
    expect(r.horaPico, isNull);
  });
}
```

Agregar `import 'package:drift/drift.dart' show Value;` para `Value`.

- [ ] **Step 2: Correr y ver que falla**

Run: `flutter test test/repositories/reporte_ranking_test.dart`
Expected: FAIL (`ranking`, `otrosMontos`, `ventasPorHora`, `horaPico` no existen).

- [ ] **Step 3: Implementar**

En `lib/repositories/reporte_repository.dart`:

- antes de `class Reporte`:

```dart
/// Un producto del ranking del periodo.
class ProductoVendido {
  const ProductoVendido({
    required this.productoId,
    required this.nombre,
    required this.unidades,
    required this.dinero,
  });

  final int productoId;

  /// Nombre actual del producto.
  final String nombre;
  final int unidades;
  final int dinero;
}
```

- en `Reporte`: agregar al constructor `required this.ranking, required this.otrosMontos, required this.ventasPorHora, required this.horaPico,` y los campos:

```dart
  /// Hasta 10 productos, por unidades (empate: dinero, luego nombre).
  final List<ProductoVendido> ranking;

  /// Dinero de líneas sin producto ("+ Otro" y montos rápidos).
  final int otrosMontos;

  /// Hora local (0–23) → dinero vendido; solo horas con ventas, en orden.
  final Map<int, int> ventasPorHora;

  /// Hora de más dinero (empate: la más temprana); null sin ventas.
  final int? horaPico;
```

- en `reporte(...)`, después de calcular `mejorDia` y antes del `return`:

```dart
    final filas = await (_db.select(_db.lineasVenta).join([
      innerJoin(_db.ventas, _db.ventas.id.equalsExp(_db.lineasVenta.ventaId)),
    ])
          ..where(_db.ventas.anulado.equals(false) &
              _db.ventas.fecha.isBetweenValues(inicio, fin)))
        .get();
    final nombres = {
      for (final p in await _db.select(_db.productos).get()) p.id: p.nombre,
    };
    final acumulado = <int, ({String nombre, int unidades, int dinero})>{};
    var otrosMontos = 0;
    for (final fila in filas) {
      final linea = fila.readTable(_db.lineasVenta);
      final subtotal = linea.precioUnitario * linea.cantidad;
      final productoId = linea.productoId;
      if (productoId == null) {
        otrosMontos += subtotal;
        continue;
      }
      final previo = acumulado[productoId];
      acumulado[productoId] = (
        nombre: nombres[productoId] ?? linea.descripcion,
        unidades: (previo?.unidades ?? 0) + linea.cantidad,
        dinero: (previo?.dinero ?? 0) + subtotal,
      );
    }
    final ranking = [
      for (final e in acumulado.entries)
        ProductoVendido(
          productoId: e.key,
          nombre: e.value.nombre,
          unidades: e.value.unidades,
          dinero: e.value.dinero,
        ),
    ]..sort((a, b) {
        final porUnidades = b.unidades.compareTo(a.unidades);
        if (porUnidades != 0) return porUnidades;
        final porDinero = b.dinero.compareTo(a.dinero);
        if (porDinero != 0) return porDinero;
        return a.nombre.compareTo(b.nombre);
      });

    final porHoraDesordenado = <int, int>{};
    for (final v in ventas) {
      porHoraDesordenado.update(v.fecha.hour, (s) => s + v.monto,
          ifAbsent: () => v.monto);
    }
    final horas = porHoraDesordenado.keys.toList()..sort();
    final ventasPorHora = {for (final h in horas) h: porHoraDesordenado[h]!};
    int? horaPico;
    for (final h in horas) {
      if (horaPico == null || ventasPorHora[h]! > ventasPorHora[horaPico]!) {
        horaPico = h;
      }
    }
```

- en el `return Reporte(...)` agregar:

```dart
      ranking: ranking.take(10).toList(),
      otrosMontos: otrosMontos,
      ventasPorHora: ventasPorHora,
      horaPico: horaPico,
```

- [ ] **Step 4: Correr y ver que pasa**

Run: `flutter test test/repositories`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/repositories/reporte_repository.dart test/repositories/reporte_ranking_test.dart
git commit -m "Add top products and sales by hour to the period report"
```

---

### Task 6: Barras genéricas y secciones nuevas en Reportes

**Files:**
- Modify: `lib/screens/reportes/barras_por_dia.dart`
- Modify: `lib/screens/reportes/reportes_screen.dart` (`_Contenido`)
- Modify: `test/screens/reportes/barras_por_dia_test.dart`
- Modify: `test/screens/reportes/reportes_screen_test.dart`

**Interfaces:**
- Consumes: `Reporte.ranking`, `otrosMontos`, `ventasPorHora`, `horaPico` (Task 5); `VentaRepository.registrarVenta(lineas:)`, `LineaNueva` (Task 2).
- Produces: `String etiquetaHora(int hora)`; `class FilaBarra { const FilaBarra({required String clave, required String etiqueta, required int valor}); }`; `Barras({Key? key, required List<FilaBarra> filas, String? resaltada})`; `Barra` (antes `BarraDia`) con la misma API; llaves `barra_<clave>` (días: `barra_6`; horas: `barra_h18`), `ranking_<i>`, `texto_otros_montos`, `texto_sin_detalle`, `texto_hora_pico`.

- [ ] **Step 1: Escribir las pruebas que fallan**

En `test/screens/reportes/barras_por_dia_test.dart`: reemplazar todas las apariciones de `BarraDia` por `Barra`, y agregar:

```dart
  test('etiquetaHora usa a. m., m. y p. m.', () {
    expect(etiquetaHora(0), '12 a. m.');
    expect(etiquetaHora(7), '7 a. m.');
    expect(etiquetaHora(12), '12 m.');
    expect(etiquetaHora(13), '1 p. m.');
    expect(etiquetaHora(18), '6 p. m.');
    expect(etiquetaHora(23), '11 p. m.');
  });

  testWidgets('Barras resalta la fila indicada', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Barras(
          filas: [
            FilaBarra(clave: 'h9', etiqueta: '9 a. m.', valor: 3000),
            FilaBarra(clave: 'h18', etiqueta: '6 p. m.', valor: 1500),
          ],
          resaltada: 'h9',
        ),
      ),
    ));

    expect(tester.widget<Barra>(find.byKey(const Key('barra_h9'))).resaltada,
        isTrue);
    expect(tester.widget<Barra>(find.byKey(const Key('barra_h18'))).fraccion,
        0.5);
  });
```

En `test/screens/reportes/reportes_screen_test.dart`: reemplazar `BarraDia` por `Barra`, agregar `import 'package:app_ventas/repositories/venta_repository.dart';` y dentro de `main()`:

```dart
  testWidgets('muestra el ranking, otros montos y la hora pico',
      (tester) async {
    final arepa = await db
        .into(db.productos)
        .insert(ProductosCompanion.insert(nombre: 'Arepa', precio: 3500));
    await VentaRepository(db).registrarVenta(
      monto: 12000,
      esFiado: false,
      usuarioId: ana,
      fecha: DateTime(2026, 10, 6, 18, 20),
      lineas: [
        LineaNueva(
            productoId: arepa,
            descripcion: 'Arepa',
            precioUnitario: 3500,
            cantidad: 2),
        const LineaNueva(
            descripcion: r'$5.000', precioUnitario: 5000, cantidad: 1),
      ],
    );
    await vender(1000, DateTime(2026, 10, 6, 8));
    await montar(tester);

    expect(find.text('Productos más vendidos'), findsOneWidget);
    expect(find.text(r'1. Arepa · 2 u · $7.000'), findsOneWidget);
    expect(find.text(r'Otros montos · $5.000'), findsOneWidget);
    expect(find.text('Horas de más venta'), findsOneWidget);
    expect(find.text(r'Hora pico: 6 p. m. · $12.000'), findsOneWidget);
    expect(find.text('8 a. m.'), findsOneWidget);
    expect(tester.widget<Barra>(find.byKey(const Key('barra_h18'))).resaltada,
        isTrue);
  });

  testWidgets('con ventas sin detalle avisa en el ranking pero muestra horas',
      (tester) async {
    await vender(4000, DateTime(2026, 10, 6, 10));
    await montar(tester);

    expect(
        find.text('Aún no hay ventas con detalle de productos en este periodo'),
        findsOneWidget);
    expect(find.text(r'Hora pico: 10 a. m. · $4.000'), findsOneWidget);
  });
```

- [ ] **Step 2: Correr y ver que falla**

Run: `flutter test test/screens/reportes`
Expected: FAIL (`Barra`, `Barras`, `FilaBarra`, `etiquetaHora` no existen).

- [ ] **Step 3: Generalizar las barras**

En `lib/screens/reportes/barras_por_dia.dart`:

- agregar después de `etiquetaDia`:

```dart
/// "12 a. m.", "7 a. m.", "12 m.", "6 p. m.".
String etiquetaHora(int hora) {
  if (hora == 0) return '12 a. m.';
  if (hora < 12) return '$hora a. m.';
  if (hora == 12) return '12 m.';
  return '${hora - 12} p. m.';
}

/// Una fila de [Barras]: su llave (`barra_<clave>`), etiqueta y valor.
class FilaBarra {
  const FilaBarra({
    required this.clave,
    required this.etiqueta,
    required this.valor,
  });

  final String clave;
  final String etiqueta;
  final int valor;
}

/// Barras horizontales proporcionales al mayor valor, con [resaltada] (una
/// clave) en verde intenso.
class Barras extends StatelessWidget {
  const Barras({super.key, required this.filas, this.resaltada});

  final List<FilaBarra> filas;
  final String? resaltada;

  @override
  Widget build(BuildContext context) {
    final maximo = filas.fold<int>(0, (m, f) => f.valor > m ? f.valor : m);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final fila in filas)
          Barra(
            key: Key('barra_${fila.clave}'),
            etiqueta: fila.etiqueta,
            valor: fila.valor,
            fraccion: maximo == 0 ? 0.0 : fila.valor / maximo,
            resaltada: fila.clave == resaltada,
          ),
      ],
    );
  }
}
```

- en `BarrasPorDia.build`, reemplazar el `for (final entrada in ventasPorDia.entries) BarraDia(...)` y el cálculo de `maximo` por:

```dart
        Barras(
          filas: [
            for (final entrada in ventasPorDia.entries)
              FilaBarra(
                clave: '${entrada.key.day}',
                etiqueta: etiquetaDia(entrada.key),
                valor: entrada.value,
              ),
          ],
          resaltada: mejor == null ? null : '${mejor.day}',
        ),
```

  (quitar la variable `maximo`, ya no se usa ahí).
- renombrar la clase `BarraDia` a `Barra` (constructor incluido), cambiar su doc a `/// Una fila: etiqueta, barra proporcional y monto.` y el ancho de la etiqueta de `56` a `64` (para "12 a. m.").

- [ ] **Step 4: Secciones en Reportes**

En `lib/screens/reportes/reportes_screen.dart`, al final de los `children` de `_Contenido`, después de `BarrasPorDia(ventasPorDia: r.ventasPorDia, mejorDia: r.mejorDia),`:

```dart
        const _Titulo('Productos más vendidos'),
        if (r.ranking.isEmpty && r.otrosMontos == 0)
          const Text(
            'Aún no hay ventas con detalle de productos en este periodo',
            key: Key('texto_sin_detalle'),
            style: gris,
          )
        else ...[
          for (final (i, p) in r.ranking.indexed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                '${i + 1}. ${p.nombre} · ${p.unidades} u · '
                '${formatoMoneda(p.dinero)}',
                key: Key('ranking_$i'),
              ),
            ),
          if (r.otrosMontos > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Otros montos · ${formatoMoneda(r.otrosMontos)}',
                key: const Key('texto_otros_montos'),
                style: gris,
              ),
            ),
        ],
        const _Titulo('Horas de más venta'),
        if (r.horaPico case final pico?)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Hora pico: ${etiquetaHora(pico)} · '
              '${formatoMoneda(r.ventasPorHora[pico]!)}',
              key: const Key('texto_hora_pico'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        Barras(
          filas: [
            for (final e in r.ventasPorHora.entries)
              FilaBarra(
                clave: 'h${e.key}',
                etiqueta: etiquetaHora(e.key),
                valor: e.value,
              ),
          ],
          resaltada: r.horaPico == null ? null : 'h${r.horaPico}',
        ),
```

- [ ] **Step 5: Correr y ver que pasa**

Run: `flutter test test/screens/reportes`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add lib/screens/reportes test/screens/reportes
git commit -m "Show top products and peak hours in Reportes"
```

---

### Task 7: Verificación final

**Files:**
- Modify: `docs/superpowers/specs/2026-10-07-vecitienda-detalle-tickets-design.md` (línea `**Estado:**`)
- Modify: `docs/hoja-de-ruta.md` (mover la 3C a "Hecho")

- [ ] **Step 1: Análisis y suite completa**

Run: `flutter analyze` y `flutter test`
Expected: "No issues found!" y todas las pruebas pasan.

- [ ] **Step 2: Compilar**

Run: `flutter build apk --debug`
Expected: "Built build\app\outputs\flutter-apk\app-debug.apk".

- [ ] **Step 3: Documentación**

- Especificación: `**Estado:** Diseño aprobado, pendiente de plan` → `**Estado:** Implementado (falta el recorrido manual en un celular real)`.
- `docs/hoja-de-ruta.md`: mover "Fase 3C" de "En curso" a "Hecho" (una línea: "Fase 3C — detalle de tickets, productos más vendidos y horas de venta.") y dejar "En curso" con "Nada; siguiente: Fase 4.".

- [ ] **Step 4: Commit**

```bash
git add docs/superpowers/specs/2026-10-07-vecitienda-detalle-tickets-design.md docs/hoja-de-ruta.md
git commit -m "Mark Fase 3C as implemented"
```
