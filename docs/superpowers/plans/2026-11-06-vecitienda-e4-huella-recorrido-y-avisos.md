# VeciTienda E4 — Huella, recorrido y avisos del vendedor — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The vendor turns on their own fingerprint from their account, sees a short tour the
first time they enter on their own phone, and every phone with the app open is told when sales
made on another phone leave a product "por pedir".

**Architecture:**
- **Huella.** The fingerprint switch stops being admin-only. A shared function
  `activarHuella` (dialog + fingerprint confirmation) is used by Ajustes and by a new item in
  the account menu, which every user sees.
- **Vendor tour.** When a vendor phone finishes downloading the store after approval (E3
  `revisarSolicitud`), it saves `recorrido_vendedor_pendiente = true`. The first time a vendor
  opens the Inicio on that phone, the Inicio shows a short set of balloons and clears the flag.
  The admin's tour (`recorrido_paso`) is untouched.
- **"Por pedir" from other phones.** When a sync cycle downloads rows that change stock
  (`ventas`, `lineas_venta`, `conteos_inventario`, `entradas_mercancia`, `lineas_entrada`,
  `productos`), the `Sincronizador` reads the stock of controlled products before applying
  them and, after applying, computes which ones crossed their minimum with the existing
  `productosQueCruzaron` rule. The notifier hands them to `avisoPorPedirProvider.trasVenta`,
  so the Inicio strip shows them like after a local sale.
- The "celular nuevo" alert is already done (E3, `AtenderSolicitudes`).

**Tech Stack:** Flutter 3.47.2, Riverpod, Drift, `local_auth` (already in use). No new
dependencies; no schema change; no Supabase change.

**Spec:** `docs/superpowers/specs/2026-11-03-vecitienda-tienda-compartida-design.md`
(§2 metas 6–7, §5 "Huella del vendedor" and "Recorrido del vendedor", §7 llamada 1 E4 and 8).

## Global Constraints

- Huella, tour and consejos are per phone and never go to the cloud (spec §7 llamada 8).
- Spanish copy, no raw errors. A failure computing stock alerts must never stop or fail a sync
  cycle (the alert is a convenience, like after a local sale).
- `dart format` only on touched files, `flutter analyze` clean, full `flutter test` green
  before each commit. Conventional Commits with
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`, commit and push to `master`.

## Review Focus

1. **A vendor phone that downloads a store while the vendor is not the one who logs in first**
   (e.g. the admin tests the phone): the tour is for vendors only; the admin entering on that
   phone must not consume or see it. Test in Task 2.
2. **The first sync after a download** brings the whole store: that must not flood the strip
   with every product already under its minimum. Only products that crossed during that cycle
   count, and a fresh download (no local stock before) produces none. Test in Task 3.
3. **This phone's own sale** must not be announced twice (once by the sale screen, again when
   its own rows come back): rows are only "downloaded" if they came from the cloud and were
   applied, and the strip merges by product. Test in Task 3.
4. **No fingerprint hardware**: the account menu item does not appear. Test in Task 1.
5. **A deactivated user's fingerprint**: already refused in E3 (`iniciarSesionConHuella`);
   nothing new, but the account menu must only act on the logged-in user.

---

## File Structure

- Create `lib/screens/configuracion/activar_huella.dart` — `activarHuella(context, ref,
  usuario)` moved out of `_FilaHuella`.
- Modify `lib/screens/configuracion/ajustes_screen.dart` (`_FilaHuella` uses it),
  `lib/screens/home/home_screen.dart` (`_MenuCuenta` item; vendor tour).
- Create `lib/screens/recorrido/globos_vendedor.dart` (balloon list).
- Modify `lib/providers/recorrido_provider.dart` (vendor flag),
  `lib/sincronizacion/sincronizacion_provider.dart` (set flag on approval; stock alerts),
  `lib/sincronizacion/sincronizador.dart` (stock snapshot around apply),
  `lib/screens/ayuda/preguntas_frecuentes.dart`, `README.md`, `docs/hoja-de-ruta.md`.

---

### Task 1: Fingerprint from the account menu

**Files:** create `lib/screens/configuracion/activar_huella.dart`; modify
`ajustes_screen.dart`, `home_screen.dart`, `preguntas_frecuentes.dart`; tests
`test/screens/home/menu_cuenta_huella_test.dart` (new),
`test/screens/configuracion/ajustes_huella_test.dart` (must stay green),
`test/screens/ayuda/preguntas_frecuentes_test.dart`.

**Interfaces:**
- Produces: `Future<void> activarHuella(BuildContext context, WidgetRef ref, Usuario usuario)`
  — the current `_FilaHuella._activar` body (dialog keys `activar_huella` / `cancelar_huella`,
  same copy, then fingerprint confirmation `'Confirma que eres ${usuario.nombre}'`).
- Account menu, only when `huellaDisponibleProvider` is true: item key `menu_huella`.
  - Off: **"Entrar con huella"** → `activarHuella`.
  - On: **"Quitar la huella"** → `usuariosConHuellaProvider.notifier.desactivar(id)` and
    SnackBar **"Ya no entras con huella en este celular"**.
  - After activating: SnackBar **"Listo: entras con tu huella en este celular"**.

- [ ] **Step 1: Write failing tests** (`menu_cuenta_huella_test.dart`, HomeScreen with a
  vendor session and `HuellaFalsa` from `test/support/huella_falsa.dart`):
  - `un vendedor activa su huella desde su cuenta`: open `menu_cuenta`, tap `menu_huella`, tap
    `activar_huella`; the fake approves; `usuariosConHuellaProvider` contains the vendor's id.
  - `con la huella activa el menú ofrece quitarla`.
  - `sin lector de huella el menú no la ofrece`.
  - FAQ: the answer to **"¿Cómo entro con la huella?"** no longer starts with "Solo el
    administrador" and contains "Toca tu inicial".
- [ ] **Step 2: Run** them — Expected: FAIL.
- [ ] **Step 3: Implement.** FAQ answer: **"Si el celular tiene lector de huella, toca tu
  inicial, arriba a la derecha, y elige "Entrar con huella" (el administrador también lo
  tiene en "Ajustes"). Toca "Activar" y confirma con tu huella. Después, en la pantalla del
  PIN toca "Entrar con huella". El PIN sigue sirviendo. Actívalo solo si el celular es
  tuyo."**
- [ ] **Step 4: Run** the full suite — Expected: green.
- [ ] **Step 5: Commit** `feat: let every user turn on their fingerprint from their account`

---

### Task 2: Short tour for the vendor on their phone

**Files:** create `lib/screens/recorrido/globos_vendedor.dart`; modify
`recorrido_provider.dart`, `sincronizacion_provider.dart` (`revisarSolicitud`),
`home_screen.dart`; tests `test/screens/home/recorrido_vendedor_test.dart` (new),
`test/screens/vendedor/unirse_tienda_test.dart`.

**Interfaces:**
- `const claveRecorridoVendedor = 'recorrido_vendedor_pendiente';` in `recorrido_provider.dart`,
  with `final recorridoVendedorProvider = NotifierProvider<RecorridoVendedorNotifier, bool>`:
  `build()` reads the bool (default false); `Future<void> marcarPendiente()`;
  `Future<void> terminar()` (sets false and removes the key).
- `revisarSolicitud` calls `marcarPendiente()` right after the store is on the phone (both the
  fresh download and the "ya bajada" path).
- E3 `_olvidarTienda` also removes `claveRecorridoVendedor` and invalidates the provider.
- `globosVendedor` (same `PasoGlobo` targets that exist today):
  1. `tarjeta_ventas`: **"Aquí ves cuánto se vendió hoy en la tienda."**
  2. `boton_nueva_venta`: **"Registra cada venta aquí. Llega sola al celular del
     administrador."**
  3. `boton_consultar_precio`: **"¿Te preguntan cuánto vale algo? Escanéalo aquí y ves el
     precio sin vender."**
  4. `pestana_fiado`: **"Aquí está lo que deben los clientes."**
  5. `menu_cuenta`: **"Tu cuenta: entrar con huella, apariencia, preguntas y cerrar
     sesión."**
- `HomeScreen`: when the session is a **vendor** (`!esAdmin`) and `recorridoVendedorProvider`
  is true, after the first frame show `mostrarGlobos(context, globosVendedor, ...)`; both
  `onTerminar` and `onSaltar` call `terminar()`. Admin sessions ignore the flag.

- [ ] **Step 1: Write failing tests:**
  - `el vendedor ve el recorrido corto la primera vez en su celular`: prefs with the flag,
    vendor session → the first balloon text shows; finishing it clears the flag.
  - `el admin no ve ni gasta el recorrido del vendedor`: same prefs, admin session → no
    balloon, flag still true.
  - `sin la marca el vendedor no ve recorrido`.
  - In `unirse_tienda_test.dart`, `al aprobarlo baja la tienda…` also asserts
    `prefs.getBool(claveRecorridoVendedor) == true`.
- [ ] **Step 2: Run** them — Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the full suite — Expected: green.
- [ ] **Step 5: Commit** `feat: show the vendor a short tour on their own phone`

---

### Task 3: "Por pedir" caused by another phone's sales

**Files:** modify `sincronizador.dart`, `sincronizacion_provider.dart`; tests
`test/sincronizacion/sincronizador_test.dart`,
`test/sincronizacion/sincronizacion_provider_test.dart`.

**Interfaces:**
- `Sincronizador` gains `List<AvisoExistencias> avisosBajados` (reset to `const []` at the
  start of every cycle).
- In `_bajarYAplicar`, only when `porAplicar` has a row of
  `{'ventas','lineas_venta','conteos_inventario','entradas_mercancia','lineas_entrada',
  'productos'}`:
  - before the apply transaction: `antes = existencias of every product with
    controlaExistencias` (via `InventarioRepository(db).productosConControl()`);
  - after it commits: `avisosBajados = await InventarioRepository(db).avisosTrasVenta(antes)`.
  - Any exception in either read leaves `avisosBajados` empty and does not change the result.
- `SincronizacionNotifier`, after a cycle with result `alDia` and non-empty
  `sincronizador.avisosBajados`, calls
  `ref.read(avisoPorPedirProvider.notifier).trasVenta(sincronizador.avisosBajados)` inside a
  try/catch.

- [ ] **Step 1: Write failing tests:**
  - Sincronizador, two phones A and B with a product (`controlaExistencias`, `minimo: 3`,
    stock 5 by a conteo) synced on both: A sells 3 and syncs; B syncs → B's
    `avisosBajados.single.texto == 'Quedan 2 Arepa: toca pedir'`.
  - `una descarga nueva no avisa lo que ya estaba por pedir`: B downloads a store where the
    product is already at 2 → `avisosBajados` is empty.
  - `la venta propia no vuelve como aviso bajado`: A sells and syncs → A's `avisosBajados` is
    empty.
  - Provider: with a fake cycle that leaves one aviso, `avisoPorPedirProvider` has it after
    the cycle.
- [ ] **Step 2: Run** them — Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the full suite — Expected: green.
- [ ] **Step 5: Commit** `feat: warn every phone when another phone's sales leave a product por pedir`

---

### Task 4: Docs and phone test

**Files:** `README.md`, `docs/hoja-de-ruta.md`.

- [ ] **Step 1:** Hoja de ruta: E4 done (paso 6 complete) and a "Pendiente de verificar" line:
  vendor turns on fingerprint from their account; vendor sees the short tour once; a sale on
  the vendor phone leaves "Quedan N …" on the admin phone within a minute.
- [ ] **Step 2:** README Arquitectura: one line each for the vendor tour flag and the
  downloaded stock alerts.
- [ ] **Step 3:** Full suite, analyze. Commit and push
  `docs: close the shared store step with E4`.

## Rulings made while planning

- **The fingerprint item is in the account menu for everyone**, not only vendors: the admin
  keeps the Ajustes switch too. One shared function, so both behave the same.
- **The vendor tour is a phone flag set on approval**, not `recorrido_paso`: an admin phone
  whose `recorrido_paso` is `ninguno` (old installs) must not show a tour to a vendor who logs
  in there, and the admin's own tour state is not touched.
- **Downloaded stock alerts reuse the local-sale rule and strip.** No separate wording for
  "otro celular": the text says what to do ("toca pedir"), which is the same either way.
- **No "por pedir" alert from the first download**: before it there is no local stock, so
  nothing "crossed".
