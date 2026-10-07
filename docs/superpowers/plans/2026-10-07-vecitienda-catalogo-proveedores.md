# Fase 4A — Catálogo, proveedores y nombre de la tienda Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** La tienda tiene nombre visible; el administrador registra proveedores y, por producto, a quién le compra y a qué precio (con un preferido); cada venta guarda su costo y Reportes muestra la ganancia en productos.

**Architecture:** Esquema v5: tablas `proveedores` y `productos_proveedores` (única por par, un preferido por producto garantizado por el repositorio), `lineas_venta.costoUnitario` y `configuracion_tienda.nombreTienda`. `ProveedorRepository` nuevo; `ProductoRepository.guardarProducto` guarda producto y proveedores en una transacción; `registrarVenta` copia el costo del preferido a cada línea; `ReporteRepository` suma ganancias. Pantallas: Proveedores, Producto (reemplaza el formulario y el diálogo actuales), nombre de la tienda en login, Inicio y Ajustes.

**Tech Stack:** Flutter 3.47 / Dart ^3.13, flutter_riverpod 2.6, Drift 2.34 (+ build_runner), sqlite3 3.5. Sin dependencias nuevas.

**Spec:** `docs/superpowers/specs/2026-10-07-vecitienda-catalogo-proveedores-design.md`

## Global Constraints

- `schemaVersion = 5`; la migración solo agrega. Ojo: `lineas_venta` (creada en `desde < 4`) y `configuracion_tienda` (creada en `desde < 2`) ya nacen con las columnas nuevas cuando la base viene de antes; el bloque `desde < 5` solo hace `addColumn` si la tabla ya existía (`desde >= 4` y `desde >= 2`).
- Después de cada cambio en `lib/data/database.dart`: `dart run build_runner build --delete-conflicting-outputs`.
- Producto–proveedor: sin repetir proveedor, `precioCompra > 0`, exactamente un preferido si hay alguno; un proveedor inactivo no se puede agregar nuevo a un producto (sí se conserva si ya estaba).
- Costo de un producto = `precioCompra` de su preferido; sin proveedores, null. Las líneas de monto suelto guardan `costoUnitario` null.
- Ganancia: por producto Σ (precioUnitario − costoUnitario) × cantidad de líneas con costo (null si ninguna); `gananciaProductos` igual sobre todas; `vendidoSinCosto` = Σ subtotal de líneas sin costo. Nada anulado cuenta.
- Nombre de la tienda: 1–40 caracteres tras recortar espacios; error vacío "Escribe el nombre de tu tienda", largo "Máximo 40 caracteres".
- Textos exactos: "Nombre de la tienda", "¿Cómo se llama tu tienda?", "Nombre guardado", "Tienda", "Proveedores", "A quién le compras", "Aún no tienes proveedores", "Agrega a quién le compras para armar tus pedidos", "Surte N productos" (`plural`), "Proveedor guardado", "Teléfono", "Notas", "Productos que surte", "Agregar proveedor", "Precio de compra", "Nuevo proveedor", "Nuevo producto", "Editar producto", "Precio de venta", "Costo $2.500 · Ganas $1.000 por unidad (29 %)", "Este producto se vende con pérdida", "Sin costo: agrega un proveedor para ver la ganancia", "$3.500 · gana $1.000", "$3.500 · sin costo", "Ganancia en productos: $X", "· gana $X", "$Y vendidos sin costo registrado", "Producto guardado", "Escribe un nombre", "Escribe un precio válido".
- Productos, Proveedores y el cambio de nombre de la tienda: solo administrador (Ajustes).
- Trabajar en una rama nueva `fase4a-catalogo-proveedores` desde `master`.

## Review Focus

1. Restaurar un respaldo v1, v2 o v3 → la migración a v5 no falla por columnas duplicadas (pruebas en Task 1).
2. Guardar el nombre de la tienda con un QR ya cargado (o al revés) → no se borra el otro dato (prueba en Task 2).
3. Administrador sin nombre de tienda → la hoja no se cierra con atrás ni tocando afuera; un vendedor no la ve (pruebas en Task 3).
4. Quitar el proveedor preferido en el formulario → otro queda preferido y guardar funciona (prueba en Task 8).
5. Producto que ya tenía un proveedor que luego se desactivó → se puede seguir editando y guardando (prueba en Task 5).

---

### Task 1: Esquema v5

**Files:**
- Modify: `lib/data/database.dart`
- Regenerate: `lib/data/database.g.dart`
- Create: `test/support/esquema_v4.dart`
- Modify: `test/data/migracion_test.dart`
- Modify: `test/respaldo/copia_base_datos_test.dart` (`versionMaxima: 4` → `5`)

**Interfaces:**
- Produces: `db.proveedores` (`Proveedor { id, nombre, telefono?, notas?, activo }`, `ProveedoresCompanion.insert({required String nombre, Value<String?> telefono, Value<String?> notas, Value<bool> activo})`); `db.productosProveedores` (`ProductoProveedor { id, productoId, proveedorId, precioCompra, preferido }`, `ProductosProveedoresCompanion.insert({required int productoId, required int proveedorId, required int precioCompra, Value<bool> preferido})`); `LineaVenta.costoUnitario` (`int?`); `ConfiguracionTiendaFila.nombreTienda` (`String?`).

- [ ] **Step 1: Crear la rama**

```bash
git checkout master
git checkout -b fase4a-catalogo-proveedores
```

- [ ] **Step 2: Fixture v4**

`test/support/esquema_v4.dart`:

```dart
import 'package:sqlite3/sqlite3.dart';

import 'esquema_v3.dart';

/// Crea en [ruta] una base con el esquema v4 de la app (3C, antes de la 4A):
/// el de v3 más `lineas_venta`, con una línea para la venta existente.
void crearBaseV4(String ruta) {
  crearBaseV3(ruta);
  sqlite3.open(ruta)
    ..execute('''
      CREATE TABLE lineas_venta (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        venta_id INTEGER NOT NULL REFERENCES ventas (id),
        producto_id INTEGER NULL REFERENCES productos (id),
        descripcion TEXT NOT NULL, precio_unitario INTEGER NOT NULL,
        cantidad INTEGER NOT NULL);
      INSERT INTO lineas_venta (venta_id, descripcion, precio_unitario, cantidad)
        VALUES (1, '\$5.000', 5000, 1);
    ''')
    ..userVersion = 4
    ..close();
}
```

- [ ] **Step 3: Escribir las pruebas que fallan**

En `test/data/migracion_test.dart`: agregar `import '../support/esquema_v4.dart';`, cambiar `expect(db.schemaVersion, 4);` por `expect(db.schemaVersion, 5);` y agregar dentro de `main()`:

```dart
  test('una base v4 abre en v5 sin costos, proveedores ni nombre de tienda',
      () async {
    final archivo = File('${carpeta.path}/v4.sqlite');
    crearBaseV4(archivo.path);

    final db = AppDatabase(NativeDatabase(archivo));
    addTearDown(db.close);

    expect((await db.select(db.lineasVenta).getSingle()).costoUnitario,
        isNull);
    expect(await db.select(db.proveedores).get(), isEmpty);
    expect(await db.select(db.productosProveedores).get(), isEmpty);
    expect(await db.select(db.configuracionTienda).get(), isEmpty);
  });

  for (final (version, crear) in [
    (1, crearBaseV1),
    (2, crearBaseV2),
    (3, crearBaseV3),
  ]) {
    test('una base v$version abre en v5 y acepta líneas con costo y nombre',
        () async {
      final archivo = File('${carpeta.path}/vieja$version.sqlite');
      crear(archivo.path);

      final db = AppDatabase(NativeDatabase(archivo));
      addTearDown(db.close);

      final venta = (await db.select(db.ventas).getSingle()).id;
      await db.into(db.lineasVenta).insert(LineasVentaCompanion.insert(
            ventaId: venta,
            descripcion: 'Arepa',
            precioUnitario: 3500,
            cantidad: 1,
            costoUnitario: const Value(2500),
          ));
      await db.into(db.configuracionTienda).insert(
          const ConfiguracionTiendaCompanion(
              id: Value(1), nombreTienda: Value('La Esquina')));
      expect((await db.select(db.lineasVenta).getSingle()).costoUnitario,
          2500);
      expect((await db.select(db.configuracionTienda).getSingle()).nombreTienda,
          'La Esquina');
    });
  }

  test('producto y proveedor no se pueden repetir', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final producto = await db
        .into(db.productos)
        .insert(ProductosCompanion.insert(nombre: 'Arepa', precio: 3500));
    final proveedor = await db
        .into(db.proveedores)
        .insert(ProveedoresCompanion.insert(nombre: 'Postobón'));
    await db.into(db.productosProveedores).insert(
        ProductosProveedoresCompanion.insert(
            productoId: producto, proveedorId: proveedor, precioCompra: 2500));

    await expectLater(
        db.into(db.productosProveedores).insert(
            ProductosProveedoresCompanion.insert(
                productoId: producto,
                proveedorId: proveedor,
                precioCompra: 2600)),
        throwsA(anything));
    expect((await db.select(db.proveedores).getSingle()).activo, isTrue);
  });
```

En `test/respaldo/copia_base_datos_test.dart` cambiar `versionMaxima: 4` por `versionMaxima: 5`.

- [ ] **Step 4: Correr y ver que falla**

Run: `flutter test test/data/migracion_test.dart`
Expected: FAIL de compilación (`proveedores`, `costoUnitario`, `nombreTienda` no existen).

- [ ] **Step 5: Implementar**

En `lib/data/database.dart`:

- En `LineasVenta`, después de `cantidad`:

```dart

  /// Costo de una unidad al vender (precio del proveedor preferido); null en
  /// montos sueltos, productos sin proveedor o ventas anteriores a la 4A.
  IntColumn get costoUnitario => integer().nullable()();
```

- En `ConfiguracionTienda`, después de `imagenQr`:

```dart

  /// Nombre de la tienda; null mientras no se ha configurado.
  TextColumn get nombreTienda => text().nullable()();
```

- Después de la clase `Productos`:

```dart
/// A quién se le compran los productos.
@DataClassName('Proveedor')
class Proveedores extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get nombre => text()();
  TextColumn get telefono => text().nullable()();
  TextColumn get notas => text().nullable()();
  BoolColumn get activo => boolean().withDefault(const Constant(true))();
}

/// Un proveedor de un producto y su precio de compra. Un producto con
/// proveedores tiene exactamente un preferido (lo garantiza el repositorio).
@DataClassName('ProductoProveedor')
class ProductosProveedores extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get productoId => integer().references(Productos, #id)();
  IntColumn get proveedorId => integer().references(Proveedores, #id)();
  IntColumn get precioCompra => integer()();
  BoolColumn get preferido => boolean().withDefault(const Constant(false))();

  @override
  List<Set<Column>> get uniqueKeys => [
        {productoId, proveedorId},
      ];
}
```

- En `tables:` agregar `Proveedores,` y `ProductosProveedores,` después de `Productos,`.
- `int get schemaVersion => 5;`
- En `onUpgrade`, después del bloque `if (desde < 4) {...}`:

```dart
          if (desde < 5) {
            await m.createTable(proveedores);
            await m.createTable(productosProveedores);
            // Si la tabla se creó en esta misma migración ya trae la columna.
            if (desde >= 4) {
              await m.addColumn(lineasVenta, lineasVenta.costoUnitario);
            }
            if (desde >= 2) {
              await m.addColumn(
                  configuracionTienda, configuracionTienda.nombreTienda);
            }
          }
```

Run: `dart run build_runner build --delete-conflicting-outputs`

- [ ] **Step 6: Correr y ver que pasa**

Run: `flutter test test/data test/respaldo`
Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add lib/data test/support/esquema_v4.dart test/data/migracion_test.dart test/respaldo/copia_base_datos_test.dart
git commit -m "Add suppliers, product suppliers, line cost and store name (schema v5)"
```

---

### Task 2: Nombre de la tienda — datos y primera configuración

**Files:**
- Modify: `lib/repositories/configuracion_repository.dart`
- Modify: `lib/providers/configuracion_providers.dart`
- Modify: `lib/screens/login/crear_admin_inicial_screen.dart`
- Modify: `test/repositories/configuracion_repository_test.dart`
- Modify: `test/screens/login/crear_admin_inicial_screen_test.dart`

**Interfaces:**
- Consumes: `ConfiguracionTiendaFila.nombreTienda` (Task 1).
- Produces: `String? errorNombreTienda(String nombre)` (top-level en `configuracion_repository.dart`); `ConfiguracionRepository.nombreTienda()`, `observarNombreTienda()`, `guardarNombreTienda(String)` (lanza `ArgumentError` si `errorNombreTienda` no es null); `nombreTiendaProvider` (`StreamProvider<String?>`); campo `campo_nombre_tienda` en la primera configuración.

- [ ] **Step 1: Escribir las pruebas que fallan**

En `test/repositories/configuracion_repository_test.dart` agregar dentro de `main()` (usa el `db` y el `repo` que ya define el archivo):

```dart
  test('guarda el nombre de la tienda recortado y lo lee', () async {
    await repo.guardarNombreTienda('  La Esquina  ');
    expect(await repo.nombreTienda(), 'La Esquina');
  });

  test('sin guardar no hay nombre de tienda', () async {
    expect(await repo.nombreTienda(), isNull);
  });

  test('un nombre vacío, de solo espacios o muy largo se rechaza', () async {
    await expectLater(repo.guardarNombreTienda(''), throwsArgumentError);
    await expectLater(repo.guardarNombreTienda('   '), throwsArgumentError);
    await expectLater(
        repo.guardarNombreTienda('x' * 41), throwsArgumentError);
    expect(await repo.nombreTienda(), isNull);
    expect(errorNombreTienda(''), 'Escribe el nombre de tu tienda');
    expect(errorNombreTienda('x' * 41), 'Máximo 40 caracteres');
    expect(errorNombreTienda('x' * 40), isNull);
  });

  test('el nombre de la tienda y el QR no se borran entre sí', () async {
    final qr = Uint8List.fromList([1, 2, 3]);
    await repo.guardarImagenQr(qr);
    await repo.guardarNombreTienda('La Esquina');
    expect(await repo.imagenQr(), qr);

    await repo.guardarImagenQr(Uint8List.fromList([4]));
    expect(await repo.nombreTienda(), 'La Esquina');
  });
```

(Agregar `import 'dart:typed_data';` si el archivo no lo tiene.)

En `test/screens/login/crear_admin_inicial_screen_test.dart`:
- en la prueba existente, antes de `campo_nombre_admin`:

```dart
    await tester.enterText(
        find.byKey(const Key('campo_nombre_tienda')), 'La Esquina');
```

  y al final: `expect(await ConfiguracionRepository(db).nombreTienda(), 'La Esquina');` (import `package:app_ventas/repositories/configuracion_repository.dart`).
- nueva prueba:

```dart
  testWidgets('sin nombre de tienda muestra el error y no crea nada',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: CrearAdminInicialScreen()),
    ));

    await tester.enterText(find.byKey(const Key('campo_nombre_admin')), 'Ana');
    await tester.enterText(find.byKey(const Key('campo_pin_admin')), '1234');
    await tester.tap(find.byKey(const Key('boton_crear_admin')));
    await tester.pumpAndSettle();

    expect(find.text('Escribe el nombre de tu tienda'), findsOneWidget);
    expect(await db.select(db.usuarios).get(), isEmpty);
    expect(container.read(sesionProvider).haySesion, isFalse);
  });
```

- [ ] **Step 2: Correr y ver que falla**

Run: `flutter test test/repositories/configuracion_repository_test.dart test/screens/login/crear_admin_inicial_screen_test.dart`
Expected: FAIL (`guardarNombreTienda`, `errorNombreTienda`, `campo_nombre_tienda` no existen).

- [ ] **Step 3: Implementar el repositorio y el provider**

En `lib/repositories/configuracion_repository.dart`:
- cambiar el doc de la clase a `/// Configuración de la tienda (una sola fila, id 1): nombre y QR de cobro.`
- antes de la clase:

```dart
/// Mensaje de error para un nombre de tienda, o null si es válido.
String? errorNombreTienda(String nombre) {
  final limpio = nombre.trim();
  if (limpio.isEmpty) return 'Escribe el nombre de tu tienda';
  if (limpio.length > 40) return 'Máximo 40 caracteres';
  return null;
}
```

- dentro de la clase, al final:

```dart
  Future<String?> nombreTienda() async =>
      (await _fila.getSingleOrNull())?.nombreTienda;

  Stream<String?> observarNombreTienda() =>
      _fila.watchSingleOrNull().map((fila) => fila?.nombreTienda);

  /// Guarda [nombre] sin espacios sobrantes; no toca el QR.
  Future<void> guardarNombreTienda(String nombre) {
    final error = errorNombreTienda(nombre);
    if (error != null) throw ArgumentError(error);
    return _db.into(_db.configuracionTienda).insertOnConflictUpdate(
          ConfiguracionTiendaCompanion(
              id: const Value(_id), nombreTienda: Value(nombre.trim())),
        );
  }
```

En `lib/providers/configuracion_providers.dart`, al final:

```dart
/// Nombre de la tienda; null si aún no se configuró.
final nombreTiendaProvider = StreamProvider<String?>(
  (ref) => ref.watch(configuracionRepositoryProvider).observarNombreTienda(),
);
```

- [ ] **Step 4: Pedirlo en la primera configuración**

En `lib/screens/login/crear_admin_inicial_screen.dart`:
- import `import '../../providers/configuracion_providers.dart';` y `import '../../repositories/configuracion_repository.dart';`
- controlador nuevo `final _tiendaController = TextEditingController();` (y su `dispose`).
- al inicio de `_crear`:

```dart
    final tienda = _tiendaController.text;
    final errorTienda = errorNombreTienda(tienda);
    if (errorTienda != null) {
      setState(() => _error = errorTienda);
      return;
    }
```

- justo antes de `final repo = ref.read(usuarioRepositoryProvider);`:

```dart
    await ref.read(configuracionRepositoryProvider).guardarNombreTienda(tienda);
```

- en el `ListView`, antes del campo `campo_nombre_admin`:

```dart
            TextField(
              key: const Key('campo_nombre_tienda'),
              controller: _tiendaController,
              decoration:
                  const InputDecoration(labelText: 'Nombre de la tienda'),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
```

- [ ] **Step 5: Correr y ver que pasa**

Run: `flutter test test/repositories test/screens/login`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add lib/repositories/configuracion_repository.dart lib/providers/configuracion_providers.dart lib/screens/login/crear_admin_inicial_screen.dart test/repositories/configuracion_repository_test.dart test/screens/login/crear_admin_inicial_screen_test.dart
git commit -m "Store the shop name and ask for it when setting up the app"
```

---

### Task 3: Nombre de la tienda visible y editable

**Files:**
- Create: `lib/widgets/nombre_tienda.dart`
- Create: `lib/screens/configuracion/hoja_nombre_tienda.dart`
- Modify: `lib/ui/hoja_inferior.dart` (parámetro `descartable`)
- Modify: `lib/screens/login/seleccionar_usuario_screen.dart`
- Modify: `lib/screens/login/ingresar_pin_screen.dart`
- Modify: `lib/screens/home/home_screen.dart`
- Modify: `lib/screens/configuracion/ajustes_screen.dart`
- Test: `test/screens/configuracion/nombre_tienda_test.dart`
- Modify: `test/screens/home/home_screen_test.dart` (setUp con nombre)

**Interfaces:**
- Consumes: `nombreTiendaProvider`, `ConfiguracionRepository.guardarNombreTienda`, `errorNombreTienda` (Task 2).
- Produces: `NombreTienda({Key? key, TextStyle? estilo})` (texto con llave `nombre_tienda`, nada si null); `Future<void> mostrarHojaNombreTienda(BuildContext context, {bool obligatoria = false})`; `mostrarHojaInferior(..., {bool descartable = true})`; fila `menu_nombre_tienda` en Ajustes; llaves `campo_nombre_tienda_hoja`, `boton_guardar_nombre_tienda`.

- [ ] **Step 1: Escribir las pruebas que fallan**

`test/screens/configuracion/nombre_tienda_test.dart`:

```dart
import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/repositories/configuracion_repository.dart';
import 'package:app_ventas/screens/configuracion/ajustes_screen.dart';
import 'package:app_ventas/screens/home/home_screen.dart';
import 'package:app_ventas/screens/login/ingresar_pin_screen.dart';
import 'package:app_ventas/screens/login/seleccionar_usuario_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/montaje.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> conNombre() =>
      ConfiguracionRepository(db).guardarNombreTienda('La Esquina');

  Future<void> montar(WidgetTester tester, Widget inicio,
      {String rol = 'admin'}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final container = await containerConSesion(db, rol: rol);
    addTearDown(container.dispose);
    await tester.pumpWidget(appDePrueba(container, inicio: inicio));
    await tester.pumpAndSettle();
  }

  testWidgets('el nombre se ve al elegir usuario', (tester) async {
    await conNombre();
    await montar(tester, const SeleccionarUsuarioScreen());
    expect(find.text('La Esquina'), findsOneWidget);
  });

  testWidgets('el nombre se ve al ingresar el PIN', (tester) async {
    await conNombre();
    const usuario = Usuario(id: 99, nombre: 'Beto', rol: 'vendedor', pinHash: 'x');
    await montar(tester, const IngresarPinScreen(usuario: usuario));
    expect(find.text('La Esquina'), findsOneWidget);
  });

  testWidgets('el nombre se ve en el encabezado de Inicio', (tester) async {
    await conNombre();
    await montar(tester, const HomeScreen());
    expect(
        find.descendant(
            of: find.byType(AppBar), matching: find.text('La Esquina')),
        findsOneWidget);
  });

  testWidgets('en Ajustes el administrador cambia el nombre', (tester) async {
    await conNombre();
    await montar(tester, const Scaffold(body: AjustesScreen()));

    await tester.tap(find.byKey(const Key('menu_nombre_tienda')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('campo_nombre_tienda_hoja')), 'Donde Rosa');
    await tester.tap(find.byKey(const Key('boton_guardar_nombre_tienda')));
    await tester.pumpAndSettle();

    expect(await ConfiguracionRepository(db).nombreTienda(), 'Donde Rosa');
    expect(find.text('Nombre guardado'), findsOneWidget);
    expect(find.text('Donde Rosa'), findsOneWidget);
  });

  testWidgets('un nombre vacío en la hoja muestra el error', (tester) async {
    await conNombre();
    await montar(tester, const Scaffold(body: AjustesScreen()));

    await tester.tap(find.byKey(const Key('menu_nombre_tienda')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('campo_nombre_tienda_hoja')), '  ');
    await tester.tap(find.byKey(const Key('boton_guardar_nombre_tienda')));
    await tester.pumpAndSettle();

    expect(find.text('Escribe el nombre de tu tienda'), findsOneWidget);
    expect(await ConfiguracionRepository(db).nombreTienda(), 'La Esquina');
  });

  testWidgets(
      'al administrador sin nombre se le pide y no puede cerrar la hoja',
      (tester) async {
    await montar(tester, const HomeScreen());

    expect(find.text('¿Cómo se llama tu tienda?'), findsOneWidget);
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    expect(find.text('¿Cómo se llama tu tienda?'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('¿Cómo se llama tu tienda?'), findsOneWidget);

    await tester.enterText(
        find.byKey(const Key('campo_nombre_tienda_hoja')), 'La Esquina');
    await tester.tap(find.byKey(const Key('boton_guardar_nombre_tienda')));
    await tester.pumpAndSettle();

    expect(find.text('¿Cómo se llama tu tienda?'), findsNothing);
    expect(await ConfiguracionRepository(db).nombreTienda(), 'La Esquina');
  });

  testWidgets('al vendedor sin nombre no se le pide', (tester) async {
    await montar(tester, const HomeScreen(), rol: 'vendedor');
    expect(find.text('¿Cómo se llama tu tienda?'), findsNothing);
  });
}
```

En `test/screens/home/home_screen_test.dart`, cambiar el `setUp` para que la tienda ya tenga nombre (si no, la hoja obligatoria tapa las pestañas):

```dart
  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await ConfiguracionRepository(db).guardarNombreTienda('La Esquina');
  });
```

(import `package:app_ventas/repositories/configuracion_repository.dart`).

- [ ] **Step 2: Correr y ver que falla**

Run: `flutter test test/screens/configuracion/nombre_tienda_test.dart`
Expected: FAIL (`menu_nombre_tienda`, la hoja y el nombre en pantalla no existen).

- [ ] **Step 3: Hoja descartable o no**

En `lib/ui/hoja_inferior.dart`, agregar el parámetro `bool descartable = true,` a `mostrarHojaInferior` (doc: `/// Con [descartable] en false no se cierra tocando afuera ni arrastrando.`) y pasar a `showModalBottomSheet`:

```dart
    isDismissible: descartable,
    enableDrag: descartable,
```

- [ ] **Step 4: Widget y hoja**

`lib/widgets/nombre_tienda.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/configuracion_providers.dart';

/// El nombre de la tienda en una línea; nada si aún no tiene nombre.
class NombreTienda extends ConsumerWidget {
  const NombreTienda({super.key, this.estilo});

  final TextStyle? estilo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nombre = ref.watch(nombreTiendaProvider).valueOrNull;
    if (nombre == null) return const SizedBox.shrink();
    return Text(
      nombre,
      key: const Key('nombre_tienda'),
      style: estilo,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
```

`lib/screens/configuracion/hoja_nombre_tienda.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/configuracion_providers.dart';
import '../../repositories/configuracion_repository.dart';
import '../../ui/avisos.dart';
import '../../ui/boton_principal.dart';
import '../../ui/hoja_inferior.dart';

/// Pide o cambia el nombre de la tienda. Con [obligatoria] no se puede
/// cerrar sin guardar.
Future<void> mostrarHojaNombreTienda(
  BuildContext context, {
  bool obligatoria = false,
}) async {
  final guardado = await mostrarHojaInferior<bool>(
    context,
    titulo: '¿Cómo se llama tu tienda?',
    descartable: !obligatoria,
    builder: (_) => _HojaNombreTienda(obligatoria: obligatoria),
  );
  if (guardado == true && context.mounted) avisar(context, 'Nombre guardado');
}

class _HojaNombreTienda extends ConsumerStatefulWidget {
  const _HojaNombreTienda({required this.obligatoria});

  final bool obligatoria;

  @override
  ConsumerState<_HojaNombreTienda> createState() => _HojaNombreTiendaState();
}

class _HojaNombreTiendaState extends ConsumerState<_HojaNombreTienda> {
  late final _controller = TextEditingController(
      text: ref.read(nombreTiendaProvider).valueOrNull ?? '');
  String? _error;
  bool _guardando = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_guardando) return;
    final error = errorNombreTienda(_controller.text);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() => _guardando = true);
    try {
      await ref
          .read(configuracionRepositoryProvider)
          .guardarNombreTienda(_controller.text);
      if (mounted) Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.obligatoria,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const Key('campo_nombre_tienda_hoja'),
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
                labelText: 'Nombre de la tienda', errorText: _error),
          ),
          const SizedBox(height: 16),
          BotonPrincipal(
            key: const Key('boton_guardar_nombre_tienda'),
            texto: 'Guardar',
            onPressed: _guardando ? null : _guardar,
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Mostrar el nombre y pedirlo**

- `seleccionar_usuario_screen.dart`: import `../../widgets/nombre_tienda.dart`; entre `const SizedBox(height: 32),` y `Text('¿Quién eres?', ...)`:

```dart
              const NombreTienda(
                estilo: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: ColoresApp.primario),
              ),
              const SizedBox(height: 4),
```

- `ingresar_pin_screen.dart`: import `../../widgets/nombre_tienda.dart`; como primer hijo de la `Column` (antes de `AvatarInicial(`):

```dart
                    const NombreTienda(
                      estilo: TextStyle(
                          color: ColoresApp.textoSecundario,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
```

- `home_screen.dart`:
  - imports `../../providers/configuracion_providers.dart`, `../../widgets/nombre_tienda.dart`, `../configuracion/hoja_nombre_tienda.dart`.
  - en el estado: `bool _pidioNombre = false;`
  - en `build`, después de `final usuario = sesion.usuarioActivo!;`:

```dart
    // Un administrador sin nombre de tienda debe ponerlo una vez.
    ref.listen<AsyncValue<String?>>(nombreTiendaProvider, (_, siguiente) {
      if (_pidioNombre ||
          !ref.read(sesionProvider).esAdmin ||
          !siguiente.hasValue ||
          siguiente.value != null) {
        return;
      }
      _pidioNombre = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) mostrarHojaNombreTienda(context, obligatoria: true);
      });
    }, fireImmediately: true);
```

  - en el título de Inicio, reemplazar

```dart
                  Flexible(
                    child: Text(
                      'Hola, ${usuario.nombre}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
```

  por

```dart
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hola, ${usuario.nombre}',
                          overflow: TextOverflow.ellipsis,
                        ),
                        const NombreTienda(
                          estilo: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
```

- `ajustes_screen.dart`: imports `../../providers/configuracion_providers.dart` y `hoja_nombre_tienda.dart`; como primer hijo de la `Column` de la tarjeta TIENDA (antes de `menu_productos`):

```dart
              ListTile(
                key: const Key('menu_nombre_tienda'),
                leading: const Icon(Icons.storefront_outlined),
                title: const Text('Tienda'),
                subtitle: Text(
                    ref.watch(nombreTiendaProvider).valueOrNull ?? 'Sin nombre'),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () => mostrarHojaNombreTienda(context),
              ),
              const Divider(height: 1),
```

- [ ] **Step 6: Correr y ver que pasa**

Run: `flutter test test/screens`
Expected: PASS (las pruebas de Inicio tienen nombre de tienda desde el `setUp`).

- [ ] **Step 7: Commit**

```bash
git add lib/widgets/nombre_tienda.dart lib/screens/configuracion/hoja_nombre_tienda.dart lib/ui/hoja_inferior.dart lib/screens/login lib/screens/home/home_screen.dart lib/screens/configuracion/ajustes_screen.dart test/screens/configuracion/nombre_tienda_test.dart test/screens/home/home_screen_test.dart
git commit -m "Show the shop name on sign-in, Inicio and Ajustes and ask admins who have none"
```

---

### Task 4: `ProveedorRepository`

**Files:**
- Create: `lib/repositories/proveedor_repository.dart`
- Create: `lib/providers/proveedores_providers.dart`
- Modify: `lib/providers/repository_providers.dart`
- Test: `test/repositories/proveedor_repository_test.dart`

**Interfaces:**
- Consumes: `db.proveedores`, `db.productosProveedores` (Task 1).
- Produces: `ProveedorRepository(AppDatabase)` con `Stream<List<Proveedor>> observarActivos()`, `observarInactivos()` (orden por nombre), `Future<List<Proveedor>> todos()`, `Future<int> crear({required String nombre, String? telefono, String? notas})`, `Future<void> actualizar(int id, {required String nombre, String? telefono, String? notas})`, `desactivar(int)`, `reactivar(int)`, `Future<Map<int, int>> cantidadProductos()`, `Future<List<({Producto producto, int precioCompra})>> productosDe(int proveedorId)`. Nombre vacío → `ArgumentError`; teléfono/notas vacíos se guardan null. Providers: `proveedorRepositoryProvider`, `proveedoresActivosProvider`, `proveedoresInactivosProvider`, `cantidadProductosPorProveedorProvider`, `productosDeProveedorProvider` (family por id).

- [ ] **Step 1: Escribir la prueba que falla**

`test/repositories/proveedor_repository_test.dart`:

```dart
import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/repositories/proveedor_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late ProveedorRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ProveedorRepository(db);
  });

  tearDown(() => db.close());

  Future<Proveedor> proveedor(int id) =>
      (db.select(db.proveedores)..where((p) => p.id.equals(id))).getSingle();

  test('crear recorta y guarda vacíos como null', () async {
    final id = await repo.crear(nombre: '  Postobón ', telefono: ' ', notas: '');
    final p = await proveedor(id);
    expect(p.nombre, 'Postobón');
    expect(p.telefono, isNull);
    expect(p.notas, isNull);
    expect(p.activo, isTrue);
  });

  test('un nombre vacío se rechaza', () async {
    await expectLater(repo.crear(nombre: '  '), throwsArgumentError);
    expect(await db.select(db.proveedores).get(), isEmpty);
  });

  test('actualizar cambia los datos', () async {
    final id = await repo.crear(nombre: 'Postobón');
    await repo.actualizar(id,
        nombre: 'Postobón S.A.', telefono: '3001234567', notas: 'Martes');
    final p = await proveedor(id);
    expect(p.nombre, 'Postobón S.A.');
    expect(p.telefono, '3001234567');
    expect(p.notas, 'Martes');
  });

  test('desactivar y reactivar mueven entre las listas', () async {
    final id = await repo.crear(nombre: 'Postobón');
    await repo.crear(nombre: 'Alpina');

    await repo.desactivar(id);
    expect((await repo.observarActivos().first).map((p) => p.nombre),
        ['Alpina']);
    expect((await repo.observarInactivos().first).single.id, id);

    await repo.reactivar(id);
    expect((await repo.observarActivos().first).map((p) => p.nombre),
        ['Alpina', 'Postobón']);
    expect(await repo.todos(), hasLength(2));
  });

  test('cuenta y lista los productos de cada proveedor', () async {
    final postobon = await repo.crear(nombre: 'Postobón');
    final alpina = await repo.crear(nombre: 'Alpina');
    final coca = await db
        .into(db.productos)
        .insert(ProductosCompanion.insert(nombre: 'Coca', precio: 1200));
    final avena = await db
        .into(db.productos)
        .insert(ProductosCompanion.insert(nombre: 'Avena', precio: 2000));
    await db.into(db.productosProveedores).insert(
        ProductosProveedoresCompanion.insert(
            productoId: coca, proveedorId: postobon, precioCompra: 900));
    await db.into(db.productosProveedores).insert(
        ProductosProveedoresCompanion.insert(
            productoId: avena, proveedorId: postobon, precioCompra: 1500));

    expect(await repo.cantidadProductos(), {postobon: 2});
    expect(await repo.cantidadProductos().then((m) => m[alpina]), isNull);
    final productos = await repo.productosDe(postobon);
    expect(productos.map((p) => (p.producto.nombre, p.precioCompra)),
        [('Avena', 1500), ('Coca', 900)]);
  });
}
```

- [ ] **Step 2: Correr y ver que falla**

Run: `flutter test test/repositories/proveedor_repository_test.dart`
Expected: FAIL (`proveedor_repository.dart` no existe).

- [ ] **Step 3: Implementar**

`lib/repositories/proveedor_repository.dart`:

```dart
import 'package:drift/drift.dart';

import '../data/database.dart';

String? _opcional(String? texto) {
  final limpio = texto?.trim() ?? '';
  return limpio.isEmpty ? null : limpio;
}

String _nombreValido(String nombre) {
  final limpio = nombre.trim();
  if (limpio.isEmpty) throw ArgumentError('Escribe un nombre');
  return limpio;
}

/// Proveedores de la tienda. No se borran: se desactivan.
class ProveedorRepository {
  ProveedorRepository(this._db);

  final AppDatabase _db;

  Stream<List<Proveedor>> observarActivos() => (_db.select(_db.proveedores)
        ..where((p) => p.activo.equals(true))
        ..orderBy([(p) => OrderingTerm.asc(p.nombre)]))
      .watch();

  Stream<List<Proveedor>> observarInactivos() => (_db.select(_db.proveedores)
        ..where((p) => p.activo.equals(false))
        ..orderBy([(p) => OrderingTerm.asc(p.nombre)]))
      .watch();

  Future<List<Proveedor>> todos() => _db.select(_db.proveedores).get();

  Future<int> crear({
    required String nombre,
    String? telefono,
    String? notas,
  }) {
    return _db.into(_db.proveedores).insert(ProveedoresCompanion.insert(
          nombre: _nombreValido(nombre),
          telefono: Value(_opcional(telefono)),
          notas: Value(_opcional(notas)),
        ));
  }

  Future<void> actualizar(
    int id, {
    required String nombre,
    String? telefono,
    String? notas,
  }) {
    return (_db.update(_db.proveedores)..where((p) => p.id.equals(id))).write(
      ProveedoresCompanion(
        nombre: Value(_nombreValido(nombre)),
        telefono: Value(_opcional(telefono)),
        notas: Value(_opcional(notas)),
      ),
    );
  }

  Future<void> desactivar(int id) =>
      (_db.update(_db.proveedores)..where((p) => p.id.equals(id)))
          .write(const ProveedoresCompanion(activo: Value(false)));

  Future<void> reactivar(int id) =>
      (_db.update(_db.proveedores)..where((p) => p.id.equals(id)))
          .write(const ProveedoresCompanion(activo: Value(true)));

  /// Proveedor → cuántos productos surte (solo los que surten alguno).
  Future<Map<int, int>> cantidadProductos() async {
    final filas = await _db.select(_db.productosProveedores).get();
    final conteo = <int, int>{};
    for (final f in filas) {
      conteo.update(f.proveedorId, (n) => n + 1, ifAbsent: () => 1);
    }
    return conteo;
  }

  /// Productos que surte [proveedorId], por nombre, con su precio de compra.
  Future<List<({Producto producto, int precioCompra})>> productosDe(
      int proveedorId) async {
    final filas = await (_db.select(_db.productosProveedores).join([
      innerJoin(_db.productos,
          _db.productos.id.equalsExp(_db.productosProveedores.productoId)),
    ])
          ..where(_db.productosProveedores.proveedorId.equals(proveedorId))
          ..orderBy([OrderingTerm.asc(_db.productos.nombre)]))
        .get();
    return [
      for (final f in filas)
        (
          producto: f.readTable(_db.productos),
          precioCompra: f.readTable(_db.productosProveedores).precioCompra,
        ),
    ];
  }
}
```

En `lib/providers/repository_providers.dart` agregar `import '../repositories/proveedor_repository.dart';` y:

```dart
final proveedorRepositoryProvider = Provider(
  (ref) => ProveedorRepository(ref.watch(databaseProvider)),
);
```

`lib/providers/proveedores_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import 'database_provider.dart';
import 'repository_providers.dart';

final proveedoresActivosProvider = StreamProvider<List<Proveedor>>(
  (ref) => ref.watch(proveedorRepositoryProvider).observarActivos(),
);

final proveedoresInactivosProvider = StreamProvider<List<Proveedor>>(
  (ref) => ref.watch(proveedorRepositoryProvider).observarInactivos(),
);

/// Emite con cada cambio en la base (mismo patrón que fiado_providers).
final _cambiosProveedoresProvider = StreamProvider<void>((ref) {
  return ref.watch(databaseProvider).tableUpdates().map((_) {});
});

final cantidadProductosPorProveedorProvider =
    FutureProvider<Map<int, int>>((ref) {
  ref.watch(_cambiosProveedoresProvider);
  return ref.watch(proveedorRepositoryProvider).cantidadProductos();
});

final productosDeProveedorProvider = FutureProvider.autoDispose
    .family<List<({Producto producto, int precioCompra})>, int>((ref, id) {
  ref.watch(_cambiosProveedoresProvider);
  return ref.watch(proveedorRepositoryProvider).productosDe(id);
});
```

- [ ] **Step 4: Correr y ver que pasa**

Run: `flutter test test/repositories/proveedor_repository_test.dart` y `flutter analyze lib/providers lib/repositories`
Expected: PASS y "No issues found!"

- [ ] **Step 5: Commit**

```bash
git add lib/repositories/proveedor_repository.dart lib/providers/proveedores_providers.dart lib/providers/repository_providers.dart test/repositories/proveedor_repository_test.dart
git commit -m "Add ProveedorRepository and supplier providers"
```

---

### Task 5: Producto con proveedores y costo

**Files:**
- Modify: `lib/repositories/producto_repository.dart`
- Modify: `lib/providers/productos_providers.dart`
- Test: `test/repositories/producto_proveedores_test.dart`

**Interfaces:**
- Consumes: `db.productosProveedores`, `db.proveedores` (Task 1).
- Produces: `class ProveedorDeProducto { const ProveedorDeProducto({required int proveedorId, required int precioCompra, required bool preferido}); }`; `Future<List<ProductoProveedor>> proveedoresDe(int productoId)` (orden por id); `Future<int?> costoDe(int productoId)`; `Future<Map<int, int>> costos()` (producto → costo, solo con preferido); `Future<int> guardarProducto({int? id, required String nombre, required int precio, List<ProveedorDeProducto> proveedores = const []})` (lanza `ArgumentError` y no cambia nada si: nombre vacío, precio ≤ 0, precio de compra ≤ 0, proveedor repetido, cantidad de preferidos ≠ 1 con proveedores, proveedor inactivo que el producto no tenía). Provider `costosProductosProvider` (`FutureProvider<Map<int, int>>`).

- [ ] **Step 1: Escribir la prueba que falla**

`test/repositories/producto_proveedores_test.dart`:

```dart
import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/repositories/producto_repository.dart';
import 'package:app_ventas/repositories/proveedor_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late ProductoRepository repo;
  late ProveedorRepository proveedores;
  late int postobon;
  late int alpina;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = ProductoRepository(db);
    proveedores = ProveedorRepository(db);
    postobon = await proveedores.crear(nombre: 'Postobón');
    alpina = await proveedores.crear(nombre: 'Alpina');
  });

  tearDown(() => db.close());

  ProveedorDeProducto de(int id, int precio, {bool preferido = false}) =>
      ProveedorDeProducto(
          proveedorId: id, precioCompra: precio, preferido: preferido);

  test('guarda un producto nuevo con sus proveedores y su costo', () async {
    final id = await repo.guardarProducto(
      nombre: 'Coca',
      precio: 1200,
      proveedores: [de(postobon, 900, preferido: true), de(alpina, 850)],
    );

    final lista = await repo.proveedoresDe(id);
    expect(lista.map((p) => (p.proveedorId, p.precioCompra, p.preferido)),
        [(postobon, 900, true), (alpina, 850, false)]);
    expect(await repo.costoDe(id), 900);
    expect(await repo.costos(), {id: 900});
  });

  test('editar reemplaza nombre, precio y proveedores', () async {
    final id = await repo.guardarProducto(
        nombre: 'Coca', precio: 1200, proveedores: [de(postobon, 900, preferido: true)]);

    await repo.guardarProducto(
      id: id,
      nombre: 'Coca 400',
      precio: 1300,
      proveedores: [de(alpina, 850, preferido: true)],
    );

    final producto = await (db.select(db.productos)
          ..where((p) => p.id.equals(id)))
        .getSingle();
    expect(producto.nombre, 'Coca 400');
    expect(producto.precio, 1300);
    expect((await repo.proveedoresDe(id)).single.proveedorId, alpina);
    expect(await repo.costoDe(id), 850);
  });

  test('sin proveedores no hay costo', () async {
    final id = await repo.guardarProducto(nombre: 'Pan', precio: 500);
    expect(await repo.costoDe(id), isNull);
    expect(await repo.costos(), isEmpty);
  });

  test('listas inválidas se rechazan sin guardar nada', () async {
    final invalidas = [
      [de(postobon, 900), de(alpina, 850)], // sin preferido
      [de(postobon, 900, preferido: true), de(alpina, 850, preferido: true)],
      [de(postobon, 0, preferido: true)],
      [de(postobon, 900, preferido: true), de(postobon, 800)],
    ];
    for (final lista in invalidas) {
      await expectLater(
          repo.guardarProducto(nombre: 'Coca', precio: 1200, proveedores: lista),
          throwsArgumentError);
    }
    await expectLater(
        repo.guardarProducto(nombre: ' ', precio: 1200), throwsArgumentError);
    await expectLater(
        repo.guardarProducto(nombre: 'Coca', precio: 0), throwsArgumentError);
    expect(await db.select(db.productos).get(), isEmpty);
    expect(await db.select(db.productosProveedores).get(), isEmpty);
  });

  test('un proveedor inactivo no se agrega a un producto nuevo', () async {
    await proveedores.desactivar(alpina);
    await expectLater(
        repo.guardarProducto(
            nombre: 'Avena',
            precio: 2000,
            proveedores: [de(alpina, 1500, preferido: true)]),
        throwsArgumentError);
    expect(await db.select(db.productos).get(), isEmpty);
  });

  test('un proveedor que se desactivó después se conserva al editar',
      () async {
    final id = await repo.guardarProducto(
        nombre: 'Avena',
        precio: 2000,
        proveedores: [de(alpina, 1500, preferido: true)]);
    await proveedores.desactivar(alpina);

    await repo.guardarProducto(
        id: id,
        nombre: 'Avena grande',
        precio: 2200,
        proveedores: [de(alpina, 1600, preferido: true)]);

    expect(await repo.costoDe(id), 1600);
  });

  test('si falla al editar no cambia nada', () async {
    final id = await repo.guardarProducto(
        nombre: 'Coca', precio: 1200, proveedores: [de(postobon, 900, preferido: true)]);
    await proveedores.desactivar(alpina);

    await expectLater(
        repo.guardarProducto(
            id: id,
            nombre: 'Coca nueva',
            precio: 1500,
            proveedores: [
              de(postobon, 900, preferido: true),
              de(alpina, 850),
            ]),
        throwsArgumentError);

    final producto = await (db.select(db.productos)
          ..where((p) => p.id.equals(id)))
        .getSingle();
    expect(producto.nombre, 'Coca');
    expect(await repo.proveedoresDe(id), hasLength(1));
  });
}
```

- [ ] **Step 2: Correr y ver que falla**

Run: `flutter test test/repositories/producto_proveedores_test.dart`
Expected: FAIL (`ProveedorDeProducto`, `guardarProducto` no existen).

- [ ] **Step 3: Implementar**

En `lib/repositories/producto_repository.dart`, antes de la clase:

```dart
/// Un proveedor de un producto, tal como se edita en el formulario.
class ProveedorDeProducto {
  const ProveedorDeProducto({
    required this.proveedorId,
    required this.precioCompra,
    required this.preferido,
  });

  final int proveedorId;
  final int precioCompra;
  final bool preferido;
}
```

y dentro de la clase, al final:

```dart
  /// Proveedores de [productoId] en el orden en que se agregaron.
  Future<List<ProductoProveedor>> proveedoresDe(int productoId) =>
      (_db.select(_db.productosProveedores)
            ..where((p) => p.productoId.equals(productoId))
            ..orderBy([(p) => OrderingTerm.asc(p.id)]))
          .get();

  /// Precio de compra del proveedor preferido; null sin proveedores.
  Future<int?> costoDe(int productoId) async {
    final preferido = await (_db.select(_db.productosProveedores)
          ..where((p) =>
              p.productoId.equals(productoId) & p.preferido.equals(true)))
        .getSingleOrNull();
    return preferido?.precioCompra;
  }

  /// Producto → costo, solo de los productos con proveedor preferido.
  Future<Map<int, int>> costos() async {
    final filas = await (_db.select(_db.productosProveedores)
          ..where((p) => p.preferido.equals(true)))
        .get();
    return {for (final f in filas) f.productoId: f.precioCompra};
  }

  /// Crea ([id] null) o actualiza el producto y reemplaza sus proveedores,
  /// todo en una transacción. Devuelve el id.
  Future<int> guardarProducto({
    int? id,
    required String nombre,
    required int precio,
    List<ProveedorDeProducto> proveedores = const [],
  }) async {
    final limpio = nombre.trim();
    if (limpio.isEmpty) throw ArgumentError('Escribe un nombre');
    if (precio <= 0) throw ArgumentError('Escribe un precio válido');
    if (proveedores.any((p) => p.precioCompra <= 0)) {
      throw ArgumentError('Precio de compra inválido');
    }
    if (proveedores.map((p) => p.proveedorId).toSet().length !=
        proveedores.length) {
      throw ArgumentError('Proveedor repetido');
    }
    if (proveedores.isNotEmpty &&
        proveedores.where((p) => p.preferido).length != 1) {
      throw ArgumentError('Debe haber un proveedor preferido');
    }
    return _db.transaction(() async {
      final previos = id == null
          ? <int>{}
          : (await proveedoresDe(id)).map((p) => p.proveedorId).toSet();
      for (final p in proveedores) {
        if (previos.contains(p.proveedorId)) continue;
        final proveedor = await (_db.select(_db.proveedores)
              ..where((x) => x.id.equals(p.proveedorId)))
            .getSingleOrNull();
        if (proveedor == null || !proveedor.activo) {
          throw ArgumentError('Proveedor inactivo');
        }
      }
      final productoId = id ??
          await _db.into(_db.productos).insert(
              ProductosCompanion.insert(nombre: limpio, precio: precio));
      if (id != null) {
        await (_db.update(_db.productos)..where((p) => p.id.equals(id)))
            .write(ProductosCompanion(
                nombre: Value(limpio), precio: Value(precio)));
      }
      await (_db.delete(_db.productosProveedores)
            ..where((p) => p.productoId.equals(productoId)))
          .go();
      for (final p in proveedores) {
        await _db.into(_db.productosProveedores).insert(
              ProductosProveedoresCompanion.insert(
                productoId: productoId,
                proveedorId: p.proveedorId,
                precioCompra: p.precioCompra,
                preferido: Value(p.preferido),
              ),
            );
      }
      return productoId;
    });
  }
```

En `lib/providers/productos_providers.dart` agregar (con los imports que falten: `database_provider.dart`, `repository_providers.dart`):

```dart
/// Emite con cada cambio en la base, para refrescar los costos.
final _cambiosCostosProvider = StreamProvider<void>((ref) {
  return ref.watch(databaseProvider).tableUpdates().map((_) {});
});

/// Producto → costo (precio del proveedor preferido).
final costosProductosProvider = FutureProvider<Map<int, int>>((ref) {
  ref.watch(_cambiosCostosProvider);
  return ref.watch(productoRepositoryProvider).costos();
});
```

- [ ] **Step 4: Correr y ver que pasa**

Run: `flutter test test/repositories` y `flutter analyze lib`
Expected: PASS y "No issues found!"

- [ ] **Step 5: Commit**

```bash
git add lib/repositories/producto_repository.dart lib/providers/productos_providers.dart test/repositories/producto_proveedores_test.dart
git commit -m "Save a product with its suppliers and preferred cost in one transaction"
```

---

### Task 6: Costo en cada venta y ganancia en el reporte

**Files:**
- Modify: `lib/repositories/venta_repository.dart` (`registrarVenta`)
- Modify: `lib/repositories/reporte_repository.dart`
- Test: `test/repositories/costo_ganancia_test.dart`

**Interfaces:**
- Consumes: `ProductoRepository.guardarProducto`, `ProveedorDeProducto` (Task 5); `ProveedorRepository.crear` (Task 4); `LineaVenta.costoUnitario` (Task 1).
- Produces: `registrarVenta` guarda `costoUnitario` por línea; `ProductoVendido.ganancia` (`int?`, parámetro opcional `this.ganancia`); `Reporte.gananciaProductos` (`int`), `Reporte.vendidoSinCosto` (`int`), `Reporte.hayCostos` (`bool`: hubo alguna línea con costo).

- [ ] **Step 1: Escribir la prueba que falla**

`test/repositories/costo_ganancia_test.dart`:

```dart
import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/repositories/fiado_repository.dart';
import 'package:app_ventas/repositories/producto_repository.dart';
import 'package:app_ventas/repositories/proveedor_repository.dart';
import 'package:app_ventas/repositories/reporte_repository.dart';
import 'package:app_ventas/repositories/venta_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late VentaRepository ventas;
  late ProductoRepository productos;
  late int ana;
  late int arepa; // precio 3500, costo 2500
  late int coca; // precio 1200, sin proveedor
  late int postobon;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    ventas = VentaRepository(db);
    productos = ProductoRepository(db);
    ana = await db.into(db.usuarios).insert(
        UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'x'));
    postobon = await ProveedorRepository(db).crear(nombre: 'Postobón');
    arepa = await productos.guardarProducto(
      nombre: 'Arepa',
      precio: 3500,
      proveedores: [
        ProveedorDeProducto(
            proveedorId: postobon, precioCompra: 2500, preferido: true),
      ],
    );
    coca = await productos.guardarProducto(nombre: 'Coca', precio: 1200);
  });

  tearDown(() => db.close());

  LineaNueva de(int id, String nombre, int precio, int cantidad) => LineaNueva(
      productoId: id,
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

  test('cada línea guarda el costo del preferido; los sueltos no', () async {
    final id = await vender(DateTime(2026, 10, 6), [
      de(arepa, 'Arepa', 3500, 2),
      de(coca, 'Coca', 1200, 1),
      const LineaNueva(descripcion: r'$5.000', precioUnitario: 5000, cantidad: 1),
    ]);

    final lineas = await ventas.lineasDeVenta(id);
    expect(lineas.map((l) => l.costoUnitario), [2500, null, null]);
  });

  test('cambiar el costo después no altera la venta guardada', () async {
    final id = await vender(DateTime(2026, 10, 6), [de(arepa, 'Arepa', 3500, 1)]);
    await productos.guardarProducto(
      id: arepa,
      nombre: 'Arepa',
      precio: 3500,
      proveedores: [
        ProveedorDeProducto(
            proveedorId: postobon, precioCompra: 3000, preferido: true),
      ],
    );

    expect((await ventas.lineasDeVenta(id)).single.costoUnitario, 2500);
  });

  test('el reporte suma la ganancia y lo vendido sin costo', () async {
    await vender(DateTime(2026, 10, 6), [
      de(arepa, 'Arepa', 3500, 2),
      de(coca, 'Coca', 1200, 1),
      const LineaNueva(descripcion: r'$5.000', precioUnitario: 5000, cantidad: 1),
    ]);
    final anulada =
        await vender(DateTime(2026, 10, 7), [de(arepa, 'Arepa', 3500, 10)]);
    await db.customStatement(
        'UPDATE ventas SET anulado = 1 WHERE id = ?', [anulada]);

    final r = await ReporteRepository(db, FiadoRepository(db))
        .reporte(DateTime(2026, 10, 5), DateTime(2026, 10, 11));

    final deArepa = r.ranking.firstWhere((p) => p.productoId == arepa);
    final deCoca = r.ranking.firstWhere((p) => p.productoId == coca);
    expect(deArepa.ganancia, 2000);
    expect(deCoca.ganancia, isNull);
    expect(r.gananciaProductos, 2000);
    expect(r.vendidoSinCosto, 6200);
    expect(r.hayCostos, isTrue);
  });

  test('sin líneas con costo no hay costos', () async {
    await vender(DateTime(2026, 10, 6), [de(coca, 'Coca', 1200, 1)]);

    final r = await ReporteRepository(db, FiadoRepository(db))
        .reporte(DateTime(2026, 10, 5), DateTime(2026, 10, 11));

    expect(r.hayCostos, isFalse);
    expect(r.gananciaProductos, 0);
    expect(r.vendidoSinCosto, 1200);
  });
}
```

- [ ] **Step 2: Correr y ver que falla**

Run: `flutter test test/repositories/costo_ganancia_test.dart`
Expected: FAIL (`ganancia`, `gananciaProductos`, `vendidoSinCosto`, `hayCostos` no existen).

- [ ] **Step 3: Guardar el costo al vender**

En `lib/repositories/venta_repository.dart`, dentro de la transacción de `registrarVenta`, reemplazar el `for (final linea in lineas) {...}` por:

```dart
      for (final linea in lineas) {
        final productoId = linea.productoId;
        final costo = productoId == null
            ? null
            : (await (_db.select(_db.productosProveedores)
                      ..where((p) =>
                          p.productoId.equals(productoId) &
                          p.preferido.equals(true)))
                    .getSingleOrNull())
                ?.precioCompra;
        await _db.into(_db.lineasVenta).insert(LineasVentaCompanion.insert(
              ventaId: id,
              productoId: Value(linea.productoId),
              descripcion: linea.descripcion,
              precioUnitario: linea.precioUnitario,
              cantidad: linea.cantidad,
              costoUnitario: Value(costo),
            ));
      }
```

- [ ] **Step 4: Ganancia en el reporte**

En `lib/repositories/reporte_repository.dart`:

- `ProductoVendido`: agregar `this.ganancia,` al constructor y el campo

```dart
  /// Σ (precio − costo) × cantidad de sus líneas con costo; null si ninguna
  /// tuvo costo.
  final int? ganancia;
```

- `Reporte`: agregar al constructor `required this.gananciaProductos, required this.vendidoSinCosto, required this.hayCostos,` y los campos

```dart
  /// Ganancia de todas las líneas con costo.
  final int gananciaProductos;

  /// Lo vendido en líneas sin costo (productos sin costo y montos sueltos).
  final int vendidoSinCosto;

  /// Hubo al menos una línea con costo.
  final bool hayCostos;
```

- en `reporte(...)`, cambiar el tipo del acumulado y el ciclo de líneas:

```dart
    final acumulado =
        <int, ({String nombre, int unidades, int dinero, int? ganancia})>{};
    var otrosMontos = 0;
    var gananciaProductos = 0;
    var vendidoSinCosto = 0;
    var hayCostos = false;
    for (final fila in filas) {
      final linea = fila.readTable(_db.lineasVenta);
      final subtotal = linea.precioUnitario * linea.cantidad;
      final costo = linea.costoUnitario;
      final gananciaLinea = costo == null
          ? null
          : (linea.precioUnitario - costo) * linea.cantidad;
      if (gananciaLinea == null) {
        vendidoSinCosto += subtotal;
      } else {
        gananciaProductos += gananciaLinea;
        hayCostos = true;
      }
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
        ganancia: gananciaLinea == null
            ? previo?.ganancia
            : (previo?.ganancia ?? 0) + gananciaLinea,
      );
    }
```

- en la construcción de `ranking`, agregar `ganancia: e.value.ganancia,` a `ProductoVendido(...)`.
- en `return Reporte(...)`, agregar:

```dart
      gananciaProductos: gananciaProductos,
      vendidoSinCosto: vendidoSinCosto,
      hayCostos: hayCostos,
```

- [ ] **Step 5: Correr y ver que pasa**

Run: `flutter test test/repositories`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add lib/repositories/venta_repository.dart lib/repositories/reporte_repository.dart test/repositories/costo_ganancia_test.dart
git commit -m "Store each line's cost at sale time and add product profit to the report"
```

---

### Task 7: Pantalla Proveedores

**Files:**
- Create: `lib/screens/configuracion/proveedores_screen.dart`
- Modify: `lib/screens/configuracion/ajustes_screen.dart`
- Test: `test/screens/configuracion/proveedores_screen_test.dart`

**Interfaces:**
- Consumes: `ProveedorRepository` y providers de proveedores (Task 4); `mostrarHojaInferior`, `avisar`, `plural`, `EstadoVacio`, `BotonPrincipal`, `formatoMoneda`.
- Produces: `ProveedoresScreen`; llaves `boton_agregar_proveedor_nuevo`, `proveedor_item_<id>`, `boton_desactivar_proveedor_<id>`, `proveedor_inactivo_<id>`, `boton_reactivar_proveedor_<id>`, `campo_nombre_proveedor`, `campo_telefono_proveedor`, `campo_notas_proveedor`, `boton_guardar_proveedor`, `menu_proveedores`.

- [ ] **Step 1: Escribir la prueba que falla**

`test/screens/configuracion/proveedores_screen_test.dart`:

```dart
import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/repositories/producto_repository.dart';
import 'package:app_ventas/repositories/proveedor_repository.dart';
import 'package:app_ventas/screens/configuracion/ajustes_screen.dart';
import 'package:app_ventas/screens/configuracion/proveedores_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/montaje.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> montar(WidgetTester tester,
      {Widget inicio = const ProveedoresScreen()}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final container = await containerConSesion(db);
    addTearDown(container.dispose);
    await tester.pumpWidget(appDePrueba(container, inicio: inicio));
    await tester.pumpAndSettle();
  }

  testWidgets('sin proveedores muestra el estado vacío', (tester) async {
    await montar(tester);
    expect(find.text('Aún no tienes proveedores'), findsOneWidget);
  });

  testWidgets('crear un proveedor lo agrega a la lista', (tester) async {
    await montar(tester);

    await tester.tap(find.byKey(const Key('boton_agregar_proveedor_nuevo')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('campo_nombre_proveedor')), 'Postobón');
    await tester.enterText(
        find.byKey(const Key('campo_telefono_proveedor')), '3001234567');
    await tester.tap(find.byKey(const Key('boton_guardar_proveedor')));
    await tester.pumpAndSettle();

    expect(find.text('Postobón'), findsOneWidget);
    expect(find.text('3001234567 · Surte 0 productos'), findsOneWidget);
    expect(find.text('Proveedor guardado'), findsOneWidget);
  });

  testWidgets('sin nombre no se guarda', (tester) async {
    await montar(tester);

    await tester.tap(find.byKey(const Key('boton_agregar_proveedor_nuevo')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('boton_guardar_proveedor')));
    await tester.pumpAndSettle();

    expect(find.text('Escribe un nombre'), findsOneWidget);
    expect(await db.select(db.proveedores).get(), isEmpty);
  });

  testWidgets('editar muestra los productos que surte y guarda cambios',
      (tester) async {
    final id = await ProveedorRepository(db).crear(nombre: 'Postobón');
    await ProductoRepository(db).guardarProducto(
      nombre: 'Coca',
      precio: 1200,
      proveedores: [
        ProveedorDeProducto(proveedorId: id, precioCompra: 900, preferido: true),
      ],
    );
    await montar(tester);
    expect(find.text('Surte 1 producto'), findsOneWidget);

    await tester.tap(find.byKey(Key('proveedor_item_$id')));
    await tester.pumpAndSettle();
    expect(find.text('Productos que surte'), findsOneWidget);
    expect(find.text(r'Coca · $900'), findsOneWidget);
    await tester.enterText(
        find.byKey(const Key('campo_notas_proveedor')), 'Viene los martes');
    await tester.tap(find.byKey(const Key('boton_guardar_proveedor')));
    await tester.pumpAndSettle();

    final p = await db.select(db.proveedores).getSingle();
    expect(p.notas, 'Viene los martes');
  });

  testWidgets('desactivar y reactivar', (tester) async {
    final id = await ProveedorRepository(db).crear(nombre: 'Postobón');
    await montar(tester);

    await tester.tap(find.byKey(Key('boton_desactivar_proveedor_$id')));
    await tester.pumpAndSettle();
    expect(find.byKey(Key('proveedor_inactivo_$id')), findsOneWidget);

    await tester.tap(find.byKey(Key('boton_reactivar_proveedor_$id')));
    await tester.pumpAndSettle();
    expect(find.byKey(Key('proveedor_item_$id')), findsOneWidget);
  });

  testWidgets('Ajustes tiene la entrada Proveedores', (tester) async {
    await montar(tester, inicio: const Scaffold(body: AjustesScreen()));

    await tester.tap(find.byKey(const Key('menu_proveedores')));
    await tester.pumpAndSettle();

    expect(find.byType(ProveedoresScreen), findsOneWidget);
  });
}
```

- [ ] **Step 2: Correr y ver que falla**

Run: `flutter test test/screens/configuracion/proveedores_screen_test.dart`
Expected: FAIL (`proveedores_screen.dart` no existe).

- [ ] **Step 3: Implementar**

`lib/screens/configuracion/proveedores_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../providers/proveedores_providers.dart';
import '../../providers/repository_providers.dart';
import '../../ui/avisos.dart';
import '../../ui/boton_principal.dart';
import '../../ui/colores_app.dart';
import '../../ui/estado_vacio.dart';
import '../../ui/hoja_inferior.dart';
import '../../util/formato_moneda.dart';
import '../../util/texto_util.dart';

/// Proveedores de la tienda: crear, editar, desactivar y reactivar.
class ProveedoresScreen extends ConsumerWidget {
  const ProveedoresScreen({super.key});

  Future<void> _abrir(BuildContext context, {Proveedor? proveedor}) async {
    final guardado = await mostrarHojaInferior<bool>(
      context,
      titulo: proveedor == null ? 'Nuevo proveedor' : 'Editar proveedor',
      builder: (_) => _FormularioProveedor(proveedor: proveedor),
    );
    if (guardado == true && context.mounted) {
      avisar(context, 'Proveedor guardado');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activosAsync = ref.watch(proveedoresActivosProvider);
    final inactivos =
        ref.watch(proveedoresInactivosProvider).valueOrNull ?? const <Proveedor>[];
    final conteo =
        ref.watch(cantidadProductosPorProveedorProvider).valueOrNull ?? const {};
    final repo = ref.read(proveedorRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Proveedores')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('boton_agregar_proveedor_nuevo'),
        onPressed: () => _abrir(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Agregar'),
      ),
      body: activosAsync.when(
        data: (activos) {
          if (activos.isEmpty && inactivos.isEmpty) {
            return const EstadoVacio(
              icono: Icons.local_shipping_outlined,
              titulo: 'Aún no tienes proveedores',
              mensaje: 'Agrega a quién le compras para armar tus pedidos',
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              if (activos.isNotEmpty)
                Card(
                  child: Column(
                    children: [
                      for (final p in activos)
                        ListTile(
                          key: Key('proveedor_item_${p.id}'),
                          title: Text(p.nombre,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text([
                            if (p.telefono != null) p.telefono!,
                            'Surte ${plural(conteo[p.id] ?? 0, 'producto', 'productos')}',
                          ].join(' · ')),
                          onTap: () => _abrir(context, proveedor: p),
                          trailing: IconButton(
                            key: Key('boton_desactivar_proveedor_${p.id}'),
                            tooltip: 'Desactivar',
                            icon: const Icon(Icons.visibility_off_outlined),
                            onPressed: () => repo.desactivar(p.id),
                          ),
                        ),
                    ],
                  ),
                ),
              if (inactivos.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(4, 24, 4, 8),
                  child: Text(
                    'Inactivos',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: ColoresApp.textoSecundario,
                    ),
                  ),
                ),
                Card(
                  child: Column(
                    children: [
                      for (final p in inactivos)
                        ListTile(
                          key: Key('proveedor_inactivo_${p.id}'),
                          title: Text(p.nombre,
                              style: const TextStyle(
                                  color: ColoresApp.textoSecundario)),
                          trailing: TextButton(
                            key: Key('boton_reactivar_proveedor_${p.id}'),
                            onPressed: () => repo.reactivar(p.id),
                            child: const Text('Reactivar'),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _FormularioProveedor extends ConsumerStatefulWidget {
  const _FormularioProveedor({this.proveedor});

  final Proveedor? proveedor;

  @override
  ConsumerState<_FormularioProveedor> createState() =>
      _FormularioProveedorState();
}

class _FormularioProveedorState extends ConsumerState<_FormularioProveedor> {
  late final _nombre = TextEditingController(text: widget.proveedor?.nombre);
  late final _telefono =
      TextEditingController(text: widget.proveedor?.telefono);
  late final _notas = TextEditingController(text: widget.proveedor?.notas);
  String? _error;
  bool _guardando = false;

  @override
  void dispose() {
    _nombre.dispose();
    _telefono.dispose();
    _notas.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_guardando) return;
    if (_nombre.text.trim().isEmpty) {
      setState(() => _error = 'Escribe un nombre');
      return;
    }
    setState(() => _guardando = true);
    try {
      final repo = ref.read(proveedorRepositoryProvider);
      final id = widget.proveedor?.id;
      if (id == null) {
        await repo.crear(
            nombre: _nombre.text, telefono: _telefono.text, notas: _notas.text);
      } else {
        await repo.actualizar(id,
            nombre: _nombre.text, telefono: _telefono.text, notas: _notas.text);
      }
      if (mounted) Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.proveedor?.id;
    final productos = id == null
        ? const <({Producto producto, int precioCompra})>[]
        : ref.watch(productosDeProveedorProvider(id)).valueOrNull ??
            const <({Producto producto, int precioCompra})>[];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('campo_nombre_proveedor'),
          controller: _nombre,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(labelText: 'Nombre', errorText: _error),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('campo_telefono_proveedor'),
          controller: _telefono,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'Teléfono'),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('campo_notas_proveedor'),
          controller: _notas,
          decoration: const InputDecoration(labelText: 'Notas'),
        ),
        if (productos.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text('Productos que surte',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          for (final p in productos)
            Text('${p.producto.nombre} · ${formatoMoneda(p.precioCompra)}'),
        ],
        const SizedBox(height: 16),
        BotonPrincipal(
          key: const Key('boton_guardar_proveedor'),
          texto: 'Guardar',
          onPressed: _guardando ? null : _guardar,
        ),
      ],
    );
  }
}
```

En `lib/screens/configuracion/ajustes_screen.dart`: import `proveedores_screen.dart` y, después del `ListTile` de `menu_productos` y su `Divider`:

```dart
              ListTile(
                key: const Key('menu_proveedores'),
                leading: const Icon(Icons.local_shipping_outlined),
                title: const Text('Proveedores'),
                subtitle: const Text('A quién le compras'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProveedoresScreen()),
                ),
              ),
              const Divider(height: 1),
```

- [ ] **Step 4: Correr y ver que pasa**

Run: `flutter test test/screens/configuracion`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/screens/configuracion/proveedores_screen.dart lib/screens/configuracion/ajustes_screen.dart test/screens/configuracion/proveedores_screen_test.dart
git commit -m "Add the Proveedores screen in Ajustes"
```

---

### Task 8: Pantalla Producto con proveedores

**Files:**
- Create: `lib/screens/configuracion/producto_screen.dart`
- Modify: `lib/screens/configuracion/productos_screen.dart` (abrir `ProductoScreen`; subtítulo con ganancia; quitar `_FormularioProducto`)
- Delete: `lib/screens/configuracion/editar_producto_dialog.dart`
- Modify (reescribir): `test/screens/configuracion/productos_screen_test.dart`

**Interfaces:**
- Consumes: `ProductoRepository.guardarProducto`, `proveedoresDe`, `ProveedorDeProducto`, `costosProductosProvider` (Task 5); `ProveedorRepository.todos`, `crear`, `proveedoresActivosProvider` (Task 4).
- Produces: `ProductoScreen({Key? key, Producto? producto})` (devuelve `true` con `pop` al guardar); llaves `campo_nombre_producto`, `campo_precio_producto`, `boton_guardar_producto`, `boton_agregar_proveedor`, `fila_proveedor_<id>`, `preferido_<id>`, `quitar_proveedor_<id>`, `texto_resumen_costo`, y en la hoja `opcion_proveedor_<id>`, `campo_nuevo_proveedor`, `campo_precio_compra`, `boton_agregar_proveedor_producto`.

- [ ] **Step 1: Reescribir las pruebas (fallan)**

`test/screens/configuracion/productos_screen_test.dart` (reemplazo completo):

```dart
import 'dart:async';

import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/repository_providers.dart';
import 'package:app_ventas/repositories/producto_repository.dart';
import 'package:app_ventas/repositories/proveedor_repository.dart';
import 'package:app_ventas/screens/configuracion/producto_screen.dart';
import 'package:app_ventas/screens/configuracion/productos_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/montaje.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> montar(WidgetTester tester,
      {List<Override> overrides = const []}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final container = await containerConSesion(db, overrides: overrides);
    addTearDown(container.dispose);
    await tester.pumpWidget(
        appDePrueba(container, inicio: const ProductosScreen()));
    await tester.pumpAndSettle();
  }

  Future<int> crearArepa() => db.into(db.productos).insert(
        ProductosCompanion.insert(nombre: 'Arepa', precio: 3000),
      );

  Future<void> guardar(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const Key('boton_guardar_producto')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('boton_guardar_producto')));
    await tester.pumpAndSettle();
  }

  Future<void> agregarProveedor(
      WidgetTester tester, int proveedorId, String precio) async {
    await tester.ensureVisible(find.byKey(const Key('boton_agregar_proveedor')));
    await tester.tap(find.byKey(const Key('boton_agregar_proveedor')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('opcion_proveedor_$proveedorId')));
    await tester.enterText(find.byKey(const Key('campo_precio_compra')), precio);
    await tester.tap(find.byKey(const Key('boton_agregar_proveedor_producto')));
    await tester.pumpAndSettle();
  }

  testWidgets('sin productos muestra el estado vacío', (tester) async {
    await montar(tester);
    expect(find.text('Aún no tienes productos'), findsOneWidget);
  });

  testWidgets('crear un producto lo agrega sin costo y lo confirma',
      (tester) async {
    await montar(tester);

    await tester.tap(find.byKey(const Key('boton_agregar_producto')));
    await tester.pumpAndSettle();
    expect(find.text('Nuevo producto'), findsOneWidget);
    await tester.enterText(
        find.byKey(const Key('campo_nombre_producto')), 'Arepa');
    await tester.enterText(
        find.byKey(const Key('campo_precio_producto')), '3.000');
    expect(find.text('Sin costo: agrega un proveedor para ver la ganancia'),
        findsOneWidget);
    await guardar(tester);

    expect(find.byType(ProductoScreen), findsNothing);
    expect(find.text('Arepa'), findsOneWidget);
    expect(find.text(r'$3.000 · sin costo'), findsOneWidget);
    expect(find.text('Producto guardado'), findsOneWidget);
  });

  testWidgets('un precio inválido muestra error y no guarda', (tester) async {
    await montar(tester);

    await tester.tap(find.byKey(const Key('boton_agregar_producto')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('campo_nombre_producto')), 'Arepa');
    await tester.enterText(
        find.byKey(const Key('campo_precio_producto')), '2.5');
    await guardar(tester);

    expect(find.text('Escribe un precio válido'), findsOneWidget);
    expect(await db.select(db.productos).get(), isEmpty);
  });

  testWidgets('editar un producto cambia nombre y precio', (tester) async {
    final id = await crearArepa();
    await montar(tester);

    await tester.tap(find.byKey(Key('producto_item_$id')));
    await tester.pumpAndSettle();
    expect(find.text('Editar producto'), findsOneWidget);
    await tester.enterText(
        find.byKey(const Key('campo_nombre_producto')), 'Arepa rellena');
    await tester.enterText(
        find.byKey(const Key('campo_precio_producto')), '3.500');
    await guardar(tester);

    final producto = await db.select(db.productos).getSingle();
    expect(producto.nombre, 'Arepa rellena');
    expect(producto.precio, 3500);
    expect(find.text(r'$3.500 · sin costo'), findsOneWidget);
  });

  testWidgets(
      'dos proveedores: el primero queda preferido y se puede cambiar',
      (tester) async {
    final proveedores = ProveedorRepository(db);
    final postobon = await proveedores.crear(nombre: 'Postobón');
    final alpina = await proveedores.crear(nombre: 'Alpina');
    await montar(tester);

    await tester.tap(find.byKey(const Key('boton_agregar_producto')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('campo_nombre_producto')), 'Arepa');
    await tester.enterText(
        find.byKey(const Key('campo_precio_producto')), '3.500');
    await agregarProveedor(tester, postobon, '2.500');
    await agregarProveedor(tester, alpina, '2.300');
    expect(find.text(r'Costo $2.500 · Ganas $1.000 por unidad (29 %)'),
        findsOneWidget);

    await tester.tap(find.byKey(Key('preferido_$alpina')));
    await tester.pump();
    expect(find.text(r'Costo $2.300 · Ganas $1.200 por unidad (34 %)'),
        findsOneWidget);
    await guardar(tester);

    final id = (await db.select(db.productos).getSingle()).id;
    expect(await ProductoRepository(db).costoDe(id), 2300);
    expect(find.text(r'$3.500 · gana $1.200'), findsOneWidget);
  });

  testWidgets('quitar el preferido deja preferido al otro', (tester) async {
    final proveedores = ProveedorRepository(db);
    final postobon = await proveedores.crear(nombre: 'Postobón');
    final alpina = await proveedores.crear(nombre: 'Alpina');
    await montar(tester);

    await tester.tap(find.byKey(const Key('boton_agregar_producto')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('campo_nombre_producto')), 'Arepa');
    await tester.enterText(
        find.byKey(const Key('campo_precio_producto')), '3.500');
    await agregarProveedor(tester, postobon, '2.500');
    await agregarProveedor(tester, alpina, '2.300');
    await tester.tap(find.byKey(Key('quitar_proveedor_$postobon')));
    await tester.pump();
    await guardar(tester);

    final id = (await db.select(db.productos).getSingle()).id;
    final lista = await ProductoRepository(db).proveedoresDe(id);
    expect(lista.single.proveedorId, alpina);
    expect(lista.single.preferido, isTrue);
  });

  testWidgets('un costo mayor que el precio avisa la pérdida',
      (tester) async {
    final postobon = await ProveedorRepository(db).crear(nombre: 'Postobón');
    await montar(tester);

    await tester.tap(find.byKey(const Key('boton_agregar_producto')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('campo_nombre_producto')), 'Arepa');
    await tester.enterText(
        find.byKey(const Key('campo_precio_producto')), '2.000');
    await agregarProveedor(tester, postobon, '2.500');

    expect(find.text('Este producto se vende con pérdida'), findsOneWidget);
  });

  testWidgets('agregar un proveedor nuevo desde el producto', (tester) async {
    await montar(tester);

    await tester.tap(find.byKey(const Key('boton_agregar_producto')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('campo_nombre_producto')), 'Avena');
    await tester.enterText(
        find.byKey(const Key('campo_precio_producto')), '2.000');
    await tester.ensureVisible(find.byKey(const Key('boton_agregar_proveedor')));
    await tester.tap(find.byKey(const Key('boton_agregar_proveedor')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('campo_nuevo_proveedor')), 'Alpina');
    await tester.enterText(
        find.byKey(const Key('campo_precio_compra')), '1.500');
    await tester.tap(find.byKey(const Key('boton_agregar_proveedor_producto')));
    await tester.pumpAndSettle();
    await guardar(tester);

    expect((await db.select(db.proveedores).getSingle()).nombre, 'Alpina');
    final id = (await db.select(db.productos).getSingle()).id;
    expect(await ProductoRepository(db).costoDe(id), 1500);
  });

  testWidgets('desactivar lo pasa a Inactivos y reactivar lo devuelve',
      (tester) async {
    final id = await crearArepa();
    await montar(tester);

    await tester.tap(find.byKey(Key('boton_desactivar_$id')));
    await tester.pumpAndSettle();
    expect(find.byKey(Key('producto_inactivo_$id')), findsOneWidget);

    await tester.tap(find.byKey(Key('boton_reactivar_$id')));
    await tester.pumpAndSettle();
    expect(find.byKey(Key('producto_item_$id')), findsOneWidget);
  });

  testWidgets('un doble toque en Guardar cierra solo la pantalla del producto',
      (tester) async {
    final id = await crearArepa();
    final guardado = Completer<void>();
    await montar(tester, overrides: [
      productoRepositoryProvider
          .overrideWith((ref) => _ProductoRepositoryLento(db, guardado.future)),
    ]);

    await tester.tap(find.byKey(Key('producto_item_$id')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('boton_guardar_producto')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('boton_guardar_producto')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('boton_guardar_producto')),
        warnIfMissed: false);
    await tester.pump();
    guardado.complete();
    await tester.pumpAndSettle();

    expect(find.byType(ProductoScreen), findsNothing);
    expect(find.byType(ProductosScreen), findsOneWidget);
  });
}

/// Espera a [_espera] antes de guardar, para simular la latencia de la base.
class _ProductoRepositoryLento extends ProductoRepository {
  _ProductoRepositoryLento(super.db, this._espera);

  final Future<void> _espera;

  @override
  Future<int> guardarProducto({
    int? id,
    required String nombre,
    required int precio,
    List<ProveedorDeProducto> proveedores = const [],
  }) async {
    await _espera;
    return super.guardarProducto(
        id: id, nombre: nombre, precio: precio, proveedores: proveedores);
  }
}
```

- [ ] **Step 2: Correr y ver que falla**

Run: `flutter test test/screens/configuracion/productos_screen_test.dart`
Expected: FAIL (`producto_screen.dart` no existe).

- [ ] **Step 3: Implementar la pantalla Producto**

`lib/screens/configuracion/producto_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../providers/proveedores_providers.dart';
import '../../providers/repository_providers.dart';
import '../../repositories/producto_repository.dart';
import '../../ui/boton_principal.dart';
import '../../ui/colores_app.dart';
import '../../ui/hoja_inferior.dart';
import '../../util/formato_moneda.dart';

/// Un proveedor en edición dentro del formulario.
class _Fila {
  _Fila({
    required this.proveedorId,
    required this.nombre,
    required this.activo,
    required this.precioCompra,
    required this.preferido,
  });

  final int proveedorId;
  final String nombre;
  final bool activo;
  final int precioCompra;
  bool preferido;
}

/// Crea ([producto] null) o edita un producto con sus proveedores. Se cierra
/// con `true` si guardó.
class ProductoScreen extends ConsumerStatefulWidget {
  const ProductoScreen({super.key, this.producto});

  final Producto? producto;

  @override
  ConsumerState<ProductoScreen> createState() => _ProductoScreenState();
}

class _ProductoScreenState extends ConsumerState<ProductoScreen> {
  late final _nombre = TextEditingController(text: widget.producto?.nombre);
  late final _precio =
      TextEditingController(text: widget.producto?.precio.toString());
  final List<_Fila> _filas = [];
  String? _errorNombre;
  String? _errorPrecio;
  String? _error;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    final id = widget.producto?.id;
    if (id != null) _cargar(id);
  }

  Future<void> _cargar(int id) async {
    final vinculos = await ref.read(productoRepositoryProvider).proveedoresDe(id);
    final proveedores = {
      for (final p in await ref.read(proveedorRepositoryProvider).todos()) p.id: p,
    };
    if (!mounted) return;
    setState(() {
      _filas.addAll([
        for (final v in vinculos)
          _Fila(
            proveedorId: v.proveedorId,
            nombre: proveedores[v.proveedorId]?.nombre ?? '',
            activo: proveedores[v.proveedorId]?.activo ?? false,
            precioCompra: v.precioCompra,
            preferido: v.preferido,
          ),
      ]);
    });
  }

  @override
  void dispose() {
    _nombre.dispose();
    _precio.dispose();
    super.dispose();
  }

  Future<void> _agregarProveedor() async {
    final elegido = await mostrarHojaInferior<_Fila>(
      context,
      titulo: 'Agregar proveedor',
      builder: (_) => _HojaAgregarProveedor(
          excluir: {for (final f in _filas) f.proveedorId}),
    );
    if (elegido == null) return;
    setState(() {
      elegido.preferido = _filas.isEmpty;
      _filas.add(elegido);
    });
  }

  void _marcarPreferido(_Fila fila) => setState(() {
        for (final f in _filas) {
          f.preferido = identical(f, fila);
        }
      });

  void _quitar(_Fila fila) => setState(() {
        _filas.remove(fila);
        if (fila.preferido && _filas.isNotEmpty) _filas.first.preferido = true;
      });

  Future<void> _guardar() async {
    if (_guardando) return;
    final nombre = _nombre.text.trim();
    final precio = parsearMonto(_precio.text);
    setState(() {
      _errorNombre = nombre.isEmpty ? 'Escribe un nombre' : null;
      _errorPrecio =
          (precio == null || precio <= 0) ? 'Escribe un precio válido' : null;
      _error = null;
    });
    if (_errorNombre != null || _errorPrecio != null) return;
    setState(() => _guardando = true);
    try {
      await ref.read(productoRepositoryProvider).guardarProducto(
            id: widget.producto?.id,
            nombre: nombre,
            precio: precio!,
            proveedores: [
              for (final f in _filas)
                ProveedorDeProducto(
                  proveedorId: f.proveedorId,
                  precioCompra: f.precioCompra,
                  preferido: f.preferido,
                ),
            ],
          );
      if (mounted) Navigator.of(context).pop(true);
    } on ArgumentError {
      if (mounted) {
        setState(() => _error = 'No se pudo guardar, revisa los proveedores');
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Widget _resumen() {
    final precio = parsearMonto(_precio.text);
    final preferido = _filas.where((f) => f.preferido).firstOrNull;
    if (preferido == null) {
      return const Text(
        'Sin costo: agrega un proveedor para ver la ganancia',
        key: Key('texto_resumen_costo'),
        style: TextStyle(color: ColoresApp.textoSecundario),
      );
    }
    final costo = preferido.precioCompra;
    if (precio == null || precio <= 0) {
      return Text('Costo ${formatoMoneda(costo)}',
          key: const Key('texto_resumen_costo'));
    }
    final ganancia = precio - costo;
    if (ganancia < 0) {
      return const Text(
        'Este producto se vende con pérdida',
        key: Key('texto_resumen_costo'),
        style: TextStyle(color: ColoresApp.sale, fontWeight: FontWeight.w600),
      );
    }
    final porcentaje = (ganancia * 100 / precio).round();
    return Text(
      'Costo ${formatoMoneda(costo)} · Ganas ${formatoMoneda(ganancia)} '
      'por unidad ($porcentaje %)',
      key: const Key('texto_resumen_costo'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            widget.producto == null ? 'Nuevo producto' : 'Editar producto'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            key: const Key('campo_nombre_producto'),
            controller: _nombre,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
                labelText: 'Nombre del producto', errorText: _errorNombre),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('campo_precio_producto'),
            controller: _precio,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
                labelText: 'Precio de venta', errorText: _errorPrecio),
          ),
          const SizedBox(height: 24),
          const Text('Proveedores',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          for (final f in _filas)
            Row(
              key: Key('fila_proveedor_${f.proveedorId}'),
              children: [
                Expanded(
                  child: Text(
                    f.nombre,
                    style: TextStyle(
                        color: f.activo ? null : ColoresApp.textoSecundario),
                  ),
                ),
                Text(formatoMoneda(f.precioCompra)),
                IconButton(
                  key: Key('preferido_${f.proveedorId}'),
                  tooltip: 'Preferido',
                  icon: Icon(
                      f.preferido ? Icons.star_rounded : Icons.star_border_rounded,
                      color: f.preferido ? ColoresApp.fiado : null),
                  onPressed: () => _marcarPreferido(f),
                ),
                IconButton(
                  key: Key('quitar_proveedor_${f.proveedorId}'),
                  tooltip: 'Quitar',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => _quitar(f),
                ),
              ],
            ),
          TextButton.icon(
            key: const Key('boton_agregar_proveedor'),
            onPressed: _agregarProveedor,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Agregar proveedor'),
          ),
          const SizedBox(height: 12),
          _resumen(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!,
                  style: const TextStyle(color: ColoresApp.sale)),
            ),
          const SizedBox(height: 24),
          BotonPrincipal(
            key: const Key('boton_guardar_producto'),
            texto: 'Guardar',
            onPressed: _guardando ? null : _guardar,
          ),
        ],
      ),
    );
  }
}

/// Elige un proveedor activo que el producto no tenga (o crea uno nuevo) y
/// su precio de compra. Devuelve la fila a agregar.
class _HojaAgregarProveedor extends ConsumerStatefulWidget {
  const _HojaAgregarProveedor({required this.excluir});

  final Set<int> excluir;

  @override
  ConsumerState<_HojaAgregarProveedor> createState() =>
      _HojaAgregarProveedorState();
}

class _HojaAgregarProveedorState extends ConsumerState<_HojaAgregarProveedor> {
  final _nuevo = TextEditingController();
  final _precio = TextEditingController();
  Proveedor? _elegido;
  String? _error;
  bool _guardando = false;

  @override
  void dispose() {
    _nuevo.dispose();
    _precio.dispose();
    super.dispose();
  }

  Future<void> _agregar() async {
    if (_guardando) return;
    final precio = parsearMonto(_precio.text);
    final nombreNuevo = _nuevo.text.trim();
    if (_elegido == null && nombreNuevo.isEmpty) {
      setState(() => _error = 'Elige o escribe un proveedor');
      return;
    }
    if (precio == null || precio <= 0) {
      setState(() => _error = 'Escribe un precio válido');
      return;
    }
    setState(() => _guardando = true);
    try {
      var proveedor = _elegido;
      if (proveedor == null) {
        final repo = ref.read(proveedorRepositoryProvider);
        final id = await repo.crear(nombre: nombreNuevo);
        proveedor = (await repo.todos()).firstWhere((p) => p.id == id);
      }
      if (!mounted) return;
      Navigator.of(context).pop(_Fila(
        proveedorId: proveedor.id,
        nombre: proveedor.nombre,
        activo: true,
        precioCompra: precio,
        preferido: false,
      ));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final disponibles = (ref.watch(proveedoresActivosProvider).valueOrNull ??
            const <Proveedor>[])
        .where((p) => !widget.excluir.contains(p.id))
        .toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (disponibles.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in disponibles)
                ChoiceChip(
                  key: Key('opcion_proveedor_${p.id}'),
                  label: Text(p.nombre),
                  selected: _elegido?.id == p.id,
                  onSelected: (_) => setState(() {
                    _elegido = p;
                    _nuevo.clear();
                    _error = null;
                  }),
                ),
            ],
          ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('campo_nuevo_proveedor'),
          controller: _nuevo,
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => setState(() => _elegido = null),
          decoration: const InputDecoration(labelText: 'Nuevo proveedor'),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('campo_precio_compra'),
          controller: _precio,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
              labelText: 'Precio de compra', errorText: _error),
        ),
        const SizedBox(height: 16),
        BotonPrincipal(
          key: const Key('boton_agregar_proveedor_producto'),
          texto: 'Agregar',
          onPressed: _guardando ? null : _agregar,
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Lista de productos**

En `lib/screens/configuracion/productos_screen.dart`:
- imports: quitar `editar_producto_dialog.dart`, `../../ui/hoja_inferior.dart`, `../../ui/boton_principal.dart` y `../../ui/monto.dart` si quedan sin uso; agregar `producto_screen.dart`.
- reemplazar `_agregar` y `_editar` por:

```dart
  Future<void> _abrir({Producto? producto}) async {
    final guardado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ProductoScreen(producto: producto)),
    );
    if (guardado == true && mounted) avisar(context, 'Producto guardado');
  }
```

  y usar `onPressed: () => _abrir()` en el botón flotante y `onTap: () => _abrir(producto: p)` en cada producto.
- en `build`: `final costos = ref.watch(costosProductosProvider).valueOrNull ?? const <int, int>{};` y el subtítulo de cada activo:

```dart
                          subtitle: Text(costos[p.id] == null
                              ? '${formatoMoneda(p.precio)} · sin costo'
                              : '${formatoMoneda(p.precio)} · gana '
                                  '${formatoMoneda(p.precio - costos[p.id]!)}'),
```

- borrar las clases `_FormularioProducto` y `_FormularioProductoState`.

Borrar `lib/screens/configuracion/editar_producto_dialog.dart` (se hace con `git rm` en el commit).

- [ ] **Step 5: Correr y ver que pasa**

Run: `flutter analyze` y `flutter test test/screens/configuracion`
Expected: "No issues found!" y PASS.

- [ ] **Step 6: Commit**

```bash
git rm lib/screens/configuracion/editar_producto_dialog.dart
git add lib/screens/configuracion test/screens/configuracion/productos_screen_test.dart
git commit -m "Edit products on a full screen with suppliers, preferred cost and profit"
```

---

### Task 9: Ganancia en Reportes

**Files:**
- Modify: `lib/screens/reportes/reportes_screen.dart` (`_Contenido`, sección "Productos más vendidos")
- Modify: `test/screens/reportes/reportes_screen_test.dart`

**Interfaces:**
- Consumes: `Reporte.gananciaProductos`, `vendidoSinCosto`, `hayCostos`, `ProductoVendido.ganancia` (Task 6); `ProductoRepository.guardarProducto`, `ProveedorDeProducto` (Task 5); `ProveedorRepository.crear` (Task 4).
- Produces: llaves `texto_ganancia_productos`, `texto_sin_costo`.

- [ ] **Step 1: Escribir la prueba que falla**

En `test/screens/reportes/reportes_screen_test.dart` agregar imports `package:app_ventas/repositories/producto_repository.dart` y `package:app_ventas/repositories/proveedor_repository.dart`, y dentro de `main()`:

```dart
  testWidgets('muestra la ganancia en productos y lo vendido sin costo',
      (tester) async {
    final postobon = await ProveedorRepository(db).crear(nombre: 'Postobón');
    final arepa = await ProductoRepository(db).guardarProducto(
      nombre: 'Arepa',
      precio: 3500,
      proveedores: [
        ProveedorDeProducto(
            proveedorId: postobon, precioCompra: 2500, preferido: true),
      ],
    );
    await VentaRepository(db).registrarVenta(
      monto: 12000,
      esFiado: false,
      usuarioId: ana,
      fecha: DateTime(2026, 10, 6, 9),
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
    await montar(tester);

    expect(find.text(r'Ganancia en productos: $2.000'), findsOneWidget);
    expect(find.text(r'1. Arepa · 2 u · $7.000 · gana $2.000'), findsOneWidget);
    expect(find.text(r'$5.000 vendidos sin costo registrado'), findsOneWidget);
  });
```

- [ ] **Step 2: Correr y ver que falla**

Run: `flutter test test/screens/reportes/reportes_screen_test.dart`
Expected: FAIL (los textos de ganancia no existen).

- [ ] **Step 3: Implementar**

En `lib/screens/reportes/reportes_screen.dart`, dentro del `else ...[` de "Productos más vendidos":

- como primer elemento:

```dart
          if (r.hayCostos)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Ganancia en productos: ${formatoMoneda(r.gananciaProductos)}',
                key: const Key('texto_ganancia_productos'),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
```

- en el texto de cada fila del ranking, reemplazar

```dart
                '${i + 1}. ${p.nombre} · ${p.unidades} u · '
                '${formatoMoneda(p.dinero)}',
```

  por

```dart
                '${i + 1}. ${p.nombre} · ${p.unidades} u · '
                '${formatoMoneda(p.dinero)}'
                '${p.ganancia == null ? '' : ' · gana ${formatoMoneda(p.ganancia!)}'}',
```

- como último elemento (después del bloque de "Otros montos"):

```dart
          if (r.vendidoSinCosto > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${formatoMoneda(r.vendidoSinCosto)} vendidos sin costo '
                'registrado',
                key: const Key('texto_sin_costo'),
                style: gris,
              ),
            ),
```

- [ ] **Step 4: Correr y ver que pasa**

Run: `flutter test test/screens/reportes`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/screens/reportes/reportes_screen.dart test/screens/reportes/reportes_screen_test.dart
git commit -m "Show product profit and sales without cost in Reportes"
```

---

### Task 10: Verificación final

**Files:**
- Modify: `docs/superpowers/specs/2026-10-07-vecitienda-catalogo-proveedores-design.md` (línea `**Estado:**`)
- Modify: `docs/hoja-de-ruta.md`

- [ ] **Step 1: Análisis y suite completa**

Run: `flutter analyze` y `flutter test`
Expected: "No issues found!" y todas las pruebas pasan.

- [ ] **Step 2: Compilar**

Run: `flutter build apk --debug`
Expected: "Built build\app\outputs\flutter-apk\app-debug.apk".

- [ ] **Step 3: Documentación**

- Especificación: `**Estado:** Diseño aprobado, pendiente de plan` → `**Estado:** Implementado (falta el recorrido manual en un celular real)`.
- `docs/hoja-de-ruta.md`: en "Hecho" agregar "- Fase 4A — catálogo, proveedores, ganancia por producto y nombre de la tienda."; en "En curso" dejar "- Siguiente: Fase 4B (existencias y \"Por pedir\")."; en "Pendiente de verificar" agregar ", catálogo y proveedores (4A)" al final de la lista.

- [ ] **Step 4: Commit**

```bash
git add docs/superpowers/specs/2026-10-07-vecitienda-catalogo-proveedores-design.md docs/hoja-de-ruta.md
git commit -m "Mark Fase 4A as implemented"
```
