# Fase 4C — Pedido sugerido por proveedor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Desde cada grupo de "Por pedir" el tendero ve el pedido sugerido (cantidades con "Pedir hasta", precio de ese proveedor, total estimado), lo ajusta en pantalla y lo recibe abriendo Recibir mercancía ya llena.

**Architecture:** Esquema v7 agrega `productos.pedirHasta`. `InventarioRepository.sugerenciaPedido(proveedorId)` arma las líneas desde `porPedir()` con la regla del sugerido y el precio de ese proveedor. `PedidoSugeridoScreen` muestra y edita (sin guardar) y abre `RecibirMercanciaScreen`, que ahora acepta proveedor y líneas iniciales. Producto edita "Pedir hasta".

**Tech Stack:** Flutter 3.47 / Dart ^3.13, flutter_riverpod 2.6, Drift 2.34 (+ build_runner). Sin dependencias nuevas.

**Spec:** `docs/superpowers/specs/2026-10-07-vecitienda-pedido-sugerido-design.md`

## Global Constraints

- `schemaVersion = 7`; migración `desde < 7`: `addColumn(productos, pedirHasta)`. `CopiaBaseDatos.tablas` no cambia.
- Después de cada cambio en `lib/data/database.dart`: `dart run build_runner build --delete-conflicting-outputs`.
- Sugerido = `(pedirHasta ?? 2 × mínimo) − existencias`, nunca menor que 1.
- Precio de una línea = `precioCompra` del producto con ese proveedor; null en "Sin proveedor" o si no lo tiene.
- Total estimado = Σ cantidad × precio de líneas con precio y cantidad > 0.
- Pedir hasta: opcional, ≥ 0 y ≥ mínimo; si no, `ArgumentError` en el repositorio y error en pantalla "Debe ser mayor o igual que el mínimo" (o "Escribe un número válido" si no es número ≥ 0).
- No se envían ni se guardan pedidos.
- Textos exactos: "Ver pedido sugerido", "Pedido sugerido · Postobón", "Pedido sugerido · Sin proveedor", "quedan 2 · mín. 6 · hasta 24", "$900 c/u", "Sin precio", "Total estimado $X", "Recibir este pedido", "Pedir hasta", "Debe ser mayor o igual que el mínimo", "Escribe un número válido".
- Trabajar en una rama nueva `fase4c-pedido-sugerido` desde `master`.

## Review Focus

1. Vaciar "Pedir hasta" en Producto → se borra y el sugerido vuelve a 2 × mínimo (prueba en Task 3).
2. Subir el mínimo por encima de un "Pedir hasta" ya guardado → error en pantalla y nada se guarda (prueba en Task 3).
3. Recibir desde el pedido sugerido → al volver a Inventario aparece "Mercancía recibida · $X" y las existencias suben (prueba en Task 5).
4. Grupo "Sin proveedor" → Recibir abre sin proveedor y no deja guardar hasta elegirlo (prueba en Task 5).
5. Todas las cantidades en 0 → "Recibir este pedido" deshabilitado (prueba en Task 5).

---

### Task 1: Esquema v7 — `pedirHasta`

**Files:**
- Modify: `lib/data/database.dart`
- Regenerate: `lib/data/database.g.dart`
- Create: `test/support/esquema_v6.dart`
- Modify: `test/data/migracion_test.dart`
- Modify: `test/respaldo/copia_base_datos_test.dart` (`versionMaxima: 6` → `7`)

**Interfaces:**
- Produces: `Producto.pedirHasta` (`int?`), `ProductosCompanion(pedirHasta: Value<int?>)`.

- [ ] **Step 1: Crear la rama**

```bash
git checkout master
git checkout -b fase4c-pedido-sugerido
```

- [ ] **Step 2: Fixture v6**

`test/support/esquema_v6.dart`:

```dart
import 'package:sqlite3/sqlite3.dart';

import 'esquema_v5.dart';

/// Crea en [ruta] una base con el esquema v6 de la app (4B, antes de la 4C):
/// el de v5 más control de existencias, conteos y entradas de mercancía.
void crearBaseV6(String ruta) {
  crearBaseV5(ruta);
  sqlite3.open(ruta)
    ..execute('''
      ALTER TABLE productos ADD COLUMN controla_existencias INTEGER NOT NULL
        DEFAULT 0 CHECK (controla_existencias IN (0, 1));
      ALTER TABLE productos ADD COLUMN minimo INTEGER NOT NULL DEFAULT 0;
      CREATE TABLE conteos_inventario (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        producto_id INTEGER NOT NULL REFERENCES productos (id),
        cantidad INTEGER NOT NULL, anterior INTEGER NULL, tipo TEXT NOT NULL,
        nota TEXT NULL, usuario_id INTEGER NOT NULL REFERENCES usuarios (id),
        fecha INTEGER NOT NULL);
      CREATE TABLE entradas_mercancia (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        proveedor_id INTEGER NOT NULL REFERENCES proveedores (id),
        usuario_id INTEGER NOT NULL REFERENCES usuarios (id),
        fecha INTEGER NOT NULL, total INTEGER NOT NULL, nota TEXT NULL,
        anulada INTEGER NOT NULL DEFAULT 0 CHECK (anulada IN (0, 1)),
        anulada_por_id INTEGER NULL REFERENCES usuarios (id));
      CREATE TABLE lineas_entrada (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        entrada_id INTEGER NOT NULL REFERENCES entradas_mercancia (id),
        producto_id INTEGER NOT NULL REFERENCES productos (id),
        cantidad INTEGER NOT NULL, precio_compra INTEGER NOT NULL);
      UPDATE productos SET controla_existencias = 1, minimo = 5;
    ''')
    ..userVersion = 6
    ..close();
}
```

- [ ] **Step 3: Escribir las pruebas que fallan**

En `test/data/migracion_test.dart`: agregar `import '../support/esquema_v6.dart';`, cambiar `expect(db.schemaVersion, 6);` por `expect(db.schemaVersion, 7);` y agregar dentro de `main()`:

```dart
  test('una base v6 abre en v7 con pedir hasta vacío', () async {
    final archivo = File('${carpeta.path}/v6.sqlite');
    crearBaseV6(archivo.path);

    final db = AppDatabase(NativeDatabase(archivo));
    addTearDown(db.close);

    final producto = await db.select(db.productos).getSingle();
    expect(producto.controlaExistencias, isTrue);
    expect(producto.minimo, 5);
    expect(producto.pedirHasta, isNull);
  });

  test('una base v1 abre en v7 y guarda pedir hasta', () async {
    final archivo = File('${carpeta.path}/v1c.sqlite');
    crearBaseV1(archivo.path);

    final db = AppDatabase(NativeDatabase(archivo));
    addTearDown(db.close);

    final id = await db.into(db.productos).insert(ProductosCompanion.insert(
        nombre: 'Pan', precio: 500, pedirHasta: const Value(24)));
    expect(
        (await (db.select(db.productos)..where((p) => p.id.equals(id)))
                .getSingle())
            .pedirHasta,
        24);
  });
```

En `test/respaldo/copia_base_datos_test.dart` cambiar `versionMaxima: 6` por `versionMaxima: 7`.

- [ ] **Step 4: Correr y ver que falla**

Run: `flutter test test/data/migracion_test.dart`
Expected: FAIL de compilación (`pedirHasta` no existe).

- [ ] **Step 5: Implementar**

En `lib/data/database.dart`, en `Productos` después de `minimo`:

```dart

  /// Cuántas quiere tener después de pedir; sugiere la cantidad del pedido.
  IntColumn get pedirHasta => integer().nullable()();
```

- `int get schemaVersion => 7;`
- en `onUpgrade`, después del bloque `if (desde < 6) {...}`:

```dart
          if (desde < 7) {
            await m.addColumn(productos, productos.pedirHasta);
          }
```

Run: `dart run build_runner build --delete-conflicting-outputs`

- [ ] **Step 6: Correr y ver que pasa**

Run: `flutter test test/data test/respaldo` y `flutter analyze lib test`
Expected: PASS y "No issues found!"

- [ ] **Step 7: Commit**

```bash
git add lib/data test/support/esquema_v6.dart test/data/migracion_test.dart test/respaldo/copia_base_datos_test.dart
git commit -m "Add the order-up-to quantity per product (schema v7)"
```

---

### Task 2: `sugerenciaPedido` y `cambiarPedirHasta`

**Files:**
- Modify: `lib/repositories/inventario_repository.dart`
- Modify: `lib/providers/inventario_providers.dart`
- Test: `test/repositories/pedido_sugerido_test.dart`

**Interfaces:**
- Consumes: `porPedir()`, `GrupoPorPedir`, `ProductoPorPedir` (4B); `Producto.pedirHasta` (Task 1).
- Produces: `class LineaSugerida { const LineaSugerida({required Producto producto, required int existencias, required int sugerido, int? precio}); }`; `Future<List<LineaSugerida>> sugerenciaPedido(int? proveedorId)`; `Future<void> cambiarPedirHasta(int productoId, int? pedirHasta)` (`ArgumentError` si < 0 o < mínimo); `sugerenciaPedidoProvider` (`FutureProvider.autoDispose.family<List<LineaSugerida>, int?>`).

- [ ] **Step 1: Escribir la prueba que falla**

`test/repositories/pedido_sugerido_test.dart`:

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
  late Usuario ana;
  late int postobon;
  late int alpina;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = InventarioRepository(db, reloj: () => DateTime(2026, 10, 7, 8));
    final id = await db.into(db.usuarios).insert(
        UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'x'));
    ana = await (db.select(db.usuarios)..where((u) => u.id.equals(id)))
        .getSingle();
    postobon = await ProveedorRepository(db).crear(nombre: 'Postobón');
    alpina = await ProveedorRepository(db).crear(nombre: 'Alpina');
  });

  tearDown(() => db.close());

  Future<int> producto(String nombre,
          {List<ProveedorDeProducto> proveedores = const []}) =>
      ProductoRepository(db)
          .guardarProducto(nombre: nombre, precio: 1000, proveedores: proveedores);

  ProveedorDeProducto de(int id, int precio, {bool preferido = false}) =>
      ProveedorDeProducto(
          proveedorId: id, precioCompra: precio, preferido: preferido);

  test('con pedir hasta, sin él, negativo y nunca menos de 1', () async {
    final coca = await producto('Coca', proveedores: [
      de(postobon, 900, preferido: true),
      de(alpina, 850),
    ]);
    final pan = await producto('Pan', proveedores: [de(postobon, 400, preferido: true)]);
    final agua = await producto('Agua', proveedores: [de(postobon, 700, preferido: true)]);
    await repo.activarControl(coca, cantidad: 1, minimo: 5, por: ana);
    await repo.cambiarPedirHasta(coca, 24);
    await repo.activarControl(pan, cantidad: 2, minimo: 6, por: ana);
    await repo.activarControl(agua, cantidad: 0, minimo: 0, por: ana);
    await VentaRepository(db).registrarVenta(
      monto: 3000,
      esFiado: false,
      usuarioId: ana.id,
      fecha: DateTime(2026, 10, 7, 9),
      lineas: [
        LineaNueva(
            productoId: coca, descripcion: 'Coca', precioUnitario: 1000, cantidad: 3),
      ],
    );

    final lineas = await repo.sugerenciaPedido(postobon);

    expect(lineas.map((l) => l.producto.nombre), ['Coca', 'Pan', 'Agua']);
    expect(lineas.map((l) => (l.existencias, l.sugerido, l.precio)), [
      (-2, 26, 900),
      (2, 10, 400),
      (0, 1, 700),
    ]);
  });

  test('sin proveedor no hay precio', () async {
    final pan = await producto('Pan');
    await repo.activarControl(pan, cantidad: 1, minimo: 3, por: ana);

    final lineas = await repo.sugerenciaPedido(null);

    expect(lineas.single.producto.id, pan);
    expect(lineas.single.sugerido, 5);
    expect(lineas.single.precio, isNull);
    expect(await repo.sugerenciaPedido(postobon), isEmpty);
  });

  test('cambiarPedirHasta guarda, borra y valida', () async {
    final pan = await producto('Pan');
    await repo.activarControl(pan, cantidad: 1, minimo: 3, por: ana);

    await repo.cambiarPedirHasta(pan, 12);
    Future<int?> leer() async => (await (db.select(db.productos)
              ..where((p) => p.id.equals(pan)))
            .getSingle())
        .pedirHasta;
    expect(await leer(), 12);

    await repo.cambiarPedirHasta(pan, null);
    expect(await leer(), isNull);

    await expectLater(repo.cambiarPedirHasta(pan, -1), throwsArgumentError);
    await expectLater(repo.cambiarPedirHasta(pan, 2), throwsArgumentError);
    expect(await leer(), isNull);
  });
}
```

- [ ] **Step 2: Correr y ver que falla**

Run: `flutter test test/repositories/pedido_sugerido_test.dart`
Expected: FAIL (`cambiarPedirHasta`, `sugerenciaPedido` no existen).

- [ ] **Step 3: Implementar**

En `lib/repositories/inventario_repository.dart`, antes de la clase:

```dart
/// Una línea del pedido sugerido a un proveedor.
class LineaSugerida {
  const LineaSugerida({
    required this.producto,
    required this.existencias,
    required this.sugerido,
    this.precio,
  });

  final Producto producto;
  final int existencias;

  /// (pedirHasta ?? 2 × mínimo) − existencias, nunca menos de 1.
  final int sugerido;

  /// Precio de compra con ese proveedor; null si no lo tiene.
  final int? precio;
}
```

y dentro de la clase, al final:

```dart
  // ---- Pedido sugerido ----

  /// Cambia "pedir hasta" (null lo borra); debe ser ≥ 0 y ≥ mínimo.
  Future<void> cambiarPedirHasta(int productoId, int? pedirHasta) async {
    if (pedirHasta != null) {
      final producto = await (_db.select(_db.productos)
            ..where((p) => p.id.equals(productoId)))
          .getSingle();
      if (pedirHasta < 0 || pedirHasta < producto.minimo) {
        throw ArgumentError('Debe ser mayor o igual que el mínimo');
      }
    }
    await (_db.update(_db.productos)..where((p) => p.id.equals(productoId)))
        .write(ProductosCompanion(pedirHasta: Value(pedirHasta)));
  }

  /// Pedido sugerido para el grupo de "Por pedir" de [proveedorId] (null =
  /// "Sin proveedor"), en el mismo orden.
  Future<List<LineaSugerida>> sugerenciaPedido(int? proveedorId) async {
    final grupo = (await porPedir())
        .where((g) => g.proveedor?.id == proveedorId)
        .firstOrNull;
    if (grupo == null) return const [];
    final precios = proveedorId == null
        ? const <int, int>{}
        : {
            for (final v in await (_db.select(_db.productosProveedores)
                  ..where((v) => v.proveedorId.equals(proveedorId)))
                .get())
              v.productoId: v.precioCompra,
          };
    return [
      for (final p in grupo.productos)
        LineaSugerida(
          producto: p.producto,
          existencias: p.existencias,
          sugerido: ((p.producto.pedirHasta ?? 2 * p.producto.minimo) -
                  p.existencias)
              .clamp(1, 1 << 30),
          precio: precios[p.producto.id],
        ),
    ];
  }
```

En `lib/providers/inventario_providers.dart`, al final:

```dart
final sugerenciaPedidoProvider = FutureProvider.autoDispose
    .family<List<LineaSugerida>, int?>((ref, proveedorId) {
  ref.watch(_cambiosInventarioProvider);
  return ref.watch(inventarioRepositoryProvider).sugerenciaPedido(proveedorId);
});
```

- [ ] **Step 4: Correr y ver que pasa**

Run: `flutter test test/repositories` y `flutter analyze lib`
Expected: PASS y "No issues found!"

- [ ] **Step 5: Commit**

```bash
git add lib/repositories/inventario_repository.dart lib/providers/inventario_providers.dart test/repositories/pedido_sugerido_test.dart
git commit -m "Build the suggested order per supplier and set the order-up-to quantity"
```

---

### Task 3: "Pedir hasta" en Producto

**Files:**
- Modify: `lib/screens/configuracion/producto_screen.dart`
- Modify: `test/screens/configuracion/productos_screen_test.dart`

**Interfaces:**
- Consumes: `InventarioRepository.cambiarPedirHasta` (Task 2).
- Produces: llave `campo_pedir_hasta`.

- [ ] **Step 1: Escribir las pruebas que fallan**

En `test/screens/configuracion/productos_screen_test.dart`, dentro de `main()` (antes de su `}` de cierre, que va antes de `/// Demora la carga de proveedores`):

```dart
  testWidgets('pedir hasta se guarda, se borra y no puede ser menor al mínimo',
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
    await tester.enterText(find.byKey(const Key('campo_hay_ahora')), '2');
    await tester.enterText(find.byKey(const Key('campo_minimo')), '5');
    await tester.enterText(find.byKey(const Key('campo_pedir_hasta')), '3');
    await guardar(tester);

    expect(find.text('Debe ser mayor o igual que el mínimo'), findsOneWidget);
    expect(await db.select(db.productos).get(), isEmpty);

    await tester.enterText(find.byKey(const Key('campo_pedir_hasta')), '24');
    await guardar(tester);
    final producto = await db.select(db.productos).getSingle();
    expect(producto.pedirHasta, 24);

    await tester.tap(find.byKey(Key('producto_item_${producto.id}')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('campo_pedir_hasta')));
    await tester.enterText(find.byKey(const Key('campo_pedir_hasta')), '');
    await guardar(tester);
    expect((await db.select(db.productos).getSingle()).pedirHasta, isNull);
  });

  testWidgets('subir el mínimo por encima de pedir hasta muestra el error',
      (tester) async {
    final id = await crearArepa();
    final container = await containerConSesion(db, nombre: 'Beto');
    final beto = container.read(sesionProvider).usuarioActivo!;
    container.dispose();
    final inv = InventarioRepository(db);
    await inv.activarControl(id, cantidad: 10, minimo: 3, por: beto);
    await inv.cambiarPedirHasta(id, 12);
    await montar(tester);

    await tester.tap(find.byKey(Key('producto_item_$id')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('campo_minimo')));
    await tester.enterText(find.byKey(const Key('campo_minimo')), '15');
    await guardar(tester);

    expect(find.text('Debe ser mayor o igual que el mínimo'), findsOneWidget);
    final p = await db.select(db.productos).getSingle();
    expect((p.minimo, p.pedirHasta), (3, 12));
  });
```

- [ ] **Step 2: Correr y ver que falla**

Run: `flutter test test/screens/configuracion/productos_screen_test.dart`
Expected: FAIL (`campo_pedir_hasta` no existe).

- [ ] **Step 3: Implementar**

En `lib/screens/configuracion/producto_screen.dart`:

- estado, después de `late final _minimo = ...;`:

```dart
  late final _pedirHasta = TextEditingController(
    text: widget.producto?.pedirHasta?.toString() ?? '',
  );
  String? _errorPedirHasta;
```

  y `_pedirHasta.dispose();` en `dispose` (junto a `_minimo.dispose();`).
- en `_guardar`, después de `final minimo = int.tryParse(_minimo.text.trim());`:

```dart
    final textoPedirHasta = _pedirHasta.text.trim();
    final pedirHasta =
        textoPedirHasta.isEmpty ? null : int.tryParse(textoPedirHasta);
```

  dentro del primer `setState`, después de `_errorMinimo = ...;`:

```dart
      _errorPedirHasta = !_controla || textoPedirHasta.isEmpty
          ? null
          : pedirHasta == null || pedirHasta < 0
              ? 'Escribe un número válido'
              : minimo != null && pedirHasta < minimo
                  ? 'Debe ser mayor o igual que el mínimo'
                  : null;
```

  y agregar `_errorPedirHasta != null ||` a la condición que sale con `return`.
- después del bloque `if (_controla && !_controlabaAlAbrir) {...} else if (_controla) {...} else if (_controlabaAlAbrir) {...}`:

```dart
      if (_controla) {
        await inventario.cambiarPedirHasta(productoId, pedirHasta);
      }
```

- en `build`, justo después del `TextField` de `campo_minimo` (dentro del mismo `if (_controla)`, convertir en `if (_controla) ...[ campo_minimo, campo_pedir_hasta ]`):

```dart
            TextField(
              key: const Key('campo_pedir_hasta'),
              controller: _pedirHasta,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Pedir hasta',
                errorText: _errorPedirHasta,
              ),
            ),
```

- [ ] **Step 4: Correr y ver que pasa**

Run: `flutter test test/screens/configuracion` y `flutter analyze lib test`
Expected: PASS y "No issues found!"

- [ ] **Step 5: Commit**

```bash
git add lib/screens/configuracion/producto_screen.dart test/screens/configuracion/productos_screen_test.dart
git commit -m "Edit the order-up-to quantity in the product screen"
```

---

### Task 4: Recibir mercancía con datos iniciales

**Files:**
- Modify: `lib/screens/inventario/recibir_mercancia_screen.dart`
- Modify: `test/screens/inventario/recibir_mercancia_screen_test.dart`

**Interfaces:**
- Produces: `class LineaInicial { const LineaInicial({required Producto producto, required int cantidad, int? precio}); }`; `RecibirMercanciaScreen({Key? key, Proveedor? proveedorInicial, List<LineaInicial> lineasIniciales = const []})`.

- [ ] **Step 1: Escribir la prueba que falla**

En `test/screens/inventario/recibir_mercancia_screen_test.dart`, dentro de `main()`:

```dart
  testWidgets('arranca con el proveedor y las líneas que recibe', (tester) async {
    final (postobon, alpina, arepa) = await dosProveedores();
    final proveedor = await (db.select(db.proveedores)
          ..where((p) => p.id.equals(postobon)))
        .getSingle();
    final producto = await (db.select(db.productos)
          ..where((p) => p.id.equals(arepa)))
        .getSingle();
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final container = await containerConSesion(db);
    addTearDown(container.dispose);
    await tester.pumpWidget(appDePrueba(container,
        inicio: RecibirMercanciaScreen(
          proveedorInicial: proveedor,
          lineasIniciales: [
            LineaInicial(producto: producto, cantidad: 6, precio: 2500),
          ],
        )));
    await tester.pumpAndSettle();

    expect(
        tester
            .widget<ChoiceChip>(
                find.byKey(Key('opcion_proveedor_recibir_$postobon')))
            .selected,
        isTrue);
    expect(find.text('6'), findsOneWidget);
    expect(precio(tester, arepa), '2500');
    expect(find.text(r'Total $15.000'), findsOneWidget);

    await tester.tap(find.byKey(Key('opcion_proveedor_recibir_$alpina')));
    await tester.pumpAndSettle();
    expect(precio(tester, arepa), '2500');
  });
```

- [ ] **Step 2: Correr y ver que falla**

Run: `flutter test test/screens/inventario/recibir_mercancia_screen_test.dart`
Expected: FAIL (`LineaInicial`, `proveedorInicial` no existen).

- [ ] **Step 3: Implementar**

En `lib/screens/inventario/recibir_mercancia_screen.dart`:

- antes de `class RecibirMercanciaScreen`:

```dart
/// Un producto con el que arranca Recibir mercancía (p. ej. desde el pedido
/// sugerido).
class LineaInicial {
  const LineaInicial({required this.producto, required this.cantidad, this.precio});

  final Producto producto;
  final int cantidad;
  final int? precio;
}
```

- reemplazar el constructor y agregar los campos:

```dart
  const RecibirMercanciaScreen({
    super.key,
    this.proveedorInicial,
    this.lineasIniciales = const [],
  });

  final Proveedor? proveedorInicial;

  /// Sus precios cuentan como escritos: cambiar de proveedor no los reemplaza.
  final List<LineaInicial> lineasIniciales;
```

- en el estado, agregar:

```dart
  @override
  void initState() {
    super.initState();
    _proveedor = widget.proveedorInicial;
    for (final l in widget.lineasIniciales) {
      _lineas.add(_Linea(l.producto, l.precio?.toString() ?? '')
        ..cantidad = l.cantidad
        ..editado = true);
    }
  }
```

- [ ] **Step 4: Correr y ver que pasa**

Run: `flutter test test/screens/inventario` y `flutter analyze lib test`
Expected: PASS y "No issues found!"

- [ ] **Step 5: Commit**

```bash
git add lib/screens/inventario/recibir_mercancia_screen.dart test/screens/inventario/recibir_mercancia_screen_test.dart
git commit -m "Open Recibir mercancía with an initial supplier and lines"
```

---

### Task 5: Pantalla "Pedido sugerido"

**Files:**
- Create: `lib/screens/inventario/pedido_sugerido_screen.dart`
- Modify: `lib/screens/inventario/inventario_screen.dart` (botón por grupo; helper `numeroConSigno`)
- Test: `test/screens/inventario/pedido_sugerido_screen_test.dart`

**Interfaces:**
- Consumes: `sugerenciaPedidoProvider`, `LineaSugerida` (Task 2); `RecibirMercanciaScreen`, `LineaInicial` (Task 4).
- Produces: `PedidoSugeridoScreen({Key? key, required Proveedor? proveedor})` (hace `pop(total)` si se recibió); `String numeroConSigno(int n)` en `inventario_screen.dart` ("−2" / "5"); llaves `ver_pedido_<proveedorId|sin>`, `cantidad_pedido_<id>`, `restar_pedido_<id>`, `sumar_pedido_<id>`, `precio_pedido_<id>`, `total_pedido`, `boton_recibir_pedido`.

- [ ] **Step 1: Escribir la prueba que falla**

`test/screens/inventario/pedido_sugerido_screen_test.dart`:

```dart
import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/sesion_provider.dart';
import 'package:app_ventas/repositories/inventario_repository.dart';
import 'package:app_ventas/repositories/producto_repository.dart';
import 'package:app_ventas/repositories/proveedor_repository.dart';
import 'package:app_ventas/screens/inventario/inventario_screen.dart';
import 'package:app_ventas/screens/inventario/pedido_sugerido_screen.dart';
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

  bool habilitado(WidgetTester tester, String clave) =>
      tester.widget<BotonPrincipal>(find.byKey(Key(clave))).onPressed != null;

  /// Postobón con Coca ($900, quedan 2, mín. 6, hasta 24 → 22) y Pan ($400,
  /// quedan 1, mín. 5 → 9); y Agua sin proveedor (quedan 0, mín. 0 → 1).
  Future<(int, int, int, int)> preparar(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final container = await containerConSesion(db);
    addTearDown(container.dispose);
    final ana = container.read(sesionProvider).usuarioActivo!;
    final postobon = await ProveedorRepository(db).crear(nombre: 'Postobón');
    final productos = ProductoRepository(db);
    final coca = await productos.guardarProducto(
        nombre: 'Coca',
        precio: 1500,
        proveedores: [
          ProveedorDeProducto(proveedorId: postobon, precioCompra: 900, preferido: true),
        ]);
    final pan = await productos.guardarProducto(
        nombre: 'Pan',
        precio: 600,
        proveedores: [
          ProveedorDeProducto(proveedorId: postobon, precioCompra: 400, preferido: true),
        ]);
    final agua = await productos.guardarProducto(nombre: 'Agua', precio: 1000);
    final inv = InventarioRepository(db, reloj: () => DateTime(2026, 10, 7, 8));
    await inv.activarControl(coca, cantidad: 2, minimo: 6, por: ana);
    await inv.cambiarPedirHasta(coca, 24);
    await inv.activarControl(pan, cantidad: 1, minimo: 5, por: ana);
    await inv.activarControl(agua, cantidad: 0, minimo: 0, por: ana);
    await tester.pumpWidget(appDePrueba(container,
        inicio: const Scaffold(body: InventarioScreen())));
    await tester.pumpAndSettle();
    return (postobon, coca, pan, agua);
  }

  testWidgets('muestra sugeridos, precios y total, y se puede editar',
      (tester) async {
    final (postobon, coca, pan, _) = await preparar(tester);

    await tester.tap(find.byKey(Key('ver_pedido_$postobon')));
    await tester.pumpAndSettle();

    expect(find.text('Pedido sugerido · Postobón'), findsOneWidget);
    expect(find.text('quedan 2 · mín. 6 · hasta 24'), findsOneWidget);
    expect(find.text('quedan 1 · mín. 5'), findsOneWidget);
    expect(
        tester.widget<Text>(find.byKey(Key('cantidad_pedido_$coca'))).data, '22');
    expect(
        tester.widget<Text>(find.byKey(Key('cantidad_pedido_$pan'))).data, '9');
    expect(find.text(r'$900 c/u'), findsOneWidget);
    expect(find.text(r'Total estimado $23.400'), findsOneWidget);

    await tester.tap(find.byKey(Key('restar_pedido_$coca')));
    await tester.tap(find.byKey(Key('sumar_pedido_$pan')));
    await tester.pump();
    expect(find.text(r'Total estimado $22.900'), findsOneWidget);
  });

  testWidgets('Recibir este pedido abre Recibir lleno y suma existencias',
      (tester) async {
    final (postobon, coca, pan, _) = await preparar(tester);
    await tester.tap(find.byKey(Key('ver_pedido_$postobon')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('boton_recibir_pedido')));
    await tester.pumpAndSettle();
    expect(find.byType(RecibirMercanciaScreen), findsOneWidget);
    expect(find.text(r'Total $23.400'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('boton_guardar_recibir')));
    await tester.tap(find.byKey(const Key('boton_guardar_recibir')));
    await tester.pumpAndSettle();

    expect(find.byType(InventarioScreen), findsOneWidget);
    expect(find.text(r'Mercancía recibida · $23.400'), findsOneWidget);
    final inv = InventarioRepository(db);
    expect(await inv.existencias(coca), 24);
    expect(await inv.existencias(pan), 10);
  });

  testWidgets('sin proveedor: sin precio y Recibir sin proveedor elegido',
      (tester) async {
    final (_, _, _, agua) = await preparar(tester);

    await tester.scrollUntilVisible(find.byKey(const Key('ver_pedido_sin')), 200);
    await tester.tap(find.byKey(const Key('ver_pedido_sin')));
    await tester.pumpAndSettle();

    expect(find.text('Pedido sugerido · Sin proveedor'), findsOneWidget);
    expect(find.text('Sin precio'), findsOneWidget);
    expect(find.text(r'Total estimado $0'), findsOneWidget);

    await tester.tap(find.byKey(Key('restar_pedido_$agua')));
    await tester.pump();
    expect(habilitado(tester, 'boton_recibir_pedido'), isFalse);

    await tester.tap(find.byKey(Key('sumar_pedido_$agua')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('boton_recibir_pedido')));
    await tester.pumpAndSettle();
    expect(find.byType(RecibirMercanciaScreen), findsOneWidget);
    expect(habilitado(tester, 'boton_guardar_recibir'), isFalse);
  });
}
```

- [ ] **Step 2: Correr y ver que falla**

Run: `flutter test test/screens/inventario/pedido_sugerido_screen_test.dart`
Expected: FAIL (`pedido_sugerido_screen.dart` no existe).

- [ ] **Step 3: Implementar la pantalla**

`lib/screens/inventario/pedido_sugerido_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../providers/inventario_providers.dart';
import '../../repositories/inventario_repository.dart';
import '../../ui/boton_principal.dart';
import '../../ui/colores_app.dart';
import '../../util/formato_moneda.dart';
import 'inventario_screen.dart';
import 'recibir_mercancia_screen.dart';

/// Cuánto pedirle a [proveedor] (null = "Sin proveedor"). Las cantidades se
/// editan en pantalla y no se guardan. Si se recibe, se cierra con el total.
class PedidoSugeridoScreen extends ConsumerStatefulWidget {
  const PedidoSugeridoScreen({super.key, required this.proveedor});

  final Proveedor? proveedor;

  @override
  ConsumerState<PedidoSugeridoScreen> createState() =>
      _PedidoSugeridoScreenState();
}

class _PedidoSugeridoScreenState extends ConsumerState<PedidoSugeridoScreen> {
  /// Cantidades cambiadas por id de producto.
  final Map<int, int> _cantidades = {};

  int _cantidad(LineaSugerida l) => _cantidades[l.producto.id] ?? l.sugerido;

  Future<void> _recibir(List<LineaSugerida> lineas) async {
    final total = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (_) => RecibirMercanciaScreen(
          proveedorInicial: widget.proveedor,
          lineasIniciales: [
            for (final l in lineas)
              if (_cantidad(l) > 0)
                LineaInicial(
                    producto: l.producto,
                    cantidad: _cantidad(l),
                    precio: l.precio),
          ],
        ),
      ),
    );
    if (total != null && mounted) Navigator.of(context).pop(total);
  }

  @override
  Widget build(BuildContext context) {
    final lineas = ref
            .watch(sugerenciaPedidoProvider(widget.proveedor?.id))
            .valueOrNull ??
        const <LineaSugerida>[];
    final total = lineas.fold<int>(
        0, (s, l) => s + (l.precio == null ? 0 : _cantidad(l) * l.precio!));
    final hayAlgo = lineas.any((l) => _cantidad(l) > 0);
    const gris = TextStyle(color: ColoresApp.textoSecundario);

    return Scaffold(
      appBar: AppBar(
        title: Text(
            'Pedido sugerido · ${widget.proveedor?.nombre ?? 'Sin proveedor'}'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final l in lineas)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.producto.nombre,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          Text(
                            'quedan ${numeroConSigno(l.existencias)} · '
                            'mín. ${l.producto.minimo}'
                            '${l.producto.pedirHasta == null ? '' : ' · hasta ${l.producto.pedirHasta}'}',
                            style: gris,
                          ),
                          Text(
                            l.precio == null
                                ? 'Sin precio'
                                : '${formatoMoneda(l.precio!)} c/u',
                            key: Key('precio_pedido_${l.producto.id}'),
                            style: gris,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      key: Key('restar_pedido_${l.producto.id}'),
                      tooltip: 'Restar',
                      icon: const Icon(Icons.remove_rounded),
                      onPressed: _cantidad(l) > 0
                          ? () => setState(() =>
                              _cantidades[l.producto.id] = _cantidad(l) - 1)
                          : null,
                    ),
                    Text('${_cantidad(l)}',
                        key: Key('cantidad_pedido_${l.producto.id}'),
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    IconButton(
                      key: Key('sumar_pedido_${l.producto.id}'),
                      tooltip: 'Sumar',
                      icon: const Icon(Icons.add_rounded),
                      onPressed: () => setState(
                          () => _cantidades[l.producto.id] = _cantidad(l) + 1),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          Text('Total estimado ${formatoMoneda(total)}',
              key: const Key('total_pedido'),
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 24),
          BotonPrincipal(
            key: const Key('boton_recibir_pedido'),
            texto: 'Recibir este pedido',
            onPressed: hayAlgo ? () => _recibir(lineas) : null,
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Botón en Inventario y helper**

En `lib/screens/inventario/inventario_screen.dart`:

- reemplazar `textoExistencias` por:

```dart
/// "5" o "−2" (signo menos tipográfico).
String numeroConSigno(int n) => n < 0 ? '−${-n}' : '$n';

/// "12 u" o "−2 u".
String textoExistencias(int existencias) => '${numeroConSigno(existencias)} u';
```

- en el subtítulo de "Por pedir", reemplazar `textoExistencias(p.existencias).replaceAll(' u', '')` por `numeroConSigno(p.existencias)`.
- import `pedido_sugerido_screen.dart`.
- en el estado, agregar:

```dart
  Future<void> _verPedido(Proveedor? proveedor) async {
    final total = await Navigator.of(context).push<int>(
      MaterialPageRoute(
          builder: (_) => PedidoSugeridoScreen(proveedor: proveedor)),
    );
    if (total != null && mounted) {
      avisar(context, 'Mercancía recibida · ${formatoMoneda(total)}');
    }
  }
```

  (import `../../data/database.dart` para `Proveedor`).
- en cada grupo de "Por pedir", reemplazar el `Padding` del encabezado por una fila con el texto y el botón:

```dart
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 0, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${g.proveedor?.nombre ?? 'Sin proveedor'} · '
                        '${plural(g.productos.length, 'producto', 'productos')}',
                        key: Key('grupo_por_pedir_${g.proveedor?.id ?? 'sin'}'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    TextButton(
                      key: Key('ver_pedido_${g.proveedor?.id ?? 'sin'}'),
                      onPressed: () => _verPedido(g.proveedor),
                      child: const Text('Ver pedido sugerido'),
                    ),
                  ],
                ),
              ),
```

- [ ] **Step 5: Correr y ver que pasa**

Run: `flutter test test/screens/inventario` y `flutter analyze lib test`
Expected: PASS y "No issues found!"

- [ ] **Step 6: Commit**

```bash
git add lib/screens/inventario test/screens/inventario/pedido_sugerido_screen_test.dart
git commit -m "Add the suggested order screen per supplier with receive-from-order"
```

---

### Task 6: Verificación final

**Files:**
- Modify: `docs/superpowers/specs/2026-10-07-vecitienda-pedido-sugerido-design.md` (`**Estado:**`)
- Modify: `docs/hoja-de-ruta.md`

- [ ] **Step 1: Análisis y suite completa**

Run: `flutter analyze` y `flutter test` (en primer plano)
Expected: "No issues found!" y todas las pruebas pasan.

- [ ] **Step 2: Compilar**

Run: `flutter build apk --debug`
Expected: "Built build\app\outputs\flutter-apk\app-debug.apk".

- [ ] **Step 3: Documentación**

- Especificación: `**Estado:** Diseño aprobado, pendiente de plan` → `**Estado:** Implementado (falta el recorrido manual en un celular real)`.
- `docs/hoja-de-ruta.md`: en "Hecho" agregar "- Fase 4C — pedido sugerido por proveedor (sin envío ni historial, por decisión del usuario)."; en "En curso" dejar "- Nada; la Fase 4 quedó completa."; en "Pendiente de verificar" cambiar " e inventario (4B)." por ", inventario (4B) y pedido sugerido (4C).".

- [ ] **Step 4: Commit**

```bash
git add docs/superpowers/specs/2026-10-07-vecitienda-pedido-sugerido-design.md docs/hoja-de-ruta.md
git commit -m "Mark Fase 4C as implemented"
```
