# VeciTienda E2 — Nube y sincronización del admin — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The admin can turn a single-phone store into a **shared store** stored in Supabase;
every change made on any of the admin's phones syncs both ways (also after being offline), and a
new phone recovers the shared store with the admin's email code. No vendor yet (E3).

**Architecture:**
- **Local outbox by SQLite triggers.** Triggers on the 15 tables with `id_global`, plus
  `configuracion_tienda`, write `(tabla, id_global, borrado)` into a local `cambios_pendientes`
  table. They only write while the store is shared and the app is not applying remote rows.
  No repository changes. Hard deletes become tombstones for free.
- **One generic cloud table `filas`.** Each row is `(tienda_id, tabla, id_global, datos jsonb,
  borrado, version)`. `datos` holds the raw SQLite values of the row without the local `id`.
  Each foreign key is replaced by the referenced row's `id_global`. A per-store advisory lock
  plus a global sequence gives every write a `version` that commits in order, and that version
  is the pull cursor.
- **Conflicts: last write wins by arrival at the server** (spec §7 call 2). A row with a local
  pending change is not overwritten by a pull, because it gets pushed next.
- **Sync cycle:** check the protocol version, push the outbox, pull from the cursor, then apply
  everything in one transaction. Parents are applied before children; deletes run in reverse
  order.
- **Same Supabase session as the file backup** (admin's email OTP). Once a store is shared, the
  file backup stops (spec §5).

**Tech Stack:** Flutter 3.47.2, Drift ^2.34.3, supabase_flutter 2.18.0 (PostgREST + RPC),
Postgres 17 on Supabase (RLS), flutter_test. **No new Dart dependencies.**

**Spec:** `docs/superpowers/specs/2026-11-03-vecitienda-tienda-compartida-design.md` (§5, §6,
§7 calls 2, 3, 7, 8, 10–14). E1 plan, for context:
`docs/superpowers/plans/2026-11-03-vecitienda-e1-identificadores-globales.md`.

## Global Constraints

- Local schema 11 → **12**. Every upgrade step runs inside the existing `transaction()` wrapper
  in `onUpgrade` (E1 fix).
- Protocol version constant `versionProtocoloSincronizacion = 1`. The cloud table
  `configuracion_app` has row `('version_protocolo_minima', '1')`. A phone below the minimum
  stops syncing, shows **"Actualiza la app para seguir sincronizando"** and keeps selling.
- The following never go to the cloud: huella, letter size, theme, recorrido, consejos (spec §7
  call 8). They live in SharedPreferences, so this holds by construction.
- Supabase project `ngphwbykbrjqhgnssnjn`. Every SQL change is also saved as a file under
  `supabase/migrations/` and applied with the Supabase MCP `apply_migration`. After each one,
  run `get_advisors(security)`; it must report no new ERROR-level findings.
- RLS on every new public table. No table is writable by the `anon` role.
- User-facing copy is in Spanish; no raw `Error: $e` (follow the existing friendly-error helpers
  in `lib/respaldo/`).
- Naming follows lineamientos 03, in Spanish without abbreviations. Before each commit: tests
  first, `dart format` **only on touched files**, `flutter analyze` with no issues, full
  `flutter test` green.
- Conventional Commits ending with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
  Commit and push straight to `master`.
- Logs must never print row data, emails or tokens.

## Review Focus

1. **A phone that is offline for days** collects many changes. The next sync must push all of
   them, in batches, without losing any. Test in Task 5 (1 200 pending rows, batches of 500).
2. **A row edited locally between push and pull** must not be overwritten by the older remote
   copy. Test in Task 5.
3. **A network error in the middle of a push** leaves pending rows that were not confirmed
   still pending. Rows changed again during the upload stay pending: the `cambio` counter
   prevents losing them. Test in Task 5.
4. **"Deshacer" a sale and the line replacement** done by `productos_proveedores` and
   `lineas_pedido` must propagate as deletes, and must never leave a child row pointing at a
   missing parent. Test in Task 5.
5. **Stock must match on both phones** after a sync, even when local ids differ. The tie-break
   for counts with the same `fecha` must not depend on local `id`. Test in Task 2.

---

## File Structure

- `lib/data/database.dart` — tables `CambiosPendientes` and `EstadoSincronizacion`; triggers;
  v12 step.
- `lib/data/disparadores_sincronizacion.dart` — SQL for the triggers (one builder function).
- `lib/sincronizacion/filas_sincronizables.dart` — FK map, table order, `leerFila`,
  `aplicarFila`, `aplicarBorrado`.
- `lib/sincronizacion/nube_tienda.dart` — `NubeTienda` interface plus value types.
- `lib/sincronizacion/supabase_nube_tienda.dart` — Supabase implementation.
- `lib/sincronizacion/sincronizador.dart` — `Sincronizador` (sync cycle, convert, download).
- `lib/sincronizacion/sincronizacion_provider.dart` — Riverpod notifier, triggers and state.
- `lib/respaldo/respaldo_provider.dart` — skip the file backup when the store is shared.
- `lib/screens/respaldo/respaldo_screen.dart`, `verificar_correo_screen.dart` — UI.
- `lib/repositories/inventario_repository.dart` — deterministic tie-break.
- `supabase/migrations/20261103000000_tienda_compartida.sql` — cloud schema.
- Tests:
  - `test/data/disparadores_sincronizacion_test.dart`
  - `test/sincronizacion/filas_sincronizables_test.dart`
  - `test/sincronizacion/sincronizador_test.dart`
  - `test/sincronizacion/sincronizacion_provider_test.dart`
  - `test/support/nube_tienda_falsa.dart`
  - `test/support/esquema_v11.dart`
  - updates in `test/data/migracion_test.dart`, `test/screens/respaldo/*`,
    `test/respaldo/respaldo_provider_test.dart`

---

### Task 1: Local outbox (schema v12 + triggers)

**Files:** `lib/data/database.dart`, `lib/data/disparadores_sincronizacion.dart`,
`test/support/esquema_v11.dart`, `test/data/disparadores_sincronizacion_test.dart`,
`test/data/migracion_test.dart`

**Interfaces:**
- Produces these Drift tables:
  - `CambiosPendientes` (SQL `cambios_pendientes`):
    - `id` int autoincrement
    - `tabla` text
    - `idGlobal` text
    - `borrado` bool
    - `cambio` int, default 1
    - unique key `{tabla, idGlobal}`
  - `EstadoSincronizacion` (SQL `estado_sincronizacion`, single row `id = 1`):
    - `tiendaId` text
    - `cursor` int, default 0
    - `aplicando` bool, default false
    - `ultimaSincronizacion` dateTime nullable
- Neither table gets `ConIdGlobal`, and neither is added to `tablasConIdGlobal`.
- `List<String> sentenciasDisparadores()` returns the `CREATE TRIGGER IF NOT EXISTS ...`
  statements. It is called from `onCreate` (after `createAll`) and from the `desde < 12` step.
- Trigger names are `sincronizar_<tabla>_<insercion|edicion|borrado>`.
- Body of each trigger:
  `INSERT INTO cambios_pendientes (tabla, id_global, borrado, cambio) VALUES ('<tabla>',
  NEW|OLD.id_global, 0|1, 1) ON CONFLICT (tabla, id_global) DO UPDATE SET borrado =
  excluded.borrado, cambio = cambios_pendientes.cambio + 1`
- Guard on each trigger:
  `WHEN EXISTS (SELECT 1 FROM estado_sincronizacion WHERE id = 1 AND aplicando = 0)`
- `configuracion_tienda` triggers (insert and update only) write `id_global = 'unica'`.
- Constant `idGlobalConfiguracion = 'unica'`.

- [ ] **Step 1: Write failing tests** (`disparadores_sincronizacion_test.dart`, in-memory DB):
  - `sin tienda compartida no se anota ningún cambio`: insert a cliente, then expect
    `cambios_pendientes` to be empty.
  - `con tienda compartida se anotan altas, ediciones y borrados`:
    - Insert `estado_sincronizacion (id 1, tienda_id 't')`.
    - Insert a cliente: expect one row with `borrado false` and `cambio 1`.
    - Edit it: expect `cambio 2`.
    - Delete it with a raw `DELETE`: expect `borrado true` and `cambio 3`.
  - `mientras se aplican cambios de la nube no se anota nada`: with `aplicando = 1`, insert a
    cliente and expect zero pending rows.
  - `la configuración de la tienda se anota como 'unica'`.
  - `una base v11 abre en v12 con los disparadores`:
    - Create the base with `crearBaseV11` (v10 helper plus `id_global` plus unique indexes, the
      same SQL as the E1 step, `userVersion = 11`).
    - Expect `sqlite_master` to list 47 triggers (15×3 + 2), and the two new tables to exist.
  - In `migracion_test.dart`: the "same columns as a fresh base" test uses v11.
- [ ] **Step 2: Run** `flutter test test/data/` — Expected: FAIL (tables/triggers missing).
- [ ] **Step 3: Implement** the tables, `sentenciasDisparadores()`, `schemaVersion => 12`,
  `onCreate: (m) async { await m.createAll(); for (s in sentenciasDisparadores())
  await customStatement(s); }`, and the `desde < 12` step (create both tables, then the
  triggers). Run `build_runner`.
- [ ] **Step 4: Run** `flutter test test/data/` — Expected: PASS. Then the full suite —
  Expected: green.
- [ ] **Step 5: Commit** `feat: record local changes for the shared store with database
  triggers`

---

### Task 2: Row serialization and application

**Files:** `lib/sincronizacion/filas_sincronizables.dart`,
`test/sincronizacion/filas_sincronizables_test.dart`,
`lib/repositories/inventario_repository.dart` (tie-break)

**Interfaces:**
- Consumes: `tablasConIdGlobal` (its order is already parent-before-child), `idGlobalConfiguracion`.
- Produces:
  - `const Map<String, Map<String, String>> llavesForaneas` — table → {column → referenced
    table}. The entries:
    - `productos_proveedores` {producto_id: productos, proveedor_id: proveedores}
    - `conteos_inventario` {producto_id, usuario_id}
    - `entradas_mercancia` {proveedor_id, usuario_id, anulada_por_id: usuarios}
    - `lineas_entrada` {entrada_id: entradas_mercancia, producto_id}
    - `pedidos` {proveedor_id, usuario_id, entrada_id}
    - `lineas_pedido` {pedido_id, producto_id}
    - `ventas` {producto_id, cliente_id, usuario_id}
    - `lineas_venta` {venta_id, producto_id}
    - `pagos_fiado` {cliente_id, usuario_id}
    - `gastos` {usuario_id, entrada_id}
    - `correcciones` {usuario_id}
  - `correcciones.movimiento_id` is translated by `tipo_movimiento`: `venta` → `ventas`,
    `abono` → `pagos_fiado`, `gasto` → `gastos`.
  - `Future<Map<String, Object?>?> leerFila(AppDatabase db, String tabla, String idGlobal)`.
    Returns null if the row does not exist. The map has every column except `id`; FK values
    are ints replaced by the referenced `id_global` (null stays null).
  - For `configuracion_tienda`, `leerFila` returns `{nombre_tienda, imagen_qr}`, with the blob
    as base64.
  - `Future<void> aplicarFila(AppDatabase db, String tabla, Map<String, Object?> datos)`
    translates FK `id_global` → local `id` and upserts by `id_global` with
    `INSERT ... ON CONFLICT(id_global) DO UPDATE`. If a referenced row is missing it throws
    `FilaHuerfana(tabla, columna, idGlobal)`.
  - `Future<void> aplicarBorrado(AppDatabase db, String tabla, String idGlobal)`.
  - Neither function touches `estado_sincronizacion.aplicando`; the caller sets it.
  - Columns come from `PRAGMA table_info` (cached per table), so new columns in later schemas
    need no code change here.

- [ ] **Step 1: Write failing tests**. Use two in-memory DBs, A and B. Seed B with a different
  number of previous rows so the local ids differ.
  - `una venta con líneas pasa de un celular a otro con sus referencias`:
    - In A: usuario, cliente, producto, venta (fiado), and two lineas_venta.
    - `leerFila` each, in table order, then `aplicarFila` into B.
    - In B: the venta's `cliente_id` points to the cliente with the same `id_global`; the lines
      point to B's venta; `monto` and `fecha` are equal.
  - `aplicar dos veces la misma fila la actualiza sin duplicarla`.
  - `una corrección apunta al movimiento correcto en el otro celular`: for each
    `TipoMovimiento`.
  - `una fila cuyo padre no llegó lanza FilaHuerfana`.
  - `un borrado quita la fila` (lineas_venta, then the venta).
  - `la configuración viaja con nombre e imagen del QR`.
  - `las existencias son iguales en dos celulares con ids locales distintos`:
    - Two conteos of the same product with the same `fecha`, inserted in opposite order on A
      and B (both via `aplicarFila`).
    - Expect `InventarioRepository.existencias` to be equal on both.
    - Change the tie-break at `inventario_repository.dart:151-160` from `c.id` to `c.idGlobal`.
- [ ] **Step 2: Run** `flutter test test/sincronizacion/filas_sincronizables_test.dart` —
  Expected: FAIL.
- [ ] **Step 3: Implement** as specified. DateTimes are stored as int seconds (no `build.yaml`),
  so raw values round-trip unchanged. Bools are 0/1.
- [ ] **Step 4: Run** the tests, then `flutter test test/repositories/` — Expected: PASS.
- [ ] **Step 5: Commit** `feat: serialize rows with global references for the shared store`

---

### Task 3: Cloud schema in Supabase

**Files:** `supabase/migrations/20261103000000_tienda_compartida.sql` (applied with MCP
`apply_migration`, name `tienda_compartida`)

**Interfaces (SQL, all in `public`):**
- `tiendas(id uuid pk default gen_random_uuid(), nombre text not null default '',
  creada_en timestamptz not null default now())`
- `miembros(tienda_id uuid references tiendas on delete cascade, usuario_id uuid references
  auth.users on delete cascade, rol text check (rol in ('admin','vendedor')), estado text check
  (estado in ('pendiente','aprobado','rechazado','revocado')), revocado_en timestamptz,
  creado_en timestamptz default now(), primary key (tienda_id, usuario_id))`. E3 adds phone
  details; E2 only creates the admin row.
- `filas`:
  - columns:
    - `tienda_id uuid references tiendas on delete cascade`
    - `tabla text not null`
    - `id_global text not null`
    - `datos jsonb`
    - `borrado boolean not null default false`
    - `version bigint not null`
    - `actualizado_en timestamptz not null default now()`
    - `actualizado_por uuid default auth.uid()`
  - `primary key (tienda_id, tabla, id_global)`
  - index `filas_tienda_version (tienda_id, version)`
- `create sequence filas_version_seq`. A trigger `BEFORE INSERT OR UPDATE ON filas` takes
  `pg_advisory_xact_lock(hashtextextended(new.tienda_id::text, 0))`, then sets
  `new.version := nextval('filas_version_seq')` and `new.actualizado_en := now()`.
  The per-store lock is held until commit, so versions of one store commit in order and a
  reader's cursor can never skip a row.
- `configuracion_app(clave text pk, valor text not null)` with the row
  `('version_protocolo_minima','1')`.
- `es_miembro_aprobado(p_tienda uuid) returns boolean`: `language sql stable security definer
  set search_path = ''`, true when a `miembros` row exists with `usuario_id = auth.uid()` and
  `estado = 'aprobado'`.
- `crear_tienda(p_nombre text) returns uuid`: `security definer set search_path = ''`.
  - Refuses anonymous users (`(auth.jwt()->>'is_anonymous')::boolean`) and null `auth.uid()`.
  - If the caller is already `admin` of a store, it returns that store's id (idempotent).
  - Otherwise it inserts the store and the admin row with `aprobado`.
  - `revoke execute ... from anon`.
- `mi_tienda() returns uuid`: `security definer`; returns the store where the caller is an
  approved admin, or null.
- RLS enabled on all four tables:
  - `tiendas`: select and update for `es_miembro_aprobado(id)`.
  - `miembros`: select for `usuario_id = auth.uid()`.
  - `filas`: select, insert and update `to authenticated` with `es_miembro_aprobado(tienda_id)`
    in `using` and `with check`. No delete policy.
  - `configuracion_app`: select `to authenticated`.

- [ ] **Step 1: Write the verification SQL first** (save it as
  `supabase/tests/tienda_compartida_prueba.sql`). It runs in a transaction ending in
  `ROLLBACK`:
  - Create two auth users A and B (insert into `auth.users` with minimal columns).
  - `set local role authenticated; set local request.jwt.claims = '{"sub":"<A>","role":"authenticated"}'`.
  - `select crear_tienda('Prueba')` twice returns the same id.
  - Insert two `filas` and check their versions increase.
  - Switch claims to B: `select count(*) from filas` must be 0, and the insert into A's store
    must fail with an RLS error.
- [ ] **Step 2: Run it before the migration** with MCP `execute_sql` — Expected: error
  (`crear_tienda` does not exist).
- [ ] **Step 3: Apply** the migration with MCP `apply_migration`; save the same SQL in the file.
- [ ] **Step 4: Run** the verification SQL — Expected: every check holds and the transaction
  rolls back. Run `get_advisors(security)` — Expected: no ERROR on the new objects.
- [ ] **Step 5: Commit** `feat: add the cloud schema for shared stores`

---

### Task 4: Cloud client

**Files:** `lib/sincronizacion/nube_tienda.dart`, `lib/sincronizacion/supabase_nube_tienda.dart`,
`test/support/nube_tienda_falsa.dart`, `test/sincronizacion/nube_tienda_falsa_test.dart`

**Interfaces:**
- `class FilaNube { final String tabla; final String idGlobal; final Map<String, Object?>?
  datos; final bool borrado; final int version; }`
- `class CambioSubida { final String tabla; final String idGlobal; final Map<String, Object?>?
  datos; final bool borrado; }`
- Exceptions `ErrorSinConexion` and `ErrorSesionTienda`.
- `abstract interface class NubeTienda`:
  - `Future<String> crearTienda(String nombre)`
  - `Future<String?> miTienda()`
  - `Future<int> versionProtocoloMinima()`
  - `Future<void> subir(String tiendaId, List<CambioSubida> cambios)` — one upsert,
    `onConflict: 'tienda_id,tabla,id_global'`
  - `Future<List<FilaNube>> bajar(String tiendaId, {required int desde, int limite = 500})` —
    `version > desde`, ordered by version
- `SupabaseNubeTienda(SupabaseClient)` maps errors:
  - `SocketException` and `AuthRetryableFetchException` → `ErrorSinConexion`
  - a 401/JWT error → `ErrorSesionTienda`
- `nubeTiendaProvider = Provider<NubeTienda?>`, null when `!ConfigRespaldo.configurado`.
- `NubeTiendaFalsa` (test support) keeps a store in memory and assigns increasing versions.
  It can be told to fail: `fallarAlSubirDespuesDe` (n rows), `sinConexion`, and
  `versionMinima`. It records `subidas`.

- [ ] **Step 1: Write failing tests** for the fake, so it matches the server's behaviour
  (`nube_tienda_falsa_test.dart`):
  - Upsert keeps one row per key and raises its version.
  - `bajar` returns `version > desde` in order and respects `limite`.
- [ ] **Step 2: Run** — Expected: FAIL.
- [ ] **Step 3: Implement** the interface, the fake and `SupabaseNubeTienda`. The real client is
  checked manually in Task 7 against the Task 3 schema; there is no unit test against the
  network.
- [ ] **Step 4: Run** — Expected: PASS. `flutter analyze` clean.
- [ ] **Step 5: Commit** `feat: add the cloud client for shared stores`

---

### Task 5: Sync engine

**Files:** `lib/sincronizacion/sincronizador.dart`, `test/sincronizacion/sincronizador_test.dart`

**Interfaces:**
- Consumes the Task 1 tables, the Task 2 functions and `NubeTienda` (Task 4).
- Produces:
  - `const versionProtocoloSincronizacion = 1`
  - `enum ResultadoSincronizacion { alDia, sinConexion, actualizarApp, sesionVencida,
    noCompartida }`
  - `class Sincronizador { Sincronizador(this.db, this.nube); ... }` with:
    - `Future<bool> esCompartida()`
    - `Future<void> convertirEnCompartida(String nombreTienda)`:
      - calls `crearTienda`
      - writes `estado_sincronizacion (1, tiendaId, cursor 0)`
      - enqueues every existing row of the 15 tables plus `'unica'` with
        `INSERT INTO cambios_pendientes SELECT ...`
      - calls `sincronizar()`
    - `Future<void> descargarTienda(String tiendaId)`, for a fresh phone:
      - requires that the local DB has no `usuarios`; otherwise it throws `StateError`
      - writes the estado row and pulls everything
    - `Future<ResultadoSincronizacion> sincronizar()`
    - `Future<int> cuantosPendientes()`
- Algorithm of `sincronizar()`, in this order:
  1. If not shared, return `noCompartida`. If `versionProtocoloMinima() >
     versionProtocoloSincronizacion`, return `actualizarApp` (push nothing).
  2. **Push** in batches of 500 pending rows ordered by `id`:
     - For each row, `leerFila` (or a tombstone when `borrado`, or when the row has
       disappeared), then `subir`.
     - After success, delete exactly the uploaded rows still at the same `cambio`:
       `DELETE ... WHERE tabla = ? AND id_global = ? AND cambio = ?`.
  3. **Pull** pages of 500 from `cursor` until a page has fewer than 500. Keep the highest
     version.
  4. **Apply** in one Drift `transaction`:
     - set `aplicando = 1`
     - drop remote rows whose key is still in `cambios_pendientes` (a local change made after
       step 2 wins and is pushed next time)
     - apply upserts in `tablasConIdGlobal` order, then `configuracion_tienda`
     - apply tombstones in reverse order
     - set `cursor`, `ultimaSincronizacion = now` and `aplicando = 0`
  5. Map `ErrorSinConexion` to `sinConexion` and `ErrorSesionTienda` to `sesionVencida`. On any
     error during apply, the transaction rolls back, so the cursor and the data stay as they
     were.
- A `FilaHuerfana` during apply means the server data is inconsistent. Rethrow it; do not
  advance the cursor.

- [ ] **Step 1: Write failing tests**. Use two in-memory DBs, A and B, and one
  `NubeTiendaFalsa`.
  - `convertir sube todo lo que había en la tienda`: A has a venta with lines, a cliente and a
    gasto. After conversion the fake holds every row, and pending is 0.
  - `una venta hecha en A aparece en B después de sincronizar ambos`: the result is that B's
    resumen totals equal A's.
  - `B nuevo descarga la tienda completa`: after `descargarTienda`, B has the same usuarios
    (with `pin_hash`), the store name and the QR.
  - `sin conexión no se pierde nada y luego se sube`: with `sinConexion`, the result is
    `sinConexion` and the pending rows are kept; after reconnecting, the result is `alDia`.
  - `1 200 cambios pendientes se suben en lotes`: expect 3 `subidas` and 0 pending.
  - `un fallo a mitad de la subida deja pendientes los no confirmados`:
    `fallarAlSubirDespuesDe` the first batch.
  - `un cambio hecho durante la subida sigue pendiente`: bump `cambio` between `leerFila` and
    the delete, using a hook in the fake that runs a write on A during `subir`.
  - `un cambio local hecho después de subir no lo pisa la copia de la nube`.
  - `deshacer una venta en A la borra en B con sus líneas`, and the same for replacing a
    product's suppliers (`ProductoRepository`) and the lines of a pedido.
  - `lo mismo editado en ambos celulares: gana el último que sube`: A and B edit a cliente's
    phone; A syncs, then B syncs; after both sync again, both show B's value.
  - `con una versión mínima mayor no sincroniza y lo dice`: the result is `actualizarApp` and
    nothing is uploaded.
  - `aplicar cambios de la nube no los vuelve a anotar como pendientes`.
  - `las existencias son iguales en A y B tras sincronizar` (conteo on A, sale on B).
- [ ] **Step 2: Run** `flutter test test/sincronizacion/sincronizador_test.dart` — Expected:
  FAIL.
- [ ] **Step 3: Implement** `Sincronizador` as specified.
- [ ] **Step 4: Run** the tests, then the full suite — Expected: PASS.
- [ ] **Step 5: Commit** `feat: sync the shared store both ways with the cloud`

---

### Task 6: When sync runs, and the file backup handover

**Files:** `lib/sincronizacion/sincronizacion_provider.dart`, `lib/respaldo/respaldo_provider.dart`,
`lib/main.dart` (or the app root, for the lifecycle observer),
`test/sincronizacion/sincronizacion_provider_test.dart`,
`test/respaldo/respaldo_provider_test.dart`

**Interfaces:**
- `enum FaseSincronizacion { noCompartida, alDia, sincronizando, sinConexion, actualizarApp,
  requiereReconexion }`
- `class EstadoSincronizacion { fase, ultimaSincronizacion (DateTime?), pendientes (int) }`
  - Name the Dart state class `EstadoTiendaCompartida` so it does not collide with the Drift
    table class.
- `sincronizadorProvider = Provider<Sincronizador?>`, null without a cloud.
- `sincronizacionProvider = NotifierProvider<SincronizacionNotifier, EstadoTiendaCompartida>`,
  with:
  - `Future<void> sincronizarAhora()`
  - `Future<void> compartirTienda()`, which uses the store name from `configuracion_tienda`
  - `Future<void> descargarTienda()`
- When sync runs, only while shared:
  - on `build`
  - 5 s after the last write to `cambios_pendientes`: `tableUpdates(TableUpdateQuery.onTable(
    cambiosPendientes))` with a debounce of `retardoSincronizacion = Duration(seconds: 5)`
  - every `intervaloSincronizacion = Duration(seconds: 60)` while the app is open
  - when the app resumes, via `AppLifecycleListener`
- One run at a time, with the same in-progress/queued-again pattern as `RespaldoNotifier`.
- `RespaldoNotifier`: when the store is shared, `respaldarAhora()` returns `false` without
  uploading, `_alAbrir` does nothing, and the notifier exposes `bool compartida` in
  `EstadoRespaldo` for the UI.

- [ ] **Step 1: Write failing tests** (fake cloud plus in-memory DB, `fakeAsync`):
  - `una tienda no compartida no sincroniza`
  - `al abrir la app sincroniza`
  - `un cambio local sincroniza a los 5 segundos`: no call at 4 s, one call at 5 s.
  - `cada 60 segundos vuelve a sincronizar`
  - `sin conexión queda en sinConexion y reintenta en el siguiente ciclo`
  - `sesión vencida pasa a requiereReconexion`
  - `con tienda compartida el respaldo por archivo no sube nada`
- [ ] **Step 2: Run** — Expected: FAIL.
- [ ] **Step 3: Implement.** Register the lifecycle listener in the notifier with
  `ref.onDispose(listener.dispose)`, so no widget change is needed. Check whether `main.dart`
  needs anything; only touch it if the provider must be read eagerly. If so, read it once
  where `respaldoProvider` is first read today.
- [ ] **Step 4: Run** the tests and the full suite — Expected: PASS.
- [ ] **Step 5: Commit** `feat: sync the shared store automatically and stop file backups`

---

### Task 7: Screens, docs and phone check

**Files:** `lib/screens/respaldo/respaldo_screen.dart`,
`lib/screens/respaldo/verificar_correo_screen.dart`,
`lib/screens/ayuda/preguntas_frecuentes.dart`, `README.md`, `docs/hoja-de-ruta.md`, and the
tests in `test/screens/respaldo/`

**Copy (exact):**
- Button `boton_compartir_tienda`: **"Usar la tienda en varios celulares"**. It shows only when
  the backup is active and the store is not shared.
- Confirmation dialog:
  - Title: **"¿Usar la tienda en varios celulares?"**
  - Body: **"Los datos de la tienda se guardarán en la nube y se mantendrán al día en cada
    celular de la tienda. El respaldo por archivo se reemplaza por esto."**
  - Buttons: **"Cancelar"** and **"Continuar"** (key `confirmar_compartir`).
- Card `tarjeta_sincronizacion` (shared store), title **"Tienda compartida"**, with lines by
  phase:
  - alDia: **"Al día · última vez {hace X}"**
  - sincronizando: **"Sincronizando…"**
  - sinConexion: **"Sin internet: se sube cuando vuelva la conexión"**
  - actualizarApp: **"Actualiza la app para seguir sincronizando"**
  - requiereReconexion: reuse the existing reconnect button
  - pending: **"{n} cambios por subir"** when n > 0
  - Button `boton_sincronizar_ahora`: **"Sincronizar ahora"**
- Restore flow (`ModoVerificacion.restaurar`): after `verificar`, call `miTienda()`.
  - If it is not null: confirm with **"Se descargará la tienda compartida en este celular."**,
    then `descargarTienda()`.
  - Then clear the huellas (as `restaurar()` does), close the session and invalidate
    `databaseProvider`. The SnackBar says **"Tienda recuperada. Entra con tu PIN."**
  - If it is null, keep today's file restore.
- Activate flow on a phone that already has a store, while the email already has a shared store:
  - Dialog **"Este correo ya tiene una tienda compartida"** with
    **"Usar la tienda compartida en este celular"**. It confirms that the data on this phone
    will be replaced, then runs `descargarTienda()` after wiping the local DB with the same
    close-and-replace path the restorer uses.
  - The other choice is **"Cancelar"** (disconnect).
- FAQ: add **"¿Cómo uso la tienda en varios celulares?"** to the Respaldo topic.
- Accessibility (WCAG 2.1 AA): every new button has visible text; the card has a `Semantics`
  label.

- [ ] **Step 1: Write failing widget tests** covering:
  - the button shows only with backup active and the store not shared
  - the confirmation calls `compartirTienda`
  - the card text for each phase
  - restoring with `miTienda != null` downloads and shows "Tienda recuperada. Entra con tu PIN."
  - restoring with `miTienda == null` keeps the file restore
- [ ] **Step 2: Run** `flutter test test/screens/respaldo/` — Expected: FAIL.
- [ ] **Step 3: Implement** the UI.
- [ ] **Step 4: Run** the full suite, `flutter analyze` and `dart format` on the touched files —
  Expected: green.
- [ ] **Step 5: Docs.**
  - README:
    - Arquitectura: one paragraph on the outbox triggers, the `filas` table and the cursor.
    - Environment: no new variables.
    - Supabase: the migration file and the verification SQL.
  - Hoja de ruta: E2 done.
- [ ] **Step 6: Commit and push** `feat: let the admin share the store across phones`
- [ ] **Step 7: Phone check with the user.** Build the APK and install it with
  `%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe install -r`. Then:
  1. Convert the store on the Redmi.
  2. With MCP `execute_sql`, check that `filas` holds the store's rows (count per `tabla`, no
     data printed).
  3. Make a sale and check that a new version arrives within about 1 minute.
  4. Clear app data and recover via "Ya tengo una tienda". Expect the same sales and reports.
  5. Record the result in "Verificado en celular real".

## Rulings made while planning (deviations from the spec, for the reviewer)

- **QR image travels base64 inside `filas.datos`, not in Storage** (spec §7 call 14 suggested
  Storage). It is one small image that rarely changes, and this avoids a second sync path.
  Revisit before the January launch if stores upload large images. Cost if wrong: bigger
  `filas` rows for `configuracion_tienda`.
- **No Supabase Realtime in E2.** A 60 s poll plus sync on every change and on resume meets the
  spec's "polling as fallback" (§7 call 3). Realtime arrives in E4 with the in-app alerts.
  Cost if wrong: up to 60 s delay seeing the other phone's sales.
- **The minimum version is checked by the client** (reading `configuracion_app`), not enforced
  by the server. All clients are ours. Cost if wrong: a modified old client could still write
  rows.
- **PIN hashes travel to the cloud as today's file backup already does.** Hardening (salt plus
  server-side check) is done in E3, where the vendor's PIN is validated by the server (spec §6).
  Cost if wrong: in E2, store members can read the admin's 4-digit hash, which is no worse than
  the current backup.
