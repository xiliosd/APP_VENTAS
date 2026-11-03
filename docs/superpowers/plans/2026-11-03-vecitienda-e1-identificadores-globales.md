# VeciTienda E1 — Identificadores globales — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every synchronizable row in the local database gets a stable, globally unique id
(`id_global`, UUID v4 text), assigned automatically on insert and backfilled for existing stores,
with no visible change in the app.

**Architecture:** Keep the existing local integer `id` primary keys and foreign keys untouched
(they stay local to each phone; changing them would rewrite every repository, provider, screen
and ~1190 tests). Add a second column `id_global TEXT NOT NULL` with a unique index to the 15
synchronizable tables, through a Drift table mixin whose `clientDefault` generates a UUID v4.
The E2 sync layer will translate local ids ↔ `id_global` when sending and receiving rows. This is
the "esquema equivalente" the spec (§6) allows instead of replacing the primary keys.
`configuracion_tienda` (single row, id 1) does not get the column: in E2 it is keyed by the store.

**Tech Stack:** Flutter 3.47.2, Drift ^2.34.3 (+ drift_dev, build_runner), sqlite3, flutter_test.
No new dependency: the UUID v4 generator is ~10 lines over `Random.secure()`.

**Spec:** `docs/superpowers/specs/2026-11-03-vecitienda-tienda-compartida-design.md` (§6 first
bullet, §7 call 1 "E1").

## Global Constraints

- Schema version goes from 10 to **11**; existing stores (v1…v10) must open with all data intact.
- No new package dependencies.
- Names in Spanish, descriptive, no abbreviations (lineamientos 03): column `idGlobal`
  (`id_global` in SQL), mixin `ConIdGlobal`, function `generarIdGlobal()`.
- `dart format` only on touched files; `flutter analyze` with no new issues; full `flutter test`
  green before each commit.
- Conventional Commits, ending with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`;
  commit and push directly to `master` (personal project).
- No visible UI change in E1.

## Review Focus

1. **Restoring an old backup file (v1–v10) on an E1 phone** — it must open, migrate and every row
   must get a distinct `id_global`. Test added in Task 3.
2. **Two rows inserted in the same millisecond / large stores** — ids must stay unique; the
   backfill must not reuse one value for many rows (e.g. a SQL `DEFAULT` evaluated once). Tests
   in Tasks 1 and 3.
3. **Updates must never change `id_global`** — `.write()` with a companion, corrections and
   annulments keep the original value. Test in Task 2.
4. **Code that builds data classes by hand** (tests, fakes) must compile with the new required
   field. Covered by running the full suite in Task 2.
5. **Interrupted migration** — the backfill runs inside Drift's migration transaction, so a crash
   leaves the base at v10 and the next open retries. Pinned by asserting `user_version` is 11
   only after the backfill (Task 3).

---

## File Structure

- Create `lib/util/id_global.dart` — `generarIdGlobal()` (UUID v4 text).
- Modify `lib/data/database.dart` — mixin `ConIdGlobal`, apply it to 15 tables, unique indexes,
  `schemaVersion => 11`, migration step `desde < 11`.
- Regenerate `lib/data/database.g.dart` (`dart run build_runner build --delete-conflicting-outputs`).
- Create `test/util/id_global_test.dart`.
- Create `test/support/esquema_v10.dart` — `crearBaseV10(ruta)` = v9 + `clientes.apellido`.
- Modify `test/data/migracion_test.dart`, `test/data/database_test.dart`.
- Modify tests that construct data classes by hand (compiler will list them; currently
  `test/util/nombre_cliente_test.dart`, `permisos_test.dart`, `orden_productos_test.dart`,
  `extracto_fiado_test.dart`, `catalogo_producto_test.dart`, `aviso_existencias_test.dart`,
  `test/providers/ticket_provider_test.dart`, `test/screens/correccion/texto_correccion_test.dart`,
  `test/screens/configuracion/nombre_tienda_test.dart`).
- Modify `README.md` (Arquitectura: one line on `id_global`) and `docs/hoja-de-ruta.md`.

The 15 tables: `usuarios, productos, proveedores, productos_proveedores, conteos_inventario,
entradas_mercancia, lineas_entrada, pedidos, lineas_pedido, clientes, ventas, lineas_venta,
pagos_fiado, gastos, correcciones`.

---

### Task 1: UUID v4 generator

**Files:**
- Create: `lib/util/id_global.dart`
- Test: `test/util/id_global_test.dart`

**Interfaces:**
- Produces: `String generarIdGlobal()` — lowercase RFC 4122 v4, 36 chars.

- [ ] **Step 1: Write the failing tests**

```dart
final formatoV4 = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');

test('genera un UUID v4 en minúsculas', () {
  expect(generarIdGlobal(), matches(formatoV4));
});

test('10 000 ids seguidos no se repiten', () {
  final ids = {for (var i = 0; i < 10000; i++) generarIdGlobal()};
  expect(ids.length, 10000);
});
```

- [ ] **Step 2: Run** `flutter test test/util/id_global_test.dart` — Expected: FAIL (undefined).
- [ ] **Step 3: Implement** `generarIdGlobal()` with a top-level `Random.secure()`: 16 random
  bytes, set byte 6 to `(b & 0x0f) | 0x40` and byte 8 to `(b & 0x3f) | 0x80`, hex-encode with
  dashes 8-4-4-4-12. Doc comment: why it exists (ids that don't collide between phones of the
  same store, E2 sync).
- [ ] **Step 4: Run** the test — Expected: PASS.
- [ ] **Step 5: Commit** `feat: add a generator for global ids shared across phones`

---

### Task 2: `id_global` column on new databases

**Files:**
- Modify: `lib/data/database.dart`, `lib/data/database.g.dart` (generated)
- Test: `test/data/database_test.dart`; hand-built data classes in the tests listed above

**Interfaces:**
- Consumes: `generarIdGlobal()` (Task 1).
- Produces: every data class of the 15 tables has `String idGlobal`; companions have
  `Value<String> idGlobal` (absent → generated on insert). Unique index per table named
  `<tabla>_id_global` (e.g. `ventas_id_global`). `AppDatabase.schemaVersion == 11`.
  Task 3 relies on these index names and on the constant list
  `const tablasConIdGlobal = <String>['usuarios', ..., 'correcciones']` (the 15 SQL names,
  exported from `database.dart`) to drive the backfill.

- [ ] **Step 1: Write the failing tests** in `test/data/database_test.dart`:

```dart
test('cada fila nueva recibe un id global distinto', () async {
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  final usuario = await db.into(db.usuarios).insert(
      UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'x'));
  for (var i = 0; i < 3; i++) {
    await db.into(db.ventas).insert(VentasCompanion.insert(
        monto: 1000, fecha: DateTime(2026, 11, 3), usuarioId: usuario));
  }
  final ids = (await db.select(db.ventas).get()).map((v) => v.idGlobal).toSet();
  expect(ids.length, 3);
  expect(ids.every((id) => id.length == 36), isTrue);
});

test('editar una fila no cambia su id global', () async {
  // insert a cliente, read idGlobal, then
  // (db.update(db.clientes)..where((c) => c.id.equals(id)))
  //     .write(const ClientesCompanion(telefono: Value('300')));
  // expect same idGlobal after reading again
});

test('dos filas no pueden tener el mismo id global', () async {
  // insert two clientes with ClientesCompanion.insert(nombre: .., idGlobal: Value('fijo'))
  // second insert -> throwsA(isA<SqliteException>())
});

test('la base está en la versión 11', () {
  expect(AppDatabase(NativeDatabase.memory()).schemaVersion, 11); // close in tearDown
});
```

Also change the `expect(db.schemaVersion, 10)` in `migracion_test.dart` ("una base nueva guarda
el medio de pago…") to `11`.

- [ ] **Step 2: Run** `flutter test test/data/database_test.dart` — Expected: compile FAIL
  (`idGlobal` undefined).
- [ ] **Step 3: Implement** in `database.dart`:
  - `mixin ConIdGlobal on Table { TextColumn get idGlobal => text().clientDefault(generarIdGlobal)(); }`
    with a comment on the why (the local `id` stays per phone; `idGlobal` is what phones of a
    shared store agree on — spec §6).
  - Apply `with ConIdGlobal` to the 15 tables; add `@TableIndex(name: '<tabla>_id_global',
    columns: {#idGlobal}, unique: true)` to each.
  - `tablasConIdGlobal` constant; `schemaVersion => 11`.
  - Leave `onUpgrade` for Task 3 (fresh databases use `createAll`).
  - Run `dart run build_runner build --delete-conflicting-outputs`.
- [ ] **Step 4: Fix hand-built data classes** — run `flutter analyze`; for each
  "missing required argument idGlobal" add `idGlobal: 'id-<n>'` (any distinct literal).
- [ ] **Step 5: Run** `flutter test test/data/database_test.dart` — Expected: PASS. Tests that
  open migrated v≤10 bases will fail until Task 3 adds the migration step; that is expected.
- [ ] **Step 6: No commit here.** Tasks 2 and 3 are one commit (the suite is only green with
  both); the reviewer gate for Task 2 checks the diff and `database_test.dart`, then Task 3
  starts on the same working tree.

---

### Task 3: Migration v10 → v11 with backfill

**Files:**
- Modify: `lib/data/database.dart` (`onUpgrade`)
- Create: `test/support/esquema_v10.dart`
- Test: `test/data/migracion_test.dart`, `test/respaldo/` (restore of an old copy)

**Interfaces:**
- Consumes: `tablasConIdGlobal`, index names `<tabla>_id_global`, `generarIdGlobal()`.
- Produces: `void crearBaseV10(String ruta)` test helper (v9 + `ALTER TABLE clientes ADD COLUMN
  apellido TEXT NULL`, `userVersion = 10`).

- [ ] **Step 1: Write the failing tests** in `migracion_test.dart`:

```dart
test('una base v10 abre en v11 con un id global distinto en cada fila', () async {
  final archivo = File('${carpeta.path}/v10.sqlite');
  crearBaseV10(archivo.path);
  final db = AppDatabase(NativeDatabase(archivo));
  addTearDown(db.close);
  for (final tabla in tablasConIdGlobal) {
    final filas = await db.customSelect('SELECT id_global FROM $tabla').get();
    final ids = filas.map((f) => f.read<String>('id_global')).toList();
    expect(ids.every((id) => id.length == 36), isTrue, reason: tabla);
    expect(ids.toSet().length, ids.length, reason: tabla);
  }
  expect((await db.select(db.clientes).getSingle()).nombre, 'Don Pedro');
});

test('una base v10 con 500 ventas recibe 500 ids distintos', () async {
  // crearBaseV10, then with sqlite3 insert 500 ventas rows before opening with AppDatabase;
  // expect 500 distinct id_global in ventas.
});

test('una base v1 abre en v11 y guarda filas nuevas con id global', () async {
  // crearBaseV1 → open → insert a cliente → its idGlobal has length 36;
  // existing rows have distinct non-empty idGlobal.
});

test('una base v10 migrada tiene las mismas columnas que una base nueva', () async {
  // replace the existing v9 variant: crearBaseV10 + columnasPorTabla(migrada) == nueva
});

test('una base v10 migrada tiene los índices únicos de id global', () async {
  // for each tabla: PRAGMA index_list('$tabla') contains '<tabla>_id_global' with unique = 1
});

test('la migración deja la versión 11 solo con todas las filas llenas', () async {
  // after opening a v10 base: PRAGMA user_version == 11 and
  // no row in any tablasConIdGlobal has id_global = ''
});
```

In the restore tests under `test/respaldo/`, add: a copy made with `crearBaseV10` passes
`CopiaBaseDatos.esCopiaValida(..., versionMaxima: 11)`, and after `Restaurador.restaurar` and
reopening `AppDatabase`, every row of `ventas` has a distinct `idGlobal`. Follow the existing
restore test's fakes.

- [ ] **Step 2: Run** `flutter test test/data/migracion_test.dart` — Expected: FAIL (no
  `id_global` column on migrated bases).
- [ ] **Step 3: Implement** the `if (desde < 11)` step in `onUpgrade`, for each table in
  `tablasConIdGlobal`:
  1. `customStatement("ALTER TABLE $tabla ADD COLUMN id_global TEXT NOT NULL DEFAULT ''")`
     (SQLite cannot add a NOT NULL column without a default; `''` is only a placeholder).
  2. Read all `id`s, then `UPDATE $tabla SET id_global = ? WHERE id = ?` with
     `generarIdGlobal()` per row (one value per row — never a single SQL default).
  3. Create the unique index (`m.createIndex(...)` with the generated index object).
  Runs inside Drift's migration transaction. Bases from v1…v9 also pass through this step,
  after the earlier steps created their tables (tables created by `m.createTable` in this same
  upgrade already have the column — skip `ALTER` when `PRAGMA table_info` already lists
  `id_global`, as the v5 step does for `costoUnitario`).
- [ ] **Step 4: Run** `flutter test test/data/` and `flutter test test/respaldo/` — Expected: PASS.
- [ ] **Step 5: Run the full suite** `flutter test` — Expected: all green. `flutter analyze` —
  no new issues. `dart format` on touched files.
- [ ] **Step 6: Commit** (Tasks 2 + 3 together) `feat: give every synchronizable row a global id
  and backfill it for existing stores`

---

### Task 4: Docs and phone check

**Files:**
- Modify: `README.md` (section "Arquitectura", after the `lib/data/` line), `docs/hoja-de-ruta.md`
  (paso 6: "E1 — identificadores globales hecho el <fecha>"; "Pendiente de verificar": E1).

- [ ] **Step 1:** README line: each synchronizable row has `id_global` (UUID v4) besides its local
  `id`; local ids never leave the phone, the shared store (E2) uses `id_global`.
- [ ] **Step 2:** Build the release APK
  `flutter build apk --release --dart-define-from-file=dart_defines.json` — Expected: built.
- [ ] **Step 3:** Ask the user to install it over the current app on the Redmi and confirm that
  sales, fiado, inventory and reports look the same, and that a backup still uploads.
- [ ] **Step 4: Commit and push** `docs: note global ids in the README and roadmap`, then
  `git push origin master`.
