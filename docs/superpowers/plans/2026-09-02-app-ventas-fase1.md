# App de Ventas — Fase 1 (núcleo local) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Flutter/Android app core described in the Fase 1 spec: multi-user (admin/vendedor) PIN login, quick sale registration, fiado (credit) tracking, expenses, and a daily summary — all running 100% offline against a local SQLite database.

**Architecture:** Flutter app with three layers: UI screens (Material widgets) → Riverpod providers (state) → repositories (one per entity, wrapping Drift queries) → Drift/SQLite (local persistence, single source of truth). No network, no auth server — "login" is a local PIN check against a `Usuario` row.

**Tech Stack:** Flutter (stable channel), Dart, `flutter_riverpod`/`riverpod` for state, `drift` + `sqlite3_flutter_libs` + `path_provider` for persistence, `crypto` for PIN hashing, `build_runner`/`drift_dev` for codegen.

**Spec:** `docs/superpowers/specs/2026-09-02-app-ventas-fase1-design.md`

## Global Constraints

- All monetary amounts are stored and passed around as **integer COP pesos** (no decimals, no floating point) — matches the spec's "moneda COP sin decimales" requirement.
- No network calls anywhere in this phase. Every repository talks only to the local Drift database.
- UI text is in **Spanish (Colombia)**, matching the spec's target user.
- PIN is always exactly **4 numeric digits**, hashed with SHA-256 before storage (`lib/util/pin_hash.dart`) — never stored or logged in plaintext.
- Every Drift table's row class name is pinned explicitly via `@DataClassName(...)` (see Task 2) so class names never depend on Drift's pluralization heuristics.
- Admin-only screens/actions (product catalog, user management) must be **hidden**, not just disabled, when the active session's role is `vendedor` — this is a testable requirement (Task 16).
- Every repository and provider file lives under `lib/`, mirrored 1:1 by a test file under `test/` with the same relative path (e.g. `lib/repositories/fiado_repository.dart` ↔ `test/repositories/fiado_repository_test.dart`).

---

## Environment setup already completed (do not repeat)

This was done interactively before this plan was written — verify it's still true at the start of Task 1, don't redo it from scratch:

- Flutter SDK 3.47.2 installed at `C:\src\flutter`, added to the user `PATH`.
- Android Studio + Android SDK installed at `%LOCALAPPDATA%\Android\Sdk` (platform-tools, `platforms;android-35`, `platforms;android-36`, `build-tools;35.0.0`, `build-tools;28.0.3`), all licenses accepted.
- JDK 21 installed at `C:\Program Files\Microsoft\jdk-21.0.12.101-hotspot`, `JAVA_HOME` set at the user level.
- `flutter doctor` shows the Android toolchain as fully satisfied (only "Visual Studio - develop Windows apps" is missing, which is irrelevant since we don't target Windows desktop).
- A known-good `sqlite3.dll` (v3.53.4, Windows x64) was downloaded from `https://www.sqlite.org/2026/sqlite-dll-win-x64-3530400.zip` and extracted; Task 1 places it at `test/support/sqlite3.dll` so `flutter test` can load Drift's native SQLite backend on this Windows host (this is a well-known Drift/Windows testing gap: `sqlite3_flutter_libs` only bundles the DLL into a *built app*, not into the bare Dart VM that runs `flutter test`).
- If any Task 1 verification step fails (e.g. `flutter doctor` now shows new issues), stop and re-diagnose rather than assuming the plan's code is at fault — the issue is almost certainly environment drift, not this plan.

There is **no Android emulator or physical device connected**. This plan verifies behavior with `flutter analyze`, `flutter test` (unit + widget tests), and `flutter build apk --debug` (compile-only check). Manually trying the app on a phone/emulator is a follow-up the user does after this plan is executed, not part of it.

---

### Task 1: Scaffold the Flutter project and dependencies

**Files:**
- Create: entire Flutter project at repo root (`flutter create` generates `lib/main.dart`, `pubspec.yaml`, `android/`, etc.)
- Modify: `pubspec.yaml` (add dependencies)
- Create: `test/support/sqlite3.dll` (vendored native lib for host testing — gitignored, already present from environment setup)
- Create: `test/flutter_test_config.dart`
- Create: `analysis_options.yaml` (Flutter default, keep as generated)

**Interfaces:**
- Produces: a runnable Flutter project (`flutter analyze` and `flutter test` both exit 0 on the default counter-app template) with all packages this plan's later tasks depend on already resolved.

- [ ] **Step 1: Create the Flutter project**

Run from the repo root (`D:\personales\proyectos\APP_VENTAS`), which currently only contains the source `.docx`, `.gitignore`, and `docs/`:

```bash
flutter create --org com.appventas --project-name app_ventas .
```

This scaffolds `lib/main.dart`, `pubspec.yaml`, `android/`, `test/widget_test.dart`, etc. directly into the repo root. It will not overwrite `docs/`, `.gitignore`, or the `.docx`.

- [ ] **Step 2: Add dependencies**

```bash
flutter pub add drift sqlite3_flutter_libs path_provider path flutter_riverpod riverpod crypto
flutter pub add -d drift_dev build_runner
```

- [ ] **Step 3: Verify the default template still builds and analyzes clean**

Run: `flutter analyze`
Expected: `No issues found!`

Run: `flutter test`
Expected: the generated `test/widget_test.dart` passes (1 test, counter increments). If it references `MyApp`/counter code we're about to delete, that's fine — we replace it in Task 16; for now it must pass as generated.

- [ ] **Step 4: Vendor the SQLite native library for Windows host testing**

```bash
mkdir -p test/support
curl -sSL -o /tmp/sqlite3-dll.zip "https://www.sqlite.org/2026/sqlite-dll-win-x64-3530400.zip"
unzip -o /tmp/sqlite3-dll.zip sqlite3.dll -d test/support
rm /tmp/sqlite3-dll.zip
```

Verify: `test/support/sqlite3.dll` exists and is ~3.2 MB. Add `test/support/sqlite3.dll` to `.gitignore` (it's a re-downloadable binary, not source).

- [ ] **Step 5: Create the test bootstrap that loads the vendored DLL**

Create `test/flutter_test_config.dart`:

```dart
import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqlite3/open.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  if (Platform.isWindows) {
    open.overrideFor(
      OperatingSystem.windows,
      () => DynamicLibrary.open(
        p.join(Directory.current.path, 'test', 'support', 'sqlite3.dll'),
      ),
    );
  }
  await testMain();
}
```

Flutter automatically runs this file's `testExecutable` wrapper around every test in `test/` — no per-file import needed.

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml pubspec.lock lib android ios test analysis_options.yaml .metadata .gitignore
git commit -m "Scaffold Flutter project with Drift/Riverpod dependencies"
```

---

### Task 2: Drift database schema

**Files:**
- Create: `lib/data/database.dart`
- Test: `test/data/database_test.dart`

**Interfaces:**
- Produces: `AppDatabase` class with tables `Usuarios`/`Usuario`, `Productos`/`Producto`, `Clientes`/`Cliente`, `Ventas`/`Venta`, `PagosFiado`/`PagoFiado`, `Gastos`/`Gasto` (table class name / row class name, via `@DataClassName`), plus their generated `*Companion` insert/update classes. `AppDatabase([QueryExecutor? executor])` — passing an explicit executor is how tests use an in-memory DB; omitting it opens the real on-device file.

- [ ] **Step 1: Write the schema**

Create `lib/data/database.dart`:

```dart
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'database.g.dart';

@DataClassName('Usuario')
class Usuarios extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get nombre => text()();
  TextColumn get rol => text()(); // 'admin' | 'vendedor'
  TextColumn get pinHash => text()();
}

@DataClassName('Producto')
class Productos extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get nombre => text()();
  IntColumn get precio => integer()(); // COP, entero
  BoolColumn get activo => boolean().withDefault(const Constant(true))();
}

@DataClassName('Cliente')
class Clientes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get nombre => text()();
  TextColumn get telefono => text().nullable()();
  TextColumn get notas => text().nullable()();
}

@DataClassName('Venta')
class Ventas extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get monto => integer()();
  IntColumn get productoId => integer().nullable().references(Productos, #id)();
  DateTimeColumn get fecha => dateTime()();
  BoolColumn get esFiado => boolean().withDefault(const Constant(false))();
  IntColumn get clienteId => integer().nullable().references(Clientes, #id)();
  IntColumn get usuarioId => integer().references(Usuarios, #id)();
}

@DataClassName('PagoFiado')
class PagosFiado extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get clienteId => integer().references(Clientes, #id)();
  IntColumn get monto => integer()();
  DateTimeColumn get fecha => dateTime()();
  IntColumn get usuarioId => integer().references(Usuarios, #id)();
}

@DataClassName('Gasto')
class Gastos extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get monto => integer()();
  TextColumn get descripcion => text().nullable()();
  DateTimeColumn get fecha => dateTime()();
  IntColumn get usuarioId => integer().references(Usuarios, #id)();
}

@DriftDatabase(
  tables: [Usuarios, Productos, Clientes, Ventas, PagosFiado, Gastos],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return LazyDatabase(() async {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, 'app_ventas.sqlite'));
      return NativeDatabase.createInBackground(file);
    });
  }
}
```

- [ ] **Step 2: Generate code**

```bash
dart run build_runner build --delete-conflicting-outputs
```

Expected: `lib/data/database.g.dart` is generated with no errors.

- [ ] **Step 3: Write a test proving the schema is queryable**

Create `test/data/database_test.dart`:

```dart
import 'package:app_ventas/data/database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('creates tables and can insert/read a usuario', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final id = await db.into(db.usuarios).insert(
          UsuariosCompanion.insert(
            nombre: 'Admin',
            rol: 'admin',
            pinHash: 'hash',
          ),
        );

    final usuarios = await db.select(db.usuarios).get();
    expect(usuarios, hasLength(1));
    expect(usuarios.single.id, id);
    expect(usuarios.single.nombre, 'Admin');
  });
}
```

- [ ] **Step 4: Run the test**

Run: `flutter test test/data/database_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/data test/data
git commit -m "Add Drift database schema"
```

---

### Task 3: Shared utilities — currency formatting, PIN hashing, day boundaries

**Files:**
- Create: `lib/util/formato_moneda.dart`
- Create: `lib/util/pin_hash.dart`
- Create: `lib/util/fecha_util.dart`
- Test: `test/util/formato_moneda_test.dart`
- Test: `test/util/pin_hash_test.dart`
- Test: `test/util/fecha_util_test.dart`

**Interfaces:**
- Produces: `String formatoMoneda(int montoEnPesos)`, `String hashPin(String pin)`, `DateTime inicioDelDia(DateTime dia)`, `DateTime finDelDia(DateTime dia)` — used by every repository and screen from Task 4 onward.

- [ ] **Step 1: Write the failing tests**

Create `test/util/formato_moneda_test.dart`:

```dart
import 'package:app_ventas/util/formato_moneda.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formatea montos con separador de miles y símbolo de pesos', () {
    expect(formatoMoneda(0), r'$0');
    expect(formatoMoneda(3000), r'$3.000');
    expect(formatoMoneda(1000000), r'$1.000.000');
    expect(formatoMoneda(999), r'$999');
  });
}
```

Create `test/util/pin_hash_test.dart`:

```dart
import 'package:app_ventas/util/pin_hash.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hashPin is deterministic and never returns the raw pin', () {
    final hash = hashPin('1234');
    expect(hash, hashPin('1234'));
    expect(hash, isNot(contains('1234')));
  });

  test('hashPin differs for different pins', () {
    expect(hashPin('1234'), isNot(hashPin('4321')));
  });
}
```

Create `test/util/fecha_util_test.dart`:

```dart
import 'package:app_ventas/util/fecha_util.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('inicioDelDia trunca a medianoche', () {
    final dia = DateTime(2026, 9, 2, 15, 30, 45);
    expect(inicioDelDia(dia), DateTime(2026, 9, 2));
  });

  test('finDelDia es justo antes de medianoche siguiente', () {
    final dia = DateTime(2026, 9, 2, 15, 30, 45);
    final fin = finDelDia(dia);
    expect(fin.isAfter(DateTime(2026, 9, 2, 23, 59, 59)), isTrue);
    expect(fin.isBefore(DateTime(2026, 9, 3)), isTrue);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/util/`
Expected: FAIL — files under `lib/util/` don't exist yet.

- [ ] **Step 3: Implement**

Create `lib/util/formato_moneda.dart`:

```dart
String formatoMoneda(int montoEnPesos) {
  final esNegativo = montoEnPesos < 0;
  final digitos = montoEnPesos.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digitos.length; i++) {
    if (i > 0 && (digitos.length - i) % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(digitos[i]);
  }
  final signo = esNegativo ? '-' : '';
  return '$signo\$$buffer';
}
```

Create `lib/util/pin_hash.dart`:

```dart
import 'dart:convert';

import 'package:crypto/crypto.dart';

String hashPin(String pin) => sha256.convert(utf8.encode(pin)).toString();
```

Create `lib/util/fecha_util.dart`:

```dart
DateTime inicioDelDia(DateTime dia) => DateTime(dia.year, dia.month, dia.day);

DateTime finDelDia(DateTime dia) =>
    DateTime(dia.year, dia.month, dia.day, 23, 59, 59, 999);
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/util/`
Expected: PASS (7 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/util test/util
git commit -m "Add currency formatting, PIN hashing, and day-boundary utils"
```

---

### Task 4: Shared UI widgets — numeric PIN keypad and quick-amount grid

**Files:**
- Create: `lib/widgets/teclado_numerico.dart`
- Create: `lib/widgets/monto_rapido_grid.dart`
- Test: `test/widgets/teclado_numerico_test.dart`
- Test: `test/widgets/monto_rapido_grid_test.dart`

**Interfaces:**
- Consumes: `formatoMoneda` from `lib/util/formato_moneda.dart` (Task 3).
- Produces: `TecladoNumerico({required void Function(String digito) onDigito, required VoidCallback onBorrar})`; `MontoRapidoGrid({required void Function(int monto) onSeleccionar})` with `static const montos = [1000, 2000, 5000, 10000, 20000, 50000]`. Both are used by login and sale screens from Task 6 onward.

- [ ] **Step 1: Write the failing tests**

Create `test/widgets/teclado_numerico_test.dart`:

```dart
import 'package:app_ventas/widgets/teclado_numerico.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('tapping a digit calls onDigito with that digit', (tester) async {
    String? digitoPresionado;
    await tester.pumpWidget(MaterialApp(
      home: TecladoNumerico(
        onDigito: (d) => digitoPresionado = d,
        onBorrar: () {},
      ),
    ));

    await tester.tap(find.byKey(const Key('tecla_5')));
    expect(digitoPresionado, '5');
  });

  testWidgets('tapping the backspace key calls onBorrar', (tester) async {
    var borrado = false;
    await tester.pumpWidget(MaterialApp(
      home: TecladoNumerico(
        onDigito: (_) {},
        onBorrar: () => borrado = true,
      ),
    ));

    await tester.tap(find.byKey(const Key('tecla_⌫')));
    expect(borrado, isTrue);
  });
}
```

Create `test/widgets/monto_rapido_grid_test.dart`:

```dart
import 'package:app_ventas/widgets/monto_rapido_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('tapping a quick amount calls onSeleccionar with that amount',
      (tester) async {
    int? montoElegido;
    await tester.pumpWidget(MaterialApp(
      home: MontoRapidoGrid(onSeleccionar: (m) => montoElegido = m),
    ));

    await tester.tap(find.byKey(const Key('monto_rapido_5000')));
    expect(montoElegido, 5000);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/widgets/`
Expected: FAIL — widgets don't exist yet.

- [ ] **Step 3: Implement**

Create `lib/widgets/teclado_numerico.dart`:

```dart
import 'package:flutter/material.dart';

class TecladoNumerico extends StatelessWidget {
  const TecladoNumerico({
    super.key,
    required this.onDigito,
    required this.onBorrar,
  });

  final void Function(String digito) onDigito;
  final VoidCallback onBorrar;

  static const _filas = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
    ['', '0', '⌫'],
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: _filas.map((fila) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: fila.map((texto) {
            if (texto.isEmpty) {
              return const SizedBox(width: 72, height: 72);
            }
            return Padding(
              padding: const EdgeInsets.all(4),
              child: SizedBox(
                width: 64,
                height: 64,
                child: ElevatedButton(
                  key: Key('tecla_$texto'),
                  onPressed: () => texto == '⌫' ? onBorrar() : onDigito(texto),
                  child: Text(texto, style: const TextStyle(fontSize: 22)),
                ),
              ),
            );
          }).toList(),
        );
      }).toList(),
    );
  }
}
```

Create `lib/widgets/monto_rapido_grid.dart`:

```dart
import 'package:flutter/material.dart';

import '../util/formato_moneda.dart';

class MontoRapidoGrid extends StatelessWidget {
  const MontoRapidoGrid({super.key, required this.onSeleccionar});

  final void Function(int monto) onSeleccionar;

  static const montos = [1000, 2000, 5000, 10000, 20000, 50000];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: montos.map((monto) {
        return ElevatedButton(
          key: Key('monto_rapido_$monto'),
          onPressed: () => onSeleccionar(monto),
          child: Text(formatoMoneda(monto)),
        );
      }).toList(),
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/widgets/`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/widgets test/widgets
git commit -m "Add shared numeric keypad and quick-amount grid widgets"
```

---

### Task 5: UsuarioRepository (accounts, PIN verification)

**Files:**
- Create: `lib/repositories/usuario_repository.dart`
- Test: `test/repositories/usuario_repository_test.dart`

**Interfaces:**
- Consumes: `AppDatabase` (Task 2), `hashPin` (Task 3).
- Produces: `UsuarioRepository(AppDatabase db)` with:
  - `Future<List<Usuario>> listarUsuarios()`
  - `Future<bool> existeAlgunUsuario()`
  - `Future<int> crearUsuario({required String nombre, required String rol, required String pin})`
  - `Future<Usuario?> verificarPin(int usuarioId, String pin)`
  - `Future<void> resetearPin(int usuarioId, String nuevoPin)`

- [ ] **Step 1: Write the failing test**

Create `test/repositories/usuario_repository_test.dart`:

```dart
import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/repositories/usuario_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late UsuarioRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = UsuarioRepository(db);
  });

  tearDown(() => db.close());

  test('no usuarios inicialmente', () async {
    expect(await repo.existeAlgunUsuario(), isFalse);
  });

  test('crear usuario y listar', () async {
    await repo.crearUsuario(nombre: 'Ana', rol: 'admin', pin: '1234');
    final usuarios = await repo.listarUsuarios();
    expect(usuarios, hasLength(1));
    expect(usuarios.single.nombre, 'Ana');
    expect(usuarios.single.rol, 'admin');
    expect(await repo.existeAlgunUsuario(), isTrue);
  });

  test('verificarPin acepta el PIN correcto y rechaza uno incorrecto', () async {
    final id = await repo.crearUsuario(nombre: 'Ana', rol: 'admin', pin: '1234');

    expect((await repo.verificarPin(id, '1234'))?.nombre, 'Ana');
    expect(await repo.verificarPin(id, '0000'), isNull);
  });

  test('resetearPin cambia el PIN vigente', () async {
    final id = await repo.crearUsuario(nombre: 'Ana', rol: 'admin', pin: '1234');
    await repo.resetearPin(id, '9999');

    expect(await repo.verificarPin(id, '1234'), isNull);
    expect((await repo.verificarPin(id, '9999'))?.nombre, 'Ana');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/repositories/usuario_repository_test.dart`
Expected: FAIL — `lib/repositories/usuario_repository.dart` doesn't exist.

- [ ] **Step 3: Implement**

Create `lib/repositories/usuario_repository.dart`:

```dart
import 'package:drift/drift.dart';

import '../data/database.dart';
import '../util/pin_hash.dart';

class UsuarioRepository {
  UsuarioRepository(this._db);

  final AppDatabase _db;

  Future<List<Usuario>> listarUsuarios() => _db.select(_db.usuarios).get();

  Future<bool> existeAlgunUsuario() async {
    final usuarios = await listarUsuarios();
    return usuarios.isNotEmpty;
  }

  Future<int> crearUsuario({
    required String nombre,
    required String rol,
    required String pin,
  }) {
    return _db.into(_db.usuarios).insert(
          UsuariosCompanion.insert(
            nombre: nombre,
            rol: rol,
            pinHash: hashPin(pin),
          ),
        );
  }

  Future<Usuario?> verificarPin(int usuarioId, String pin) async {
    final usuario = await (_db.select(_db.usuarios)
          ..where((u) => u.id.equals(usuarioId)))
        .getSingleOrNull();
    if (usuario == null) return null;
    return usuario.pinHash == hashPin(pin) ? usuario : null;
  }

  Future<void> resetearPin(int usuarioId, String nuevoPin) {
    return (_db.update(_db.usuarios)..where((u) => u.id.equals(usuarioId)))
        .write(UsuariosCompanion(pinHash: Value(hashPin(nuevoPin))));
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/repositories/usuario_repository_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/repositories/usuario_repository.dart test/repositories/usuario_repository_test.dart
git commit -m "Add UsuarioRepository with PIN verification"
```

---

### Task 6: ProductoRepository and ClienteRepository

**Files:**
- Create: `lib/repositories/producto_repository.dart`
- Create: `lib/repositories/cliente_repository.dart`
- Test: `test/repositories/producto_repository_test.dart`
- Test: `test/repositories/cliente_repository_test.dart`

**Interfaces:**
- Consumes: `AppDatabase` (Task 2).
- Produces: `ProductoRepository(AppDatabase db)` with:
  - `Stream<List<Producto>> observarProductosActivos()`
  - `Future<List<Producto>> listarTodos()`
  - `Future<int> crearProducto({required String nombre, required int precio})`
  - `Future<void> actualizarProducto(int id, {String? nombre, int? precio})`
  - `Future<void> desactivarProducto(int id)`
- Produces: `ClienteRepository(AppDatabase db)` with:
  - `Future<List<Cliente>> listarClientes()`
  - `Future<int> crearCliente({required String nombre, String? telefono})`
  - `Future<Cliente?> obtenerCliente(int id)`

- [ ] **Step 1: Write the failing tests**

Create `test/repositories/producto_repository_test.dart`:

```dart
import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/repositories/producto_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late ProductoRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ProductoRepository(db);
  });

  tearDown(() => db.close());

  test('crearProducto queda activo por defecto y aparece en observarProductosActivos',
      () async {
    await repo.crearProducto(nombre: 'Arepa', precio: 3000);

    final activos = await repo.observarProductosActivos().first;
    expect(activos, hasLength(1));
    expect(activos.single.nombre, 'Arepa');
    expect(activos.single.precio, 3000);
    expect(activos.single.activo, isTrue);
  });

  test('desactivarProducto lo saca de observarProductosActivos pero sigue en listarTodos',
      () async {
    final id = await repo.crearProducto(nombre: 'Arepa', precio: 3000);
    await repo.desactivarProducto(id);

    expect(await repo.observarProductosActivos().first, isEmpty);
    expect(await repo.listarTodos(), hasLength(1));
  });

  test('actualizarProducto cambia nombre y precio', () async {
    final id = await repo.crearProducto(nombre: 'Arepa', precio: 3000);
    await repo.actualizarProducto(id, nombre: 'Arepa con queso', precio: 4000);

    final producto = (await repo.listarTodos()).single;
    expect(producto.nombre, 'Arepa con queso');
    expect(producto.precio, 4000);
  });
}
```

Create `test/repositories/cliente_repository_test.dart`:

```dart
import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/repositories/cliente_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late ClienteRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ClienteRepository(db);
  });

  tearDown(() => db.close());

  test('crearCliente y obtenerCliente', () async {
    final id = await repo.crearCliente(nombre: 'Don Pedro', telefono: '3001234567');
    final cliente = await repo.obtenerCliente(id);

    expect(cliente?.nombre, 'Don Pedro');
    expect(cliente?.telefono, '3001234567');
  });

  test('crearCliente sin teléfono deja el campo nulo', () async {
    final id = await repo.crearCliente(nombre: 'Doña Rosa');
    final cliente = await repo.obtenerCliente(id);

    expect(cliente?.telefono, isNull);
  });

  test('listarClientes devuelve todos los clientes creados', () async {
    await repo.crearCliente(nombre: 'Don Pedro');
    await repo.crearCliente(nombre: 'Doña Rosa');

    expect(await repo.listarClientes(), hasLength(2));
  });

  test('obtenerCliente con id inexistente devuelve null', () async {
    expect(await repo.obtenerCliente(999), isNull);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/repositories/producto_repository_test.dart test/repositories/cliente_repository_test.dart`
Expected: FAIL — repositories don't exist.

- [ ] **Step 3: Implement**

Create `lib/repositories/producto_repository.dart`:

```dart
import 'package:drift/drift.dart';

import '../data/database.dart';

class ProductoRepository {
  ProductoRepository(this._db);

  final AppDatabase _db;

  Stream<List<Producto>> observarProductosActivos() {
    return (_db.select(_db.productos)..where((p) => p.activo.equals(true)))
        .watch();
  }

  Future<List<Producto>> listarTodos() => _db.select(_db.productos).get();

  Future<int> crearProducto({required String nombre, required int precio}) {
    return _db.into(_db.productos).insert(
          ProductosCompanion.insert(nombre: nombre, precio: precio),
        );
  }

  Future<void> actualizarProducto(int id, {String? nombre, int? precio}) {
    return (_db.update(_db.productos)..where((p) => p.id.equals(id))).write(
      ProductosCompanion(
        nombre: nombre != null ? Value(nombre) : const Value.absent(),
        precio: precio != null ? Value(precio) : const Value.absent(),
      ),
    );
  }

  Future<void> desactivarProducto(int id) {
    return (_db.update(_db.productos)..where((p) => p.id.equals(id)))
        .write(const ProductosCompanion(activo: Value(false)));
  }
}
```

Create `lib/repositories/cliente_repository.dart`:

```dart
import 'package:drift/drift.dart';

import '../data/database.dart';

class ClienteRepository {
  ClienteRepository(this._db);

  final AppDatabase _db;

  Future<List<Cliente>> listarClientes() => _db.select(_db.clientes).get();

  Future<int> crearCliente({required String nombre, String? telefono}) {
    return _db.into(_db.clientes).insert(
          ClientesCompanion.insert(
            nombre: nombre,
            telefono: Value(telefono),
          ),
        );
  }

  Future<Cliente?> obtenerCliente(int id) {
    return (_db.select(_db.clientes)..where((c) => c.id.equals(id)))
        .getSingleOrNull();
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/repositories/producto_repository_test.dart test/repositories/cliente_repository_test.dart`
Expected: PASS (7 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/repositories/producto_repository.dart lib/repositories/cliente_repository.dart test/repositories/producto_repository_test.dart test/repositories/cliente_repository_test.dart
git commit -m "Add ProductoRepository and ClienteRepository"
```

---

### Task 7: VentaRepository and GastoRepository

**Files:**
- Create: `lib/repositories/venta_repository.dart`
- Create: `lib/repositories/gasto_repository.dart`
- Test: `test/repositories/venta_repository_test.dart`
- Test: `test/repositories/gasto_repository_test.dart`

**Interfaces:**
- Consumes: `AppDatabase` (Task 2), `inicioDelDia`/`finDelDia` (Task 3).
- Produces: `VentaRepository(AppDatabase db)` with:
  - `Future<int> registrarVenta({required int monto, int? productoId, required bool esFiado, int? clienteId, required int usuarioId, DateTime? fecha})`
  - `Future<List<Venta>> ventasDelDia(DateTime dia, {int? usuarioId})`
- Produces: `GastoRepository(AppDatabase db)` with:
  - `Future<int> registrarGasto({required int monto, String? descripcion, required int usuarioId, DateTime? fecha})`
  - `Future<List<Gasto>> gastosDelDia(DateTime dia, {int? usuarioId})`

- [ ] **Step 1: Write the failing tests**

Create `test/repositories/venta_repository_test.dart`:

```dart
import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/repositories/venta_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late VentaRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = VentaRepository(db);
  });

  tearDown(() => db.close());

  Future<int> crearUsuario() {
    return db.into(db.usuarios).insert(
          UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'x'),
        );
  }

  test('registrarVenta guarda una venta de contado', () async {
    final usuarioId = await crearUsuario();
    await repo.registrarVenta(
      monto: 5000,
      esFiado: false,
      usuarioId: usuarioId,
      fecha: DateTime(2026, 9, 2, 10),
    );

    final ventas = await repo.ventasDelDia(DateTime(2026, 9, 2));
    expect(ventas, hasLength(1));
    expect(ventas.single.monto, 5000);
    expect(ventas.single.esFiado, isFalse);
  });

  test('ventasDelDia solo trae ventas de ese día', () async {
    final usuarioId = await crearUsuario();
    await repo.registrarVenta(
      monto: 1000,
      esFiado: false,
      usuarioId: usuarioId,
      fecha: DateTime(2026, 9, 1, 23, 59),
    );
    await repo.registrarVenta(
      monto: 2000,
      esFiado: false,
      usuarioId: usuarioId,
      fecha: DateTime(2026, 9, 2, 0, 1),
    );

    final ventas = await repo.ventasDelDia(DateTime(2026, 9, 2));
    expect(ventas, hasLength(1));
    expect(ventas.single.monto, 2000);
  });

  test('ventasDelDia filtra por usuarioId cuando se indica', () async {
    final vendedor1 = await crearUsuario();
    final vendedor2 = await db.into(db.usuarios).insert(
          UsuariosCompanion.insert(nombre: 'Beto', rol: 'vendedor', pinHash: 'y'),
        );
    final dia = DateTime(2026, 9, 2, 10);
    await repo.registrarVenta(
        monto: 1000, esFiado: false, usuarioId: vendedor1, fecha: dia);
    await repo.registrarVenta(
        monto: 2000, esFiado: false, usuarioId: vendedor2, fecha: dia);

    final ventasVendedor1 = await repo.ventasDelDia(dia, usuarioId: vendedor1);
    expect(ventasVendedor1, hasLength(1));
    expect(ventasVendedor1.single.monto, 1000);
  });
}
```

Create `test/repositories/gasto_repository_test.dart`:

```dart
import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/repositories/gasto_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late GastoRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = GastoRepository(db);
  });

  tearDown(() => db.close());

  Future<int> crearUsuario() {
    return db.into(db.usuarios).insert(
          UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'x'),
        );
  }

  test('registrarGasto y gastosDelDia', () async {
    final usuarioId = await crearUsuario();
    await repo.registrarGasto(
      monto: 20000,
      descripcion: 'Bolsas',
      usuarioId: usuarioId,
      fecha: DateTime(2026, 9, 2, 9),
    );

    final gastos = await repo.gastosDelDia(DateTime(2026, 9, 2));
    expect(gastos, hasLength(1));
    expect(gastos.single.monto, 20000);
    expect(gastos.single.descripcion, 'Bolsas');
  });

  test('registrarGasto sin descripción deja el campo nulo', () async {
    final usuarioId = await crearUsuario();
    await repo.registrarGasto(
      monto: 5000,
      usuarioId: usuarioId,
      fecha: DateTime(2026, 9, 2, 9),
    );

    expect((await repo.gastosDelDia(DateTime(2026, 9, 2))).single.descripcion, isNull);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/repositories/venta_repository_test.dart test/repositories/gasto_repository_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

Create `lib/repositories/venta_repository.dart`:

```dart
import 'package:drift/drift.dart';

import '../data/database.dart';
import '../util/fecha_util.dart';

class VentaRepository {
  VentaRepository(this._db);

  final AppDatabase _db;

  Future<int> registrarVenta({
    required int monto,
    int? productoId,
    required bool esFiado,
    int? clienteId,
    required int usuarioId,
    DateTime? fecha,
  }) {
    return _db.into(_db.ventas).insert(
          VentasCompanion.insert(
            monto: monto,
            productoId: Value(productoId),
            fecha: fecha ?? DateTime.now(),
            esFiado: Value(esFiado),
            clienteId: Value(clienteId),
            usuarioId: usuarioId,
          ),
        );
  }

  Future<List<Venta>> ventasDelDia(DateTime dia, {int? usuarioId}) {
    final inicio = inicioDelDia(dia);
    final fin = finDelDia(dia);
    final query = _db.select(_db.ventas)
      ..where((v) =>
          v.fecha.isBiggerOrEqualValue(inicio) &
          v.fecha.isSmallerOrEqualValue(fin));
    if (usuarioId != null) {
      query.where((v) => v.usuarioId.equals(usuarioId));
    }
    return query.get();
  }
}
```

Create `lib/repositories/gasto_repository.dart`:

```dart
import 'package:drift/drift.dart';

import '../data/database.dart';
import '../util/fecha_util.dart';

class GastoRepository {
  GastoRepository(this._db);

  final AppDatabase _db;

  Future<int> registrarGasto({
    required int monto,
    String? descripcion,
    required int usuarioId,
    DateTime? fecha,
  }) {
    return _db.into(_db.gastos).insert(
          GastosCompanion.insert(
            monto: monto,
            descripcion: Value(descripcion),
            fecha: fecha ?? DateTime.now(),
            usuarioId: usuarioId,
          ),
        );
  }

  Future<List<Gasto>> gastosDelDia(DateTime dia, {int? usuarioId}) {
    final inicio = inicioDelDia(dia);
    final fin = finDelDia(dia);
    final query = _db.select(_db.gastos)
      ..where((g) =>
          g.fecha.isBiggerOrEqualValue(inicio) &
          g.fecha.isSmallerOrEqualValue(fin));
    if (usuarioId != null) {
      query.where((g) => g.usuarioId.equals(usuarioId));
    }
    return query.get();
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/repositories/venta_repository_test.dart test/repositories/gasto_repository_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/repositories/venta_repository.dart lib/repositories/gasto_repository.dart test/repositories/venta_repository_test.dart test/repositories/gasto_repository_test.dart
git commit -m "Add VentaRepository and GastoRepository"
```

---

### Task 8: FiadoRepository (balances, aging, payments)

**Files:**
- Create: `lib/repositories/fiado_repository.dart`
- Test: `test/repositories/fiado_repository_test.dart`

**Interfaces:**
- Consumes: `AppDatabase` (Task 2).
- Produces:
  - `class ClienteConSaldo { final Cliente cliente; final int saldo; final DateTime fechaDeudaMasAntigua; }`
  - `FiadoRepository(AppDatabase db)` with:
    - `Future<int> saldoCliente(int clienteId)` — `sum(ventas fiado) - sum(pagos)`
    - `Future<List<ClienteConSaldo>> listaClientesConDeuda()` — only clients with `saldo > 0`, sorted ascending by `fechaDeudaMasAntigua`
    - `Future<int> registrarPago({required int clienteId, required int monto, required int usuarioId, DateTime? fecha})`
    - `Future<List<Venta>> ventasFiadasCliente(int clienteId)` — newest first
    - `Future<List<PagoFiado>> pagosCliente(int clienteId)` — newest first

- [ ] **Step 1: Write the failing test**

Create `test/repositories/fiado_repository_test.dart`:

```dart
import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/repositories/fiado_repository.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late FiadoRepository repo;
  late int usuarioId;
  late int clienteId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = FiadoRepository(db);
    usuarioId = await db.into(db.usuarios).insert(
          UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'x'),
        );
    clienteId = await db.into(db.clientes).insert(
          ClientesCompanion.insert(nombre: 'Don Pedro'),
        );
  });

  tearDown(() => db.close());

  Future<void> venderFiado(int monto, DateTime fecha) {
    return db.into(db.ventas).insert(
          VentasCompanion.insert(
            monto: monto,
            fecha: fecha,
            esFiado: const Value(true),
            clienteId: Value(clienteId),
            usuarioId: usuarioId,
          ),
        );
  }

  test('saldoCliente es la suma de ventas fiadas menos pagos', () async {
    await venderFiado(5000, DateTime(2026, 9, 1));
    await venderFiado(3000, DateTime(2026, 9, 2));
    await repo.registrarPago(clienteId: clienteId, monto: 2000, usuarioId: usuarioId);

    expect(await repo.saldoCliente(clienteId), 6000);
  });

  test('saldoCliente es 0 para un cliente sin ventas fiadas', () async {
    expect(await repo.saldoCliente(clienteId), 0);
  });

  test('listaClientesConDeuda excluye clientes con saldo 0 o negativo', () async {
    await venderFiado(5000, DateTime(2026, 9, 1));
    await repo.registrarPago(clienteId: clienteId, monto: 5000, usuarioId: usuarioId);

    expect(await repo.listaClientesConDeuda(), isEmpty);
  });

  test('listaClientesConDeuda ordena por la deuda más antigua primero', () async {
    final clienteReciente = await db.into(db.clientes).insert(
          ClientesCompanion.insert(nombre: 'Doña Rosa'),
        );
    await venderFiado(1000, DateTime(2026, 9, 2)); // Don Pedro, más reciente
    await db.into(db.ventas).insert(
          VentasCompanion.insert(
            monto: 1000,
            fecha: DateTime(2026, 8, 15), // Doña Rosa, más antigua
            esFiado: const Value(true),
            clienteId: Value(clienteReciente),
            usuarioId: usuarioId,
          ),
        );

    final lista = await repo.listaClientesConDeuda();
    expect(lista, hasLength(2));
    expect(lista.first.cliente.nombre, 'Doña Rosa');
    expect(lista.last.cliente.nombre, 'Don Pedro');
  });

  test('registrarPago y pagosCliente/ventasFiadasCliente devuelven el historial',
      () async {
    await venderFiado(5000, DateTime(2026, 9, 1));
    await repo.registrarPago(
      clienteId: clienteId,
      monto: 2000,
      usuarioId: usuarioId,
      fecha: DateTime(2026, 9, 2),
    );

    expect(await repo.ventasFiadasCliente(clienteId), hasLength(1));
    final pagos = await repo.pagosCliente(clienteId);
    expect(pagos, hasLength(1));
    expect(pagos.single.monto, 2000);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/repositories/fiado_repository_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

Create `lib/repositories/fiado_repository.dart`:

```dart
import 'package:drift/drift.dart';

import '../data/database.dart';

class ClienteConSaldo {
  const ClienteConSaldo({
    required this.cliente,
    required this.saldo,
    required this.fechaDeudaMasAntigua,
  });

  final Cliente cliente;
  final int saldo;
  final DateTime fechaDeudaMasAntigua;
}

class FiadoRepository {
  FiadoRepository(this._db);

  final AppDatabase _db;

  Future<int> saldoCliente(int clienteId) async {
    final ventas = await (_db.select(_db.ventas)
          ..where((v) => v.clienteId.equals(clienteId) & v.esFiado.equals(true)))
        .get();
    final totalVentas = ventas.fold<int>(0, (suma, v) => suma + v.monto);

    final pagos = await (_db.select(_db.pagosFiado)
          ..where((p) => p.clienteId.equals(clienteId)))
        .get();
    final totalPagos = pagos.fold<int>(0, (suma, p) => suma + p.monto);

    return totalVentas - totalPagos;
  }

  Future<List<ClienteConSaldo>> listaClientesConDeuda() async {
    final clientes = await _db.select(_db.clientes).get();
    final resultado = <ClienteConSaldo>[];

    for (final cliente in clientes) {
      final saldo = await saldoCliente(cliente.id);
      if (saldo <= 0) continue;

      final ventasFiadas = await (_db.select(_db.ventas)
            ..where((v) =>
                v.clienteId.equals(cliente.id) & v.esFiado.equals(true))
            ..orderBy([(v) => OrderingTerm.asc(v.fecha)]))
          .get();

      resultado.add(ClienteConSaldo(
        cliente: cliente,
        saldo: saldo,
        fechaDeudaMasAntigua: ventasFiadas.first.fecha,
      ));
    }

    resultado.sort(
      (a, b) => a.fechaDeudaMasAntigua.compareTo(b.fechaDeudaMasAntigua),
    );
    return resultado;
  }

  Future<int> registrarPago({
    required int clienteId,
    required int monto,
    required int usuarioId,
    DateTime? fecha,
  }) {
    return _db.into(_db.pagosFiado).insert(
          PagosFiadoCompanion.insert(
            clienteId: clienteId,
            monto: monto,
            fecha: fecha ?? DateTime.now(),
            usuarioId: usuarioId,
          ),
        );
  }

  Future<List<Venta>> ventasFiadasCliente(int clienteId) {
    return (_db.select(_db.ventas)
          ..where((v) => v.clienteId.equals(clienteId) & v.esFiado.equals(true))
          ..orderBy([(v) => OrderingTerm.desc(v.fecha)]))
        .get();
  }

  Future<List<PagoFiado>> pagosCliente(int clienteId) {
    return (_db.select(_db.pagosFiado)
          ..where((p) => p.clienteId.equals(clienteId))
          ..orderBy([(p) => OrderingTerm.desc(p.fecha)]))
        .get();
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/repositories/fiado_repository_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/repositories/fiado_repository.dart test/repositories/fiado_repository_test.dart
git commit -m "Add FiadoRepository with balance calculation and aging order"
```

---

### Task 9: ResumenRepository (daily totals, per-seller breakdown)

**Files:**
- Create: `lib/repositories/resumen_repository.dart`
- Test: `test/repositories/resumen_repository_test.dart`

**Interfaces:**
- Consumes: `AppDatabase` (Task 2), `VentaRepository`, `GastoRepository` (Task 7).
- Produces:
  - `class ResumenDia { final int totalVendido; final int totalGastado; final int totalPorCobrar; }`
  - `ResumenRepository(AppDatabase db, VentaRepository ventaRepository, GastoRepository gastoRepository)` with:
    - `Future<ResumenDia> resumenDelDia(DateTime dia, {int? usuarioId})`
    - `Future<Map<Usuario, ResumenDia>> resumenPorVendedor(DateTime dia)`

- [ ] **Step 1: Write the failing test**

Create `test/repositories/resumen_repository_test.dart`:

```dart
import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/repositories/gasto_repository.dart';
import 'package:app_ventas/repositories/resumen_repository.dart';
import 'package:app_ventas/repositories/venta_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late ResumenRepository repo;
  late VentaRepository ventaRepo;
  late GastoRepository gastoRepo;
  late int vendedor1;
  late int vendedor2;
  final dia = DateTime(2026, 9, 2, 10);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    ventaRepo = VentaRepository(db);
    gastoRepo = GastoRepository(db);
    repo = ResumenRepository(db, ventaRepo, gastoRepo);

    vendedor1 = await db.into(db.usuarios).insert(
          UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'x'),
        );
    vendedor2 = await db.into(db.usuarios).insert(
          UsuariosCompanion.insert(nombre: 'Beto', rol: 'vendedor', pinHash: 'y'),
        );
  });

  tearDown(() => db.close());

  test('resumenDelDia suma ventas, gastos y separa el fiado del día', () async {
    await ventaRepo.registrarVenta(
        monto: 5000, esFiado: false, usuarioId: vendedor1, fecha: dia);
    await ventaRepo.registrarVenta(
        monto: 3000,
        esFiado: true,
        clienteId: await db
            .into(db.clientes)
            .insert(ClientesCompanion.insert(nombre: 'Don Pedro')),
        usuarioId: vendedor1,
        fecha: dia);
    await gastoRepo.registrarGasto(monto: 2000, usuarioId: vendedor1, fecha: dia);

    final resumen = await repo.resumenDelDia(dia);
    expect(resumen.totalVendido, 8000);
    expect(resumen.totalGastado, 2000);
    expect(resumen.totalPorCobrar, 3000);
  });

  test('resumenDelDia filtra por usuarioId', () async {
    await ventaRepo.registrarVenta(
        monto: 1000, esFiado: false, usuarioId: vendedor1, fecha: dia);
    await ventaRepo.registrarVenta(
        monto: 2000, esFiado: false, usuarioId: vendedor2, fecha: dia);

    final resumenVendedor1 = await repo.resumenDelDia(dia, usuarioId: vendedor1);
    expect(resumenVendedor1.totalVendido, 1000);
  });

  test('resumenPorVendedor incluye una entrada por cada usuario', () async {
    await ventaRepo.registrarVenta(
        monto: 1000, esFiado: false, usuarioId: vendedor1, fecha: dia);
    await ventaRepo.registrarVenta(
        monto: 2000, esFiado: false, usuarioId: vendedor2, fecha: dia);

    final mapa = await repo.resumenPorVendedor(dia);
    expect(mapa, hasLength(2));
    final totalesPorNombre = {
      for (final entrada in mapa.entries) entrada.key.nombre: entrada.value.totalVendido
    };
    expect(totalesPorNombre['Ana'], 1000);
    expect(totalesPorNombre['Beto'], 2000);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/repositories/resumen_repository_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

Create `lib/repositories/resumen_repository.dart`:

```dart
import '../data/database.dart';
import 'gasto_repository.dart';
import 'venta_repository.dart';

class ResumenDia {
  const ResumenDia({
    required this.totalVendido,
    required this.totalGastado,
    required this.totalPorCobrar,
  });

  final int totalVendido;
  final int totalGastado;
  final int totalPorCobrar;
}

class ResumenRepository {
  ResumenRepository(this._db, this._ventaRepository, this._gastoRepository);

  final AppDatabase _db;
  final VentaRepository _ventaRepository;
  final GastoRepository _gastoRepository;

  Future<ResumenDia> resumenDelDia(DateTime dia, {int? usuarioId}) async {
    final ventas = await _ventaRepository.ventasDelDia(dia, usuarioId: usuarioId);
    final gastos = await _gastoRepository.gastosDelDia(dia, usuarioId: usuarioId);

    final totalVendido = ventas.fold<int>(0, (suma, v) => suma + v.monto);
    final totalGastado = gastos.fold<int>(0, (suma, g) => suma + g.monto);
    final totalPorCobrar = ventas
        .where((v) => v.esFiado)
        .fold<int>(0, (suma, v) => suma + v.monto);

    return ResumenDia(
      totalVendido: totalVendido,
      totalGastado: totalGastado,
      totalPorCobrar: totalPorCobrar,
    );
  }

  Future<Map<Usuario, ResumenDia>> resumenPorVendedor(DateTime dia) async {
    final usuarios = await _db.select(_db.usuarios).get();
    final resultado = <Usuario, ResumenDia>{};
    for (final usuario in usuarios) {
      resultado[usuario] = await resumenDelDia(dia, usuarioId: usuario.id);
    }
    return resultado;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/repositories/resumen_repository_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/repositories/resumen_repository.dart test/repositories/resumen_repository_test.dart
git commit -m "Add ResumenRepository with daily and per-seller totals"
```

---

### Task 10: Riverpod providers — database, repositories, session

**Files:**
- Create: `lib/providers/database_provider.dart`
- Create: `lib/providers/repository_providers.dart`
- Create: `lib/providers/sesion_provider.dart`
- Test: `test/providers/sesion_provider_test.dart`

**Interfaces:**
- Consumes: `AppDatabase` (Task 2), all repositories (Tasks 5–9).
- Produces:
  - `final databaseProvider = Provider<AppDatabase>(...)`
  - `usuarioRepositoryProvider`, `productoRepositoryProvider`, `clienteRepositoryProvider`, `ventaRepositoryProvider`, `fiadoRepositoryProvider`, `gastoRepositoryProvider`, `resumenRepositoryProvider` — all `Provider<...Repository>`.
  - `class SesionState { final Usuario? usuarioActivo; bool get haySesion; bool get esAdmin; }`
  - `final sesionProvider = NotifierProvider<SesionNotifier, SesionState>(SesionNotifier.new)` with `Future<bool> iniciarSesion(int usuarioId, String pin)` and `void cerrarSesion()`.
  - `final haySesionUsuariosProvider = FutureProvider<bool>(...)` wrapping `UsuarioRepository.existeAlgunUsuario()`.

- [ ] **Step 1: Write the failing test**

Create `test/providers/sesion_provider_test.dart`:

```dart
import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/database_provider.dart';
import 'package:app_ventas/providers/repository_providers.dart';
import 'package:app_ventas/providers/sesion_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iniciarSesion con PIN correcto actualiza el estado y devuelve true', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final usuarioId = await db.into(db.usuarios).insert(
          UsuariosCompanion.insert(
            nombre: 'Ana',
            rol: 'admin',
            pinHash:
                '03ac674216f3e15c761ee1a5e255f067953623c8b388b4459e13f978d7c846f', // sha256("1234")
          ),
        );

    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    final ok = await container
        .read(sesionProvider.notifier)
        .iniciarSesion(usuarioId, '1234');

    expect(ok, isTrue);
    expect(container.read(sesionProvider).haySesion, isTrue);
    expect(container.read(sesionProvider).esAdmin, isTrue);
  });

  test('iniciarSesion con PIN incorrecto no cambia el estado y devuelve false', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final usuarioId = await db.into(db.usuarios).insert(
          UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'otro-hash'),
        );

    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    final ok = await container
        .read(sesionProvider.notifier)
        .iniciarSesion(usuarioId, '0000');

    expect(ok, isFalse);
    expect(container.read(sesionProvider).haySesion, isFalse);
  });

  test('cerrarSesion limpia el usuario activo', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final usuarioId = await db.into(db.usuarios).insert(
          UsuariosCompanion.insert(
            nombre: 'Ana',
            rol: 'vendedor',
            pinHash:
                '03ac674216f3e15c761ee1a5e255f067953623c8b388b4459e13f978d7c846f',
          ),
        );

    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    await container.read(sesionProvider.notifier).iniciarSesion(usuarioId, '1234');
    container.read(sesionProvider.notifier).cerrarSesion();

    expect(container.read(sesionProvider).haySesion, isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/providers/sesion_provider_test.dart`
Expected: FAIL — providers don't exist.

- [ ] **Step 3: Implement**

Create `lib/providers/database_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
```

Create `lib/providers/repository_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/cliente_repository.dart';
import '../repositories/fiado_repository.dart';
import '../repositories/gasto_repository.dart';
import '../repositories/producto_repository.dart';
import '../repositories/resumen_repository.dart';
import '../repositories/usuario_repository.dart';
import '../repositories/venta_repository.dart';
import 'database_provider.dart';

final usuarioRepositoryProvider = Provider(
  (ref) => UsuarioRepository(ref.watch(databaseProvider)),
);

final productoRepositoryProvider = Provider(
  (ref) => ProductoRepository(ref.watch(databaseProvider)),
);

final clienteRepositoryProvider = Provider(
  (ref) => ClienteRepository(ref.watch(databaseProvider)),
);

final ventaRepositoryProvider = Provider(
  (ref) => VentaRepository(ref.watch(databaseProvider)),
);

final fiadoRepositoryProvider = Provider(
  (ref) => FiadoRepository(ref.watch(databaseProvider)),
);

final gastoRepositoryProvider = Provider(
  (ref) => GastoRepository(ref.watch(databaseProvider)),
);

final resumenRepositoryProvider = Provider(
  (ref) => ResumenRepository(
    ref.watch(databaseProvider),
    ref.watch(ventaRepositoryProvider),
    ref.watch(gastoRepositoryProvider),
  ),
);
```

Create `lib/providers/sesion_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import 'repository_providers.dart';

class SesionState {
  const SesionState({this.usuarioActivo});

  final Usuario? usuarioActivo;

  bool get haySesion => usuarioActivo != null;
  bool get esAdmin => usuarioActivo?.rol == 'admin';
}

class SesionNotifier extends Notifier<SesionState> {
  @override
  SesionState build() => const SesionState();

  Future<bool> iniciarSesion(int usuarioId, String pin) async {
    final repo = ref.read(usuarioRepositoryProvider);
    final usuario = await repo.verificarPin(usuarioId, pin);
    if (usuario == null) return false;
    state = SesionState(usuarioActivo: usuario);
    return true;
  }

  void cerrarSesion() {
    state = const SesionState();
  }
}

final sesionProvider = NotifierProvider<SesionNotifier, SesionState>(
  SesionNotifier.new,
);

final haySesionUsuariosProvider = FutureProvider<bool>((ref) {
  return ref.watch(usuarioRepositoryProvider).existeAlgunUsuario();
});
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/providers/sesion_provider_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/providers test/providers
git commit -m "Add Riverpod providers for database, repositories, and session"
```

---

### Task 11: Login flow screens (select user, PIN entry, first-run admin creation)

**Files:**
- Create: `lib/screens/login/seleccionar_usuario_screen.dart`
- Create: `lib/screens/login/ingresar_pin_screen.dart`
- Create: `lib/screens/login/crear_admin_inicial_screen.dart`
- Create: `lib/providers/usuarios_providers.dart`
- Test: `test/screens/login/ingresar_pin_screen_test.dart`
- Test: `test/screens/login/crear_admin_inicial_screen_test.dart`

**Interfaces:**
- Consumes: `sesionProvider`, `haySesionUsuariosProvider` (Task 10), `usuarioRepositoryProvider` (Task 10), `TecladoNumerico` (Task 4).
- Produces: `listaUsuariosProvider = FutureProvider<List<Usuario>>` (in `lib/providers/usuarios_providers.dart`, invalidated after creating a user); `SeleccionarUsuarioScreen`, `IngresarPinScreen({required Usuario usuario})`, `CrearAdminInicialScreen` widgets, all used by `RaizApp` in Task 16.

- [ ] **Step 1: Write the failing tests**

Create `test/screens/login/ingresar_pin_screen_test.dart`:

```dart
import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/database_provider.dart';
import 'package:app_ventas/providers/sesion_provider.dart';
import 'package:app_ventas/screens/login/ingresar_pin_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('PIN correcto abre sesión y PIN incorrecto muestra error',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final usuarioId = await db.into(db.usuarios).insert(
          UsuariosCompanion.insert(
            nombre: 'Ana',
            rol: 'admin',
            pinHash:
                '03ac674216f3e15c761ee1a5e255f067953623c8b388b4459e13f978d7c846f', // "1234"
          ),
        );
    final usuario = (await db.select(db.usuarios).get()).single;

    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: IngresarPinScreen(usuario: usuario)),
      ),
    );

    for (final digito in ['0', '0', '0', '0']) {
      await tester.tap(find.byKey(Key('tecla_$digito')));
      await tester.pumpAndSettle();
    }
    expect(find.text('PIN incorrecto'), findsOneWidget);
    expect(container.read(sesionProvider).haySesion, isFalse);

    for (final digito in ['1', '2', '3', '4']) {
      await tester.tap(find.byKey(Key('tecla_$digito')));
      await tester.pumpAndSettle();
    }
    expect(container.read(sesionProvider).haySesion, isTrue);
    expect(container.read(sesionProvider).usuarioActivo?.id, usuarioId);
  });
}
```

Create `test/screens/login/crear_admin_inicial_screen_test.dart`:

```dart
import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/database_provider.dart';
import 'package:app_ventas/providers/sesion_provider.dart';
import 'package:app_ventas/screens/login/crear_admin_inicial_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('crear admin inicial guarda el usuario e inicia sesión',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: CrearAdminInicialScreen()),
      ),
    );

    await tester.enterText(find.byKey(const Key('campo_nombre_admin')), 'Ana');
    await tester.enterText(find.byKey(const Key('campo_pin_admin')), '1234');
    await tester.tap(find.byKey(const Key('boton_crear_admin')));
    await tester.pumpAndSettle();

    final usuarios = await db.select(db.usuarios).get();
    expect(usuarios, hasLength(1));
    expect(usuarios.single.nombre, 'Ana');
    expect(usuarios.single.rol, 'admin');
    expect(container.read(sesionProvider).haySesion, isTrue);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/screens/login/`
Expected: FAIL — screens don't exist.

- [ ] **Step 3: Implement**

Create `lib/providers/usuarios_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import 'repository_providers.dart';

final listaUsuariosProvider = FutureProvider<List<Usuario>>((ref) {
  return ref.watch(usuarioRepositoryProvider).listarUsuarios();
});
```

Create `lib/screens/login/ingresar_pin_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../providers/sesion_provider.dart';
import '../../widgets/teclado_numerico.dart';

class IngresarPinScreen extends ConsumerStatefulWidget {
  const IngresarPinScreen({super.key, required this.usuario});

  final Usuario usuario;

  @override
  ConsumerState<IngresarPinScreen> createState() => _IngresarPinScreenState();
}

class _IngresarPinScreenState extends ConsumerState<IngresarPinScreen> {
  String _pin = '';
  String? _error;

  Future<void> _validar() async {
    final ok = await ref
        .read(sesionProvider.notifier)
        .iniciarSesion(widget.usuario.id, _pin);
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _error = 'PIN incorrecto';
        _pin = '';
      });
    }
  }

  void _presionarDigito(String digito) {
    if (_pin.length >= 4) return;
    setState(() {
      _pin += digito;
      _error = null;
    });
    if (_pin.length == 4) _validar();
  }

  void _borrar() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Hola, ${widget.usuario.nombre}')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${'●' * _pin.length}${'○' * (4 - _pin.length)}',
              style: const TextStyle(fontSize: 32, letterSpacing: 8),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            const SizedBox(height: 24),
            TecladoNumerico(onDigito: _presionarDigito, onBorrar: _borrar),
          ],
        ),
      ),
    );
  }
}
```

Create `lib/screens/login/seleccionar_usuario_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/usuarios_providers.dart';
import 'ingresar_pin_screen.dart';

class SeleccionarUsuarioScreen extends ConsumerWidget {
  const SeleccionarUsuarioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuariosAsync = ref.watch(listaUsuariosProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('¿Quién eres?')),
      body: usuariosAsync.when(
        data: (usuarios) => ListView(
          children: usuarios
              .map((usuario) => ListTile(
                    key: Key('usuario_${usuario.id}'),
                    leading: const Icon(Icons.person, size: 32),
                    title: Text(usuario.nombre,
                        style: const TextStyle(fontSize: 20)),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => IngresarPinScreen(usuario: usuario),
                      ),
                    ),
                  ))
              .toList(),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
```

Create `lib/screens/login/crear_admin_inicial_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/repository_providers.dart';
import '../../providers/sesion_provider.dart';
import '../../providers/usuarios_providers.dart';

class CrearAdminInicialScreen extends ConsumerStatefulWidget {
  const CrearAdminInicialScreen({super.key});

  @override
  ConsumerState<CrearAdminInicialScreen> createState() =>
      _CrearAdminInicialScreenState();
}

class _CrearAdminInicialScreenState
    extends ConsumerState<CrearAdminInicialScreen> {
  final _nombreController = TextEditingController();
  final _pinController = TextEditingController();
  String? _error;

  Future<void> _crear() async {
    final nombre = _nombreController.text.trim();
    final pin = _pinController.text.trim();
    if (nombre.isEmpty) {
      setState(() => _error = 'Escribe tu nombre');
      return;
    }
    if (pin.length != 4 || int.tryParse(pin) == null) {
      setState(() => _error = 'El PIN debe tener 4 dígitos');
      return;
    }

    final repo = ref.read(usuarioRepositoryProvider);
    final id = await repo.crearUsuario(nombre: nombre, rol: 'admin', pin: pin);
    ref.invalidate(listaUsuariosProvider);
    ref.invalidate(haySesionUsuariosProvider);
    await ref.read(sesionProvider.notifier).iniciarSesion(id, pin);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configura tu tienda')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Crea el usuario administrador de tu tienda',
              style: TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextField(
              key: const Key('campo_nombre_admin'),
              controller: _nombreController,
              decoration: const InputDecoration(labelText: 'Tu nombre'),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('campo_pin_admin'),
              controller: _pinController,
              decoration: const InputDecoration(labelText: 'PIN de 4 dígitos'),
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
            ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              key: const Key('boton_crear_admin'),
              onPressed: _crear,
              child: const Text('Crear'),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/screens/login/`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/screens/login lib/providers/usuarios_providers.dart test/screens/login
git commit -m "Add login flow screens: select user, PIN entry, first-run admin creation"
```

---

### Task 12: Configuración → Productos screen

**Files:**
- Create: `lib/screens/configuracion/productos_screen.dart`
- Create: `lib/providers/productos_providers.dart`
- Test: `test/screens/configuracion/productos_screen_test.dart`

**Interfaces:**
- Consumes: `productoRepositoryProvider` (Task 10), `formatoMoneda` (Task 3).
- Produces: `productosActivosProvider = StreamProvider<List<Producto>>` (in `lib/providers/productos_providers.dart`); `ProductosScreen` widget, used by `_ConfiguracionMenu` in Task 16 and by `RegistrarVentaScreen` in Task 13.

- [ ] **Step 1: Write the failing test**

Create `test/screens/configuracion/productos_screen_test.dart`:

```dart
import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/database_provider.dart';
import 'package:app_ventas/screens/configuracion/productos_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('crear un producto lo agrega a la lista visible', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: ProductosScreen()),
      ),
    );

    await tester.enterText(
        find.byKey(const Key('campo_nombre_producto')), 'Arepa');
    await tester.enterText(
        find.byKey(const Key('campo_precio_producto')), '3000');
    await tester.tap(find.byKey(const Key('boton_crear_producto')));
    await tester.pumpAndSettle();

    expect(find.text('Arepa'), findsOneWidget);
    expect(find.text(r'$3.000'), findsOneWidget);
  });

  testWidgets('desactivar un producto lo saca de la lista', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final id = await db.into(db.productos).insert(
          ProductosCompanion.insert(nombre: 'Arepa', precio: 3000),
        );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: ProductosScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(Key('boton_desactivar_$id')));
    await tester.pumpAndSettle();

    expect(find.text('Arepa'), findsNothing);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/configuracion/productos_screen_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

Create `lib/providers/productos_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import 'repository_providers.dart';

final productosActivosProvider = StreamProvider<List<Producto>>((ref) {
  return ref.watch(productoRepositoryProvider).observarProductosActivos();
});
```

Create `lib/screens/configuracion/productos_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/productos_providers.dart';
import '../../providers/repository_providers.dart';
import '../../util/formato_moneda.dart';

class ProductosScreen extends ConsumerStatefulWidget {
  const ProductosScreen({super.key});

  @override
  ConsumerState<ProductosScreen> createState() => _ProductosScreenState();
}

class _ProductosScreenState extends ConsumerState<ProductosScreen> {
  final _nombreController = TextEditingController();
  final _precioController = TextEditingController();

  Future<void> _crear() async {
    final nombre = _nombreController.text.trim();
    final precio = int.tryParse(_precioController.text.trim());
    if (nombre.isEmpty || precio == null || precio <= 0) return;
    await ref
        .read(productoRepositoryProvider)
        .crearProducto(nombre: nombre, precio: precio);
    _nombreController.clear();
    _precioController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final productosAsync = ref.watch(productosActivosProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Productos')),
      body: Column(
        children: [
          Expanded(
            child: productosAsync.when(
              data: (productos) => ListView(
                children: productos
                    .map((p) => ListTile(
                          key: Key('producto_item_${p.id}'),
                          title: Text(p.nombre),
                          subtitle: Text(formatoMoneda(p.precio)),
                          trailing: IconButton(
                            key: Key('boton_desactivar_${p.id}'),
                            icon: const Icon(Icons.delete),
                            onPressed: () => ref
                                .read(productoRepositoryProvider)
                                .desactivarProducto(p.id),
                          ),
                        ))
                    .toList(),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Error: $e')),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  key: const Key('campo_nombre_producto'),
                  controller: _nombreController,
                  decoration: const InputDecoration(labelText: 'Nombre del producto'),
                ),
                TextField(
                  key: const Key('campo_precio_producto'),
                  controller: _precioController,
                  decoration: const InputDecoration(labelText: 'Precio'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  key: const Key('boton_crear_producto'),
                  onPressed: _crear,
                  child: const Text('Agregar producto'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/screens/configuracion/productos_screen_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/screens/configuracion/productos_screen.dart lib/providers/productos_providers.dart test/screens/configuracion/productos_screen_test.dart
git commit -m "Add Configuración > Productos screen"
```

---

### Task 13: Registrar Venta screen

**Files:**
- Create: `lib/screens/venta/registrar_venta_screen.dart`
- Create: `lib/providers/clientes_providers.dart`
- Test: `test/screens/venta/registrar_venta_screen_test.dart`

**Interfaces:**
- Consumes: `productosActivosProvider` (Task 12), `ventaRepositoryProvider`, `clienteRepositoryProvider`, `sesionProvider` (Task 10), `MontoRapidoGrid` (Task 4), `formatoMoneda` (Task 3).
- Produces: `listaClientesProvider = FutureProvider<List<Cliente>>` (in `lib/providers/clientes_providers.dart`); `RegistrarVentaScreen` widget, pushed from `HomeScreen` in Task 16.

- [ ] **Step 1: Write the failing test**

Create `test/screens/venta/registrar_venta_screen_test.dart`:

```dart
import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/database_provider.dart';
import 'package:app_ventas/providers/sesion_provider.dart';
import 'package:app_ventas/screens/venta/registrar_venta_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<ProviderContainer> _containerConSesion(AppDatabase db) async {
  final usuarioId = await db.into(db.usuarios).insert(
        UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'x'),
      );
  final usuario =
      await (db.select(db.usuarios)..where((u) => u.id.equals(usuarioId)))
          .getSingle();

  final container = ProviderContainer(
    overrides: [databaseProvider.overrideWithValue(db)],
  );
  container.read(sesionProvider.notifier).state =
      SesionState(usuarioActivo: usuario);
  return container;
}

void main() {
  testWidgets('tocar un monto rápido registra una venta de contado',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = await _containerConSesion(db);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: RegistrarVentaScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('monto_rapido_5000')));
    await tester.pumpAndSettle();

    final ventas = await db.select(db.ventas).get();
    expect(ventas, hasLength(1));
    expect(ventas.single.monto, 5000);
    expect(ventas.single.esFiado, isFalse);
  });

  testWidgets('marcar fiado con cliente nuevo crea el cliente y la venta fiada',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = await _containerConSesion(db);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: RegistrarVentaScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('checkbox_fiado')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('campo_cliente_nuevo')), 'Don Pedro');
    await tester.tap(find.byKey(const Key('monto_rapido_2000')));
    await tester.pumpAndSettle();

    final ventas = await db.select(db.ventas).get();
    expect(ventas.single.esFiado, isTrue);
    final clientes = await db.select(db.clientes).get();
    expect(clientes.single.nombre, 'Don Pedro');
    expect(ventas.single.clienteId, clientes.single.id);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/venta/registrar_venta_screen_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

Create `lib/providers/clientes_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import 'repository_providers.dart';

final listaClientesProvider = FutureProvider<List<Cliente>>((ref) {
  return ref.watch(clienteRepositoryProvider).listarClientes();
});
```

Create `lib/screens/venta/registrar_venta_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../providers/clientes_providers.dart';
import '../../providers/productos_providers.dart';
import '../../providers/repository_providers.dart';
import '../../providers/sesion_provider.dart';
import '../../util/formato_moneda.dart';
import '../../widgets/monto_rapido_grid.dart';

class RegistrarVentaScreen extends ConsumerStatefulWidget {
  const RegistrarVentaScreen({super.key});

  @override
  ConsumerState<RegistrarVentaScreen> createState() =>
      _RegistrarVentaScreenState();
}

class _RegistrarVentaScreenState extends ConsumerState<RegistrarVentaScreen> {
  final _montoLibreController = TextEditingController();
  final _nombreClienteNuevoController = TextEditingController();
  bool _esFiado = false;
  Cliente? _clienteSeleccionado;

  Future<void> _registrar(int monto, {int? productoId}) async {
    final sesion = ref.read(sesionProvider).usuarioActivo!;
    int? clienteId;

    if (_esFiado) {
      if (_clienteSeleccionado != null) {
        clienteId = _clienteSeleccionado!.id;
      } else if (_nombreClienteNuevoController.text.trim().isNotEmpty) {
        clienteId = await ref.read(clienteRepositoryProvider).crearCliente(
              nombre: _nombreClienteNuevoController.text.trim(),
            );
      } else {
        return; // fiado requiere cliente
      }
    }

    await ref.read(ventaRepositoryProvider).registrarVenta(
          monto: monto,
          productoId: productoId,
          esFiado: _esFiado,
          clienteId: clienteId,
          usuarioId: sesion.id,
        );

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final productosAsync = ref.watch(productosActivosProvider);
    final clientesAsync = ref.watch(listaClientesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Registrar venta')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Productos frecuentes', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            productosAsync.when(
              data: (productos) => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: productos.map((producto) {
                  return ElevatedButton(
                    key: Key('producto_${producto.id}'),
                    onPressed: () =>
                        _registrar(producto.precio, productoId: producto.id),
                    child: Text(
                      '${producto.nombre}\n${formatoMoneda(producto.precio)}',
                      textAlign: TextAlign.center,
                    ),
                  );
                }).toList(),
              ),
              loading: () => const CircularProgressIndicator(),
              error: (e, st) => Text('Error: $e'),
            ),
            const SizedBox(height: 16),
            const Text('Montos rápidos', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            MontoRapidoGrid(onSeleccionar: (monto) => _registrar(monto)),
            const SizedBox(height: 16),
            TextField(
              key: const Key('campo_monto_libre'),
              controller: _montoLibreController,
              decoration: const InputDecoration(labelText: 'Monto libre'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              key: const Key('boton_registrar_monto_libre'),
              onPressed: () {
                final monto = int.tryParse(_montoLibreController.text.trim());
                if (monto != null && monto > 0) _registrar(monto);
              },
              child: const Text('Registrar monto libre'),
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              key: const Key('checkbox_fiado'),
              title: const Text('Fiado'),
              value: _esFiado,
              onChanged: (value) => setState(() => _esFiado = value ?? false),
            ),
            if (_esFiado)
              clientesAsync.when(
                data: (clientes) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButton<Cliente>(
                      key: const Key('dropdown_cliente'),
                      hint: const Text('Elegir cliente existente'),
                      value: _clienteSeleccionado,
                      items: clientes
                          .map((c) =>
                              DropdownMenuItem(value: c, child: Text(c.nombre)))
                          .toList(),
                      onChanged: (c) =>
                          setState(() => _clienteSeleccionado = c),
                    ),
                    TextField(
                      key: const Key('campo_cliente_nuevo'),
                      controller: _nombreClienteNuevoController,
                      decoration: const InputDecoration(
                        labelText: 'O nombre de cliente nuevo',
                      ),
                    ),
                  ],
                ),
                loading: () => const CircularProgressIndicator(),
                error: (e, st) => Text('Error: $e'),
              ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/screens/venta/registrar_venta_screen_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/screens/venta lib/providers/clientes_providers.dart test/screens/venta
git commit -m "Add Registrar Venta screen"
```

---

### Task 14: Fiado screens — lista and detalle

**Files:**
- Create: `lib/screens/fiado/lista_fiado_screen.dart`
- Create: `lib/screens/fiado/detalle_cliente_screen.dart`
- Create: `lib/providers/fiado_providers.dart`
- Test: `test/screens/fiado/lista_fiado_screen_test.dart`
- Test: `test/screens/fiado/detalle_cliente_screen_test.dart`

**Interfaces:**
- Consumes: `fiadoRepositoryProvider`, `sesionProvider` (Task 10), `ClienteConSaldo` (Task 8), `formatoMoneda` (Task 3).
- Produces: `clientesConDeudaProvider = FutureProvider<List<ClienteConSaldo>>` (in `lib/providers/fiado_providers.dart`, invalidated after a payment); `ListaFiadoScreen`, `DetalleClienteScreen({required ClienteConSaldo clienteConSaldo})` widgets, used by `HomeScreen` in Task 16.

- [ ] **Step 1: Write the failing tests**

Create `test/screens/fiado/lista_fiado_screen_test.dart`:

```dart
import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/database_provider.dart';
import 'package:app_ventas/screens/fiado/lista_fiado_screen.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('muestra clientes con deuda y el mensaje vacío cuando no hay deudas',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: ListaFiadoScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Nadie te debe por ahora'), findsOneWidget);

    final usuarioId = await db.into(db.usuarios).insert(
          UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'x'),
        );
    final clienteId = await db
        .into(db.clientes)
        .insert(ClientesCompanion.insert(nombre: 'Don Pedro'));
    await db.into(db.ventas).insert(
          VentasCompanion.insert(
            monto: 5000,
            fecha: DateTime.now(),
            esFiado: const Value(true),
            clienteId: Value(clienteId),
            usuarioId: usuarioId,
          ),
        );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: ListaFiadoScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Don Pedro'), findsOneWidget);
    expect(find.text(r'$5.000'), findsOneWidget);
  });
}
```

Create `test/screens/fiado/detalle_cliente_screen_test.dart`:

```dart
import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/database_provider.dart';
import 'package:app_ventas/providers/sesion_provider.dart';
import 'package:app_ventas/repositories/fiado_repository.dart';
import 'package:app_ventas/screens/fiado/detalle_cliente_screen.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('registrar un abono descuenta el saldo en la base de datos',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final usuarioId = await db.into(db.usuarios).insert(
          UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'x'),
        );
    final usuario =
        await (db.select(db.usuarios)..where((u) => u.id.equals(usuarioId)))
            .getSingle();
    final clienteId = await db
        .into(db.clientes)
        .insert(ClientesCompanion.insert(nombre: 'Don Pedro'));
    await db.into(db.ventas).insert(
          VentasCompanion.insert(
            monto: 5000,
            fecha: DateTime.now(),
            esFiado: const Value(true),
            clienteId: Value(clienteId),
            usuarioId: usuarioId,
          ),
        );
    final cliente =
        await (db.select(db.clientes)..where((c) => c.id.equals(clienteId)))
            .getSingle();

    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    container.read(sesionProvider.notifier).state =
        SesionState(usuarioActivo: usuario);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: DetalleClienteScreen(
            clienteConSaldo: ClienteConSaldo(
              cliente: cliente,
              saldo: 5000,
              fechaDeudaMasAntigua: DateTime.now(),
            ),
          ),
        ),
      ),
    );

    await tester.enterText(find.byKey(const Key('campo_monto_abono')), '2000');
    await tester.tap(find.byKey(const Key('boton_registrar_abono')));
    await tester.pumpAndSettle();

    final saldo = await FiadoRepository(db).saldoCliente(clienteId);
    expect(saldo, 3000);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/screens/fiado/`
Expected: FAIL.

- [ ] **Step 3: Implement**

Create `lib/providers/fiado_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/fiado_repository.dart';
import 'repository_providers.dart';

final clientesConDeudaProvider = FutureProvider<List<ClienteConSaldo>>((ref) {
  return ref.watch(fiadoRepositoryProvider).listaClientesConDeuda();
});
```

Create `lib/screens/fiado/lista_fiado_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/fiado_providers.dart';
import '../../util/formato_moneda.dart';
import 'detalle_cliente_screen.dart';

class ListaFiadoScreen extends ConsumerWidget {
  const ListaFiadoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientesAsync = ref.watch(clientesConDeudaProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Me deben')),
      body: clientesAsync.when(
        data: (clientes) {
          if (clientes.isEmpty) {
            return const Center(child: Text('Nadie te debe por ahora'));
          }
          return ListView.builder(
            itemCount: clientes.length,
            itemBuilder: (context, index) {
              final item = clientes[index];
              return ListTile(
                key: Key('cliente_deuda_${item.cliente.id}'),
                title: Text(item.cliente.nombre),
                subtitle: Text(
                  'Desde ${item.fechaDeudaMasAntigua.day}/${item.fechaDeudaMasAntigua.month}',
                ),
                trailing: Text(
                  formatoMoneda(item.saldo),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => DetalleClienteScreen(clienteConSaldo: item),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
```

Create `lib/screens/fiado/detalle_cliente_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/fiado_providers.dart';
import '../../providers/repository_providers.dart';
import '../../providers/sesion_provider.dart';
import '../../repositories/fiado_repository.dart';
import '../../util/formato_moneda.dart';

class DetalleClienteScreen extends ConsumerStatefulWidget {
  const DetalleClienteScreen({super.key, required this.clienteConSaldo});

  final ClienteConSaldo clienteConSaldo;

  @override
  ConsumerState<DetalleClienteScreen> createState() =>
      _DetalleClienteScreenState();
}

class _DetalleClienteScreenState extends ConsumerState<DetalleClienteScreen> {
  final _montoController = TextEditingController();

  Future<void> _registrarAbono() async {
    final monto = int.tryParse(_montoController.text.trim());
    if (monto == null || monto <= 0) return;
    final sesion = ref.read(sesionProvider).usuarioActivo!;

    await ref.read(fiadoRepositoryProvider).registrarPago(
          clienteId: widget.clienteConSaldo.cliente.id,
          monto: monto,
          usuarioId: sesion.id,
        );
    ref.invalidate(clientesConDeudaProvider);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final cliente = widget.clienteConSaldo.cliente;
    return Scaffold(
      appBar: AppBar(title: Text(cliente.nombre)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Debe: ${formatoMoneda(widget.clienteConSaldo.saldo)}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('campo_monto_abono'),
              controller: _montoController,
              decoration: const InputDecoration(labelText: 'Monto del abono'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              key: const Key('boton_registrar_abono'),
              onPressed: _registrarAbono,
              child: const Text('Registrar abono'),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/screens/fiado/`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/screens/fiado lib/providers/fiado_providers.dart test/screens/fiado
git commit -m "Add Fiado list and client detail screens"
```

---

### Task 15: Registrar Gasto, Resumen, Usuarios and Historial screens

**Files:**
- Create: `lib/screens/gasto/registrar_gasto_screen.dart`
- Create: `lib/screens/home/resumen_screen.dart`
- Create: `lib/providers/resumen_providers.dart`
- Create: `lib/screens/configuracion/usuarios_screen.dart`
- Create: `lib/screens/historial/historial_screen.dart`
- Create: `lib/providers/historial_providers.dart`
- Test: `test/screens/gasto/registrar_gasto_screen_test.dart`
- Test: `test/screens/home/resumen_screen_test.dart`
- Test: `test/screens/configuracion/usuarios_screen_test.dart`
- Test: `test/screens/historial/historial_screen_test.dart`

**Interfaces:**
- Consumes: `gastoRepositoryProvider`, `resumenRepositoryProvider`, `usuarioRepositoryProvider`, `ventaRepositoryProvider`, `sesionProvider` (Task 10), `listaUsuariosProvider` (Task 11), `formatoMoneda` (Task 3).
- Produces: `resumenDelDiaProvider`, `resumenPorVendedorProvider` (`FutureProvider.autoDispose`, in `lib/providers/resumen_providers.dart`); `historialDelDiaProvider` (`FutureProvider.autoDispose<List<Venta>>`, in `lib/providers/historial_providers.dart`); `RegistrarGastoScreen`, `ResumenScreen`, `UsuariosScreen`, `HistorialScreen` widgets — all wired into `HomeScreen` in Task 16.

- [ ] **Step 1: Write the failing tests**

Create `test/screens/gasto/registrar_gasto_screen_test.dart`:

```dart
import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/database_provider.dart';
import 'package:app_ventas/providers/sesion_provider.dart';
import 'package:app_ventas/screens/gasto/registrar_gasto_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('registrar un gasto lo guarda en la base de datos', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final usuarioId = await db.into(db.usuarios).insert(
          UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'x'),
        );
    final usuario =
        await (db.select(db.usuarios)..where((u) => u.id.equals(usuarioId)))
            .getSingle();

    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    container.read(sesionProvider.notifier).state =
        SesionState(usuarioActivo: usuario);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: RegistrarGastoScreen()),
      ),
    );

    await tester.enterText(find.byKey(const Key('campo_monto_gasto')), '20000');
    await tester.enterText(
        find.byKey(const Key('campo_descripcion_gasto')), 'Bolsas');
    await tester.tap(find.byKey(const Key('boton_registrar_gasto')));
    await tester.pumpAndSettle();

    final gastos = await db.select(db.gastos).get();
    expect(gastos.single.monto, 20000);
    expect(gastos.single.descripcion, 'Bolsas');
  });
}
```

Create `test/screens/home/resumen_screen_test.dart`:

```dart
import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/database_provider.dart';
import 'package:app_ventas/screens/home/resumen_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('muestra los totales del día', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final usuarioId = await db.into(db.usuarios).insert(
          UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'x'),
        );
    await db.into(db.ventas).insert(
          VentasCompanion.insert(
            monto: 5000,
            fecha: DateTime.now(),
            usuarioId: usuarioId,
          ),
        );
    await db.into(db.gastos).insert(
          GastosCompanion.insert(
            monto: 1000,
            fecha: DateTime.now(),
            usuarioId: usuarioId,
          ),
        );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: Scaffold(body: ResumenScreen())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(r'Vendiste: $5.000'), findsOneWidget);
    expect(find.text(r'Gastaste: $1.000'), findsOneWidget);
    expect(find.text(r'Por cobrar: $0'), findsOneWidget);
  });
}
```

Create `test/screens/configuracion/usuarios_screen_test.dart`:

```dart
import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/database_provider.dart';
import 'package:app_ventas/screens/configuracion/usuarios_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('crear un vendedor lo agrega a la lista', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: UsuariosScreen()),
      ),
    );

    await tester.enterText(
        find.byKey(const Key('campo_nombre_vendedor')), 'Beto');
    await tester.enterText(find.byKey(const Key('campo_pin_vendedor')), '4321');
    await tester.tap(find.byKey(const Key('boton_crear_vendedor')));
    await tester.pumpAndSettle();

    final usuarios = await db.select(db.usuarios).get();
    expect(usuarios.single.nombre, 'Beto');
    expect(usuarios.single.rol, 'vendedor');
    expect(find.text('Beto'), findsOneWidget);
  });
}
```

Create `test/screens/historial/historial_screen_test.dart`:

```dart
import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/database_provider.dart';
import 'package:app_ventas/screens/historial/historial_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('lista las ventas del día actual', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final usuarioId = await db.into(db.usuarios).insert(
          UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'x'),
        );
    await db.into(db.ventas).insert(
          VentasCompanion.insert(
            monto: 5000,
            fecha: DateTime.now(),
            usuarioId: usuarioId,
          ),
        );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: HistorialScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(r'$5.000'), findsOneWidget);
    expect(find.text('Contado'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/screens/gasto/ test/screens/home/ test/screens/configuracion/usuarios_screen_test.dart test/screens/historial/`
Expected: FAIL.

- [ ] **Step 3: Implement**

Create `lib/screens/gasto/registrar_gasto_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/repository_providers.dart';
import '../../providers/sesion_provider.dart';

class RegistrarGastoScreen extends ConsumerStatefulWidget {
  const RegistrarGastoScreen({super.key});

  @override
  ConsumerState<RegistrarGastoScreen> createState() =>
      _RegistrarGastoScreenState();
}

class _RegistrarGastoScreenState extends ConsumerState<RegistrarGastoScreen> {
  final _montoController = TextEditingController();
  final _descripcionController = TextEditingController();

  Future<void> _registrar() async {
    final monto = int.tryParse(_montoController.text.trim());
    if (monto == null || monto <= 0) return;
    final sesion = ref.read(sesionProvider).usuarioActivo!;

    await ref.read(gastoRepositoryProvider).registrarGasto(
          monto: monto,
          descripcion: _descripcionController.text.trim().isEmpty
              ? null
              : _descripcionController.text.trim(),
          usuarioId: sesion.id,
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registrar gasto')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const Key('campo_monto_gasto'),
              controller: _montoController,
              decoration: const InputDecoration(labelText: 'Monto'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              key: const Key('campo_descripcion_gasto'),
              controller: _descripcionController,
              decoration:
                  const InputDecoration(labelText: 'Descripción (opcional)'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              key: const Key('boton_registrar_gasto'),
              onPressed: _registrar,
              child: const Text('Registrar'),
            ),
          ],
        ),
      ),
    );
  }
}
```

Create `lib/providers/resumen_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../repositories/resumen_repository.dart';
import 'repository_providers.dart';

final resumenDelDiaProvider = FutureProvider.autoDispose<ResumenDia>((ref) {
  return ref.watch(resumenRepositoryProvider).resumenDelDia(DateTime.now());
});

final resumenPorVendedorProvider =
    FutureProvider.autoDispose<Map<Usuario, ResumenDia>>((ref) {
  return ref.watch(resumenRepositoryProvider).resumenPorVendedor(DateTime.now());
});
```

Create `lib/screens/home/resumen_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/resumen_providers.dart';
import '../../util/formato_moneda.dart';

class ResumenScreen extends ConsumerWidget {
  const ResumenScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resumenAsync = ref.watch(resumenDelDiaProvider);
    final porVendedorAsync = ref.watch(resumenPorVendedorProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Hoy',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          resumenAsync.when(
            data: (resumen) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Vendiste: ${formatoMoneda(resumen.totalVendido)}'),
                Text('Gastaste: ${formatoMoneda(resumen.totalGastado)}'),
                Text('Por cobrar: ${formatoMoneda(resumen.totalPorCobrar)}'),
              ],
            ),
            loading: () => const CircularProgressIndicator(),
            error: (e, st) => Text('Error: $e'),
          ),
          const SizedBox(height: 24),
          const Text('Por vendedor',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          porVendedorAsync.when(
            data: (mapa) => Column(
              children: mapa.entries
                  .map((entrada) => ListTile(
                        title: Text(entrada.key.nombre),
                        trailing: Text(formatoMoneda(entrada.value.totalVendido)),
                      ))
                  .toList(),
            ),
            loading: () => const CircularProgressIndicator(),
            error: (e, st) => Text('Error: $e'),
          ),
        ],
      ),
    );
  }
}
```

Create `lib/screens/configuracion/usuarios_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/repository_providers.dart';
import '../../providers/usuarios_providers.dart';

class UsuariosScreen extends ConsumerStatefulWidget {
  const UsuariosScreen({super.key});

  @override
  ConsumerState<UsuariosScreen> createState() => _UsuariosScreenState();
}

class _UsuariosScreenState extends ConsumerState<UsuariosScreen> {
  final _nombreController = TextEditingController();
  final _pinController = TextEditingController();

  Future<void> _crearVendedor() async {
    final nombre = _nombreController.text.trim();
    final pin = _pinController.text.trim();
    if (nombre.isEmpty || pin.length != 4 || int.tryParse(pin) == null) return;

    await ref.read(usuarioRepositoryProvider).crearUsuario(
          nombre: nombre,
          rol: 'vendedor',
          pin: pin,
        );
    _nombreController.clear();
    _pinController.clear();
    ref.invalidate(listaUsuariosProvider);
  }

  @override
  Widget build(BuildContext context) {
    final usuariosAsync = ref.watch(listaUsuariosProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Usuarios')),
      body: Column(
        children: [
          Expanded(
            child: usuariosAsync.when(
              data: (usuarios) => ListView(
                children: usuarios
                    .map((u) => ListTile(
                          key: Key('usuario_item_${u.id}'),
                          title: Text(u.nombre),
                          subtitle: Text(u.rol),
                        ))
                    .toList(),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Error: $e')),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  key: const Key('campo_nombre_vendedor'),
                  controller: _nombreController,
                  decoration:
                      const InputDecoration(labelText: 'Nombre del vendedor'),
                ),
                TextField(
                  key: const Key('campo_pin_vendedor'),
                  controller: _pinController,
                  decoration:
                      const InputDecoration(labelText: 'PIN de 4 dígitos'),
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 4,
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  key: const Key('boton_crear_vendedor'),
                  onPressed: _crearVendedor,
                  child: const Text('Agregar vendedor'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

Create `lib/providers/historial_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import 'repository_providers.dart';

final historialDelDiaProvider = FutureProvider.autoDispose<List<Venta>>((ref) {
  return ref.watch(ventaRepositoryProvider).ventasDelDia(DateTime.now());
});
```

Create `lib/screens/historial/historial_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/historial_providers.dart';
import '../../util/formato_moneda.dart';

class HistorialScreen extends ConsumerWidget {
  const HistorialScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ventasAsync = ref.watch(historialDelDiaProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Historial de hoy')),
      body: ventasAsync.when(
        data: (ventas) => ListView.builder(
          itemCount: ventas.length,
          itemBuilder: (context, index) {
            final venta = ventas[index];
            return ListTile(
              title: Text(formatoMoneda(venta.monto)),
              subtitle: Text(venta.esFiado ? 'Fiado' : 'Contado'),
              trailing: Text(
                '${venta.fecha.hour}:${venta.fecha.minute.toString().padLeft(2, '0')}',
              ),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/screens/gasto/ test/screens/home/ test/screens/configuracion/usuarios_screen_test.dart test/screens/historial/`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/screens/gasto lib/screens/home lib/screens/configuracion/usuarios_screen.dart lib/screens/historial lib/providers/resumen_providers.dart lib/providers/historial_providers.dart test/screens/gasto test/screens/home test/screens/configuracion/usuarios_screen_test.dart test/screens/historial
git commit -m "Add Registrar Gasto, Resumen, Usuarios, and Historial screens"
```

---

### Task 16: App wiring — RaizApp, HomeScreen, role-based navigation

**Files:**
- Modify: `lib/main.dart`
- Create: `lib/screens/raiz_app.dart`
- Create: `lib/screens/home/home_screen.dart`
- Modify: `test/widget_test.dart` (replace the default counter test)
- Test: `test/screens/home/home_screen_test.dart`

**Interfaces:**
- Consumes: every screen and provider from Tasks 10–15.
- Produces: `AppVentas` (root `MaterialApp`), `RaizApp` (decides login vs. home vs. first-run), `HomeScreen` (tabbed shell with role-based nav) — the app's actual entry point.

- [ ] **Step 1: Write the failing tests**

Create `test/screens/home/home_screen_test.dart`:

```dart
import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/database_provider.dart';
import 'package:app_ventas/providers/sesion_provider.dart';
import 'package:app_ventas/screens/home/home_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<ProviderContainer> _containerConSesion(
  AppDatabase db, {
  required String rol,
}) async {
  final usuarioId = await db.into(db.usuarios).insert(
        UsuariosCompanion.insert(nombre: 'Persona', rol: rol, pinHash: 'x'),
      );
  final usuario =
      await (db.select(db.usuarios)..where((u) => u.id.equals(usuarioId)))
          .getSingle();
  final container = ProviderContainer(
    overrides: [databaseProvider.overrideWithValue(db)],
  );
  container.read(sesionProvider.notifier).state =
      SesionState(usuarioActivo: usuario);
  return container;
}

void main() {
  testWidgets('el admin ve la pestaña Config', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = await _containerConSesion(db, rol: 'admin');
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Config'), findsOneWidget);
  });

  testWidgets('el vendedor no ve la pestaña Config', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = await _containerConSesion(db, rol: 'vendedor');
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Config'), findsNothing);
  });

  testWidgets('cerrar sesión limpia el usuario activo', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = await _containerConSesion(db, rol: 'admin');
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('boton_cerrar_sesion')));
    await tester.pumpAndSettle();

    expect(container.read(sesionProvider).haySesion, isFalse);
  });
}
```

Replace `test/widget_test.dart` with:

```dart
import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/main.dart';
import 'package:app_ventas/providers/database_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('primer uso muestra la pantalla de crear administrador',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const AppVentas(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Configura tu tienda'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/screens/home/home_screen_test.dart test/widget_test.dart`
Expected: FAIL — `HomeScreen`/`RaizApp` don't exist yet, `main.dart` still has the counter template.

- [ ] **Step 3: Implement**

Create `lib/screens/home/home_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/sesion_provider.dart';
import '../configuracion/productos_screen.dart';
import '../configuracion/usuarios_screen.dart';
import '../fiado/lista_fiado_screen.dart';
import '../gasto/registrar_gasto_screen.dart';
import '../historial/historial_screen.dart';
import '../venta/registrar_venta_screen.dart';
import 'resumen_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _tabActual = 0;

  @override
  Widget build(BuildContext context) {
    final sesion = ref.watch(sesionProvider);
    final usuario = sesion.usuarioActivo!;

    final tabs = <_TabInfo>[
      const _TabInfo('Resumen', Icons.dashboard, ResumenScreen()),
      const _TabInfo('Fiado', Icons.people, ListaFiadoScreen()),
      const _TabInfo('Historial', Icons.history, HistorialScreen()),
      if (sesion.esAdmin)
        const _TabInfo('Config', Icons.settings, _ConfiguracionMenu()),
    ];

    if (_tabActual >= tabs.length) _tabActual = 0;

    return Scaffold(
      appBar: AppBar(
        title: Text('Hola, ${usuario.nombre}'),
        actions: [
          IconButton(
            key: const Key('boton_cerrar_sesion'),
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(sesionProvider.notifier).cerrarSesion(),
          ),
        ],
      ),
      body: tabs[_tabActual].pantalla,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tabActual,
        onTap: (index) => setState(() => _tabActual = index),
        items: tabs
            .map((t) => BottomNavigationBarItem(icon: Icon(t.icono), label: t.titulo))
            .toList(),
      ),
      floatingActionButton: _tabActual == 0
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.extended(
                  key: const Key('boton_nueva_venta'),
                  heroTag: 'venta',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const RegistrarVentaScreen()),
                  ),
                  label: const Text('+ Venta'),
                  icon: const Icon(Icons.add_shopping_cart),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.extended(
                  key: const Key('boton_nuevo_gasto'),
                  heroTag: 'gasto',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const RegistrarGastoScreen()),
                  ),
                  label: const Text('+ Gasto'),
                  icon: const Icon(Icons.remove_shopping_cart),
                ),
              ],
            )
          : null,
    );
  }
}

class _TabInfo {
  const _TabInfo(this.titulo, this.icono, this.pantalla);

  final String titulo;
  final IconData icono;
  final Widget pantalla;
}

class _ConfiguracionMenu extends StatelessWidget {
  const _ConfiguracionMenu();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        ListTile(
          key: const Key('menu_productos'),
          title: const Text('Productos'),
          leading: const Icon(Icons.inventory),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ProductosScreen()),
          ),
        ),
        ListTile(
          key: const Key('menu_usuarios'),
          title: const Text('Usuarios'),
          leading: const Icon(Icons.group),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const UsuariosScreen()),
          ),
        ),
      ],
    );
  }
}
```

Create `lib/screens/raiz_app.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/sesion_provider.dart';
import 'home/home_screen.dart';
import 'login/crear_admin_inicial_screen.dart';
import 'login/seleccionar_usuario_screen.dart';

class RaizApp extends ConsumerWidget {
  const RaizApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sesion = ref.watch(sesionProvider);
    if (sesion.haySesion) return const HomeScreen();

    final hayUsuariosAsync = ref.watch(haySesionUsuariosProvider);
    return hayUsuariosAsync.when(
      data: (existe) => existe
          ? const SeleccionarUsuarioScreen()
          : const CrearAdminInicialScreen(),
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, st) => Scaffold(body: Center(child: Text('Error: $e'))),
    );
  }
}
```

Replace `lib/main.dart` entirely:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screens/raiz_app.dart';

void main() {
  runApp(const ProviderScope(child: AppVentas()));
}

class AppVentas extends StatelessWidget {
  const AppVentas({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App Ventas',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal),
      home: const RaizApp(),
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test`
Expected: PASS — the entire suite (all tasks' tests) passes.

- [ ] **Step 5: Full verification pass**

Run: `flutter analyze`
Expected: `No issues found!`

Run: `flutter build apk --debug`
Expected: builds successfully (compile-only check; confirms Android packaging is wired correctly even without a connected device).

- [ ] **Step 6: Commit**

```bash
git add lib/main.dart lib/screens/raiz_app.dart lib/screens/home/home_screen.dart test/widget_test.dart test/screens/home/home_screen_test.dart
git commit -m "Wire up app entry point with role-based navigation"
```

---

## Self-review notes

- **Spec coverage:** login/PIN (Tasks 5, 11), roles/permissions (Tasks 10, 16 — Config tab hidden for `vendedor`), registrar venta in few taps with products + quick amounts + free amount (Tasks 12–13), fiado with aging order and partial payments (Tasks 8, 14), gastos (Task 15), resumen diario general and per-seller (Tasks 9, 15), offline-only (no network dependency anywhere in this plan), historial (Task 15). All Fase 1 spec sections have a corresponding task.
- **Type consistency:** `Usuario`/`Producto`/`Cliente`/`Venta`/`PagoFiado`/`Gasto` (Task 2's `@DataClassName`s) are used identically across every later task; repository constructor signatures declared in each task's Interfaces block match their Step 3 implementation; `ClienteConSaldo` and `ResumenDia` are defined once (Tasks 8, 9) and reused as-is in providers/screens.
- **No placeholders:** every step has runnable code, not a description.
