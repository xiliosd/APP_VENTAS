# Mejoras de tienda — Tanda 3 (aviso por pedir y extracto de fiado) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Al cobrar, avisar en el Inicio qué productos quedaron en su mínimo o se agotaron (con
"Ver por pedir" y un indicador "N por pedir" siempre visible), y mostrar al cliente un extracto de
fiado en pantalla con un consolidado por cada abono.

**Architecture:** El aviso se calcula comparando existencias antes y después de la venta
(`InventarioRepository.existenciasDe`) con una función pura; un `Notifier` global guarda el aviso
para que el Inicio lo muestre como franja después de cerrar Nueva venta, y se recalcula al
"Deshacer". El extracto es una función pura sobre `movimientosCliente` + `LineasVenta` (reusa
`saldosAcumulados`) y una pantalla de solo lectura abierta desde el detalle de Fiado.

**Tech Stack:** Flutter, Riverpod, Drift, flutter_test. Sin dependencias nuevas.

**Spec:** `docs/superpowers/specs/2026-10-26-vecitienda-mejoras-tienda-design.md` (secciones 4 y 6).

## Global Constraints

- Lineamientos UNIMINUTO v1.2; nombres en español como el resto del código; archivos en
  `snake_case` (excepción de Dart, ya documentada en el README).
- Rama `feature/mejoras-tienda-tanda3` desde `master`. `flutter analyze` sin hallazgos y todas
  las pruebas en verde en cada commit. Formatear solo archivos nuevos con `dart format`; líneas
  nuevas en archivos existentes ≤ 100 caracteres (no reformatear el repositorio).
- Aviso solo para productos con control de existencias. Dispara si **cruzó** al mínimo
  (`antes > minimo && despues <= minimo`) o **llegó a cero** (`antes > 0 && despues <= 0`).
- Textos fijos: "Quedan N <producto>: toca pedir", "Se agotó <producto>", "Ver por pedir",
  "N por pedir", "Ver extracto", "Ver detalle anterior",
  "Saldo al <fecha hora> después de abonar $X: $Y" (fecha hora con `formatoFechaHora`, montos con
  `formatoMoneda`).
- El aviso no agrega toques a la venta ni la bloquea; un error al calcularlo nunca impide cerrar
  la venta ni mostrar "Venta registrada".
- Extracto: sin anulados, corregidos con su valor vigente, consolidado calculado al mostrar (no se
  guarda), sin botones de corrección. Nombre y teléfono del cliente nunca en logs (Ley 1581).
- WCAG 2.1 AA: `tooltip` en botones de ícono, objetivos ≥ 48 dp, contraste ≥ 4,5:1 (usar
  `ColoresApp.fondoAviso / textoAviso / accionAviso` para la franja), franja con
  `Semantics(liveRegion: true)`. Animaciones con `Movimiento.duracion` (respeta reducir
  movimiento).
- Vibración: la franja aparece en el mismo instante que "Venta registrada", que ya vibra con
  `Vibracion.exito`; no se agrega una segunda vibración (decisión del plan: dos golpes juntos se
  sienten como uno solo y confunden).
- Cobertura ≥ 80 % en fiado/extracto (datos personales) y ≥ 60 % en el resto.
- Commits Conventional Commits con `Co-Authored-By:` del modelo que los hizo. No fusionar ni
  subir sin autorización del usuario.

## Review Focus

1. Falla al leer existencias después de cobrar: la venta queda registrada, sale "Venta
   registrada" y la pantalla se cierra (si no, el vendedor cobra dos veces). Test en Task 2.
2. "Deshacer" justo después de cobrar: la franja desaparece aunque Nueva venta ya se cerró. Test
   en Task 2.
3. Vender otra vez un producto que ya estaba bajo el mínimo (sin llegar a cero): no hay aviso
   nuevo; si llega a cero, sí sale "Se agotó". Test en Task 1.
4. Cambio de usuario (otro turno): la franja del turno anterior no se hereda. Test en Task 2.
5. Fiado viejo sin líneas (antes de la Fase 3C) y abono con la misma fecha que una venta: el
   extracto muestra "Venta sin detalle" con su total y ordena venta antes que abono, igual que el
   saldo de la línea de tiempo. Test en Task 4.

---

### Task 1: Cálculo de productos que cruzaron al mínimo

**Files:**
- Create: `lib/util/aviso_existencias.dart`
- Modify: `lib/repositories/inventario_repository.dart` (método nuevo)
- Test: `test/util/aviso_existencias_test.dart`, `test/repositories/inventario_aviso_venta_test.dart`

**Interfaces:**
- Produces:
  - `class AvisoExistencias { const AvisoExistencias({required int productoId, required String
    nombre, required int existencias, required int minimo}); bool get agotado => existencias <= 0;
    String get texto; }` — `texto`: agotado → `'Se agotó $nombre'`; si no →
    `'Quedan $existencias $nombre: toca pedir'`.
  - `List<AvisoExistencias> productosQueCruzaron({required Map<int, int> antes, required
    Map<int, int> despues, required Map<int, Producto> productos})` — un producto entra si está en
    los tres mapas y cumple la regla de Global Constraints; orden: agotados primero, luego por
    nombre.
  - `InventarioRepository.avisosTrasVenta(Map<int, int> antes) → Future<List<AvisoExistencias>>`
    — lee `existenciasDe(antes.keys)` y los `Producto` de esos ids, y llama a
    `productosQueCruzaron`.
  - `InventarioRepository.avisosVigentes(List<AvisoExistencias> avisos) →
    Future<List<AvisoExistencias>>` — vuelve a leer existencias y mínimo; conserva solo los que
    siguen `existencias <= minimo`, con el número actualizado (para "Deshacer").

- [ ] **Step 1: Write failing tests**
```dart
// aviso_existencias_test.dart (Producto de prueba con minimo 3)
test('cruza al mínimo: de 5 a 3 avisa "Quedan 3 Arroz: toca pedir"', ...);
test('llega a cero desde abajo del mínimo: de 2 a 0 avisa "Se agotó Arroz"', ...);
test('ya estaba bajo el mínimo y sigue sobre cero: de 2 a 1 no avisa', ...);
test('ya estaba en cero o negativo: de 0 a -1 no avisa', ...);
test('sin control (no viene en despues) no avisa', ...);
test('agotados primero y luego por nombre', ...);
// inventario_aviso_venta_test.dart (base en memoria, conteo inicial 4, minimo 3)
test('avisosTrasVenta detecta el cruce tras registrarVenta de 2 unidades', ...);
test('avisosVigentes descarta el aviso después de eliminarVenta', ...);
```

- [ ] **Step 2:** Run `flutter test test/util/aviso_existencias_test.dart test/repositories/inventario_aviso_venta_test.dart` — FAIL (no existe).
- [ ] **Step 3:** Implement the interfaces above.
- [ ] **Step 4:** Run the same command — PASS; `flutter analyze` limpio.
- [ ] **Step 5: Commit** `feat: detect products that reach their minimum after a sale`

### Task 2: Aviso guardado al cobrar y "Deshacer"

**Files:**
- Create: `lib/providers/aviso_por_pedir_provider.dart`
- Modify: `lib/screens/venta/registrar_venta_screen.dart` (`_cobrar`, ~líneas 409–470)
- Test: `test/providers/aviso_por_pedir_provider_test.dart`,
  `test/screens/venta/aviso_por_pedir_venta_test.dart`

**Interfaces:**
- Consumes: Task 1 (`avisosTrasVenta`, `avisosVigentes`, `AvisoExistencias`).
- Produces: `final avisoPorPedirProvider = NotifierProvider<AvisoPorPedirNotifier,
  List<AvisoExistencias>>` con:
  - `build()`: `ref.watch(sesionProvider.select((s) => s.usuarioActivo?.id))` y devuelve `const []`
    (cambiar de usuario borra el aviso).
  - `void mostrar(List<AvisoExistencias> nuevos)` — une con el estado por `productoId`; el nuevo
    reemplaza al viejo del mismo producto.
  - `void cerrar()` — estado vacío.
  - `Future<void> recalcular()` — estado = `avisosVigentes(state)`.
- `_cobrar`: antes de `registrarVenta`, `antes = existenciasDe(ids de productos del ticket)`;
  después, `avisosTrasVenta(antes)` dentro de `try/catch` que ante error deja la lista vacía (sin
  registrar datos del cliente). Si hay avisos, `mostrar`. `onDeshacer` pasa a
  `() async { await ventaRepo.eliminarVenta(ventaId); await avisoNotifier.recalcular(); }`, con
  `avisoNotifier` leído antes del `pop`.

- [ ] **Step 1: Write failing tests**
```dart
test('mostrar une por producto y el nuevo reemplaza al viejo', ...);
test('cerrar deja la lista vacía', ...);
test('cambiar el usuario activo borra el aviso', ...);
testWidgets('cobrar un producto que cruza el mínimo deja el aviso en el provider', ...);
testWidgets('Deshacer elimina la venta y quita el aviso', ...);
testWidgets('si avisosTrasVenta falla, la venta queda, sale "Venta registrada" y se cierra', ...);
// Inventario fake con override de inventarioRepositoryProvider que lanza en avisosTrasVenta.
```
- [ ] **Step 2:** Run `flutter test test/providers/aviso_por_pedir_provider_test.dart test/screens/venta/aviso_por_pedir_venta_test.dart` — FAIL.
- [ ] **Step 3:** Implement provider and `_cobrar` changes.
- [ ] **Step 4:** Run the same command and `flutter test test/screens/venta` — PASS.
- [ ] **Step 5: Commit** `feat: keep a restock notice after a sale and clear it on undo`

### Task 3: Franja e indicador "por pedir" en el Inicio

**Files:**
- Create: `lib/screens/home/franja_por_pedir.dart`
- Modify: `lib/screens/home/resumen_screen.dart` (parámetro y primeras filas del `ListView`),
  `lib/screens/home/home_screen.dart` (pasa `onVerPorPedir: () => setState(() => _tabActual = 2)`)
- Test: `test/screens/home/franja_por_pedir_test.dart`

**Interfaces:**
- Consumes: `avisoPorPedirProvider` (Task 2), `porPedirProvider` (existente).
- Produces:
  - `class FranjaPorPedir extends ConsumerWidget { const FranjaPorPedir({super.key, required
    VoidCallback onVerPorPedir}); }` — `Key('franja_por_pedir')`; nada si la lista está vacía. Un
    aviso: su `texto`. Varios: título `'Toca pedir ${n} productos'` y una línea por `texto`.
    Botón de texto "Ver por pedir" (`Key('boton_ver_por_pedir_franja')`) que cierra el aviso y
    llama `onVerPorPedir`; `IconButton` cerrar (`Key('cerrar_franja_por_pedir')`,
    `tooltip: 'Cerrar aviso'`). Colores `fondoAviso/textoAviso/accionAviso`; entra con
    `AnimatedSize` y `Movimiento.duracion(context, Movimiento.media)`.
  - `class IndicadorPorPedir extends ConsumerWidget` — `Key('indicador_por_pedir')`, texto
    `'$n por pedir'` (n = productos en `porPedirProvider`), oculto con n = 0; al tocar,
    `onVerPorPedir`. Objetivo táctil ≥ 48 dp, visible para admin y vendedor.
  - `ResumenScreen({..., VoidCallback? onVerPorPedir})`; franja e indicador van antes del
    `SelectorFecha`.

- [ ] **Step 1: Write failing tests**
```dart
testWidgets('sin avisos no hay franja; con uno muestra su texto', ...);
testWidgets('con dos avisos muestra "Toca pedir 2 productos" y ambas líneas', ...);
testWidgets('cerrar quita la franja', ...);
testWidgets('Ver por pedir cierra el aviso y abre Inventario en "Por pedir"', ...); // HomeScreen
testWidgets('indicador muestra "2 por pedir" a un vendedor y se oculta con 0', ...);
testWidgets('franja e indicador sin desborde a 2,0× en 360 dp', ...);
testWidgets('la franja es liveRegion y el cerrar tiene tooltip', ...);
```
- [ ] **Step 2:** Run `flutter test test/screens/home/franja_por_pedir_test.dart` — FAIL.
- [ ] **Step 3:** Implement widgets and wire them in `ResumenScreen` and `HomeScreen`.
- [ ] **Step 4:** Run the same command and `flutter test test/screens` — PASS.
- [ ] **Step 5: Commit** `feat: show the restock notice and a to-order count on the home screen`

### Task 4: Cálculo del extracto de fiado

**Files:**
- Create: `lib/util/extracto_fiado.dart`
- Modify: `lib/repositories/fiado_repository.dart` (método nuevo), `lib/providers/fiado_providers.dart`
- Test: `test/util/extracto_fiado_test.dart`, `test/repositories/extracto_fiado_repository_test.dart`

**Interfaces:**
- Consumes: `MovimientoFiado`, `saldosAcumulados` (existentes), `LineaVenta`.
- Produces:
  - `sealed class EntradaExtracto { DateTime get fecha; int get monto; }`
  - `class FiadoExtracto extends EntradaExtracto { final int ventaId; final List<LineaVenta>
    lineas; final int saldoDespues; }` (lineas vacías = venta sin detalle)
  - `class AbonoExtracto extends EntradaExtracto { final int pagoId; final int saldoDespues; }`
  - `class ExtractoFiado { final List<EntradaExtracto> anteriores; final AbonoExtracto?
    ultimoAbono; final List<EntradaExtracto> recientes; final int saldoActual; }`
  - `ExtractoFiado armarExtracto(List<MovimientoFiado> movimientos, Map<int, List<LineaVenta>>
    lineasPorVenta)` — descarta anulados; orden cronológico de `saldosAcumulados`;
    `ultimoAbono` = último abono vigente; `anteriores` = todo lo anterior a él (cronológico);
    `recientes` = lo posterior; sin abonos, `anteriores` vacío y todo en `recientes`;
    `saldoActual` = último saldo o 0.
  - `FiadoRepository.extractoCliente(int clienteId) → Future<ExtractoFiado>` — líneas de todas
    las ventas en una sola consulta (`isIn`).
  - `final extractoClienteProvider = FutureProvider.autoDispose.family<ExtractoFiado, int>`
    (escucha `_cambiosFiadoProvider`).

- [ ] **Step 1: Write failing tests**
```dart
test('sin abonos: todo en recientes, sin consolidado', ...);
test('fiado 10.000, abono 4.000, fiado 3.000: ultimoAbono saldoDespues 6.000, '
    'anteriores [fiado], recientes [fiado 3.000], saldoActual 9.000', ...);
test('dos abonos: el primero queda en anteriores con su saldoDespues', ...);
test('anulados no aparecen ni cuentan', ...);
test('misma fecha: la venta va antes que el abono', ...);
test('venta sin líneas queda con lineas vacías y su monto', ...);
test('extractoCliente usa el monto y las líneas corregidas y su saldoActual = saldoCliente', ...);
```
- [ ] **Step 2:** Run `flutter test test/util/extracto_fiado_test.dart test/repositories/extracto_fiado_repository_test.dart` — FAIL.
- [ ] **Step 3:** Implement the interfaces above.
- [ ] **Step 4:** Run the same command — PASS; revisar cobertura del archivo nuevo ≥ 80 %
  (`flutter test --coverage`).
- [ ] **Step 5: Commit** `feat: build a customer's credit statement with balances after each payment`

### Task 5: Pantalla del extracto y botón "Ver extracto"

**Files:**
- Create: `lib/screens/fiado/extracto_fiado_screen.dart`
- Modify: `lib/screens/fiado/detalle_cliente_screen.dart` (tarjeta de saldo), `docs/hoja-de-ruta.md`
- Test: `test/screens/fiado/extracto_fiado_screen_test.dart`,
  `test/screens/fiado/detalle_cliente_screen_test.dart`

**Interfaces:**
- Consumes: `extractoClienteProvider` (Task 4), `NombreTienda`, `formatoFechaHora`,
  `formatoMoneda`.
- Produces: `class ExtractoFiadoScreen extends ConsumerWidget { const ExtractoFiadoScreen({super.key,
  required Cliente cliente}); }`
  - Encabezado: nombre de la tienda, `cliente.nombreCompleto`, "Extracto al <fecha hora>".
  - Texto base 18 (montos 20+), sin `onTap` ni botones de corrección.
  - Con `ultimoAbono`: fila consolidado (`Key('consolidado_ultimo_abono')`) con el texto fijo de
    Global Constraints; debajo un `ExpansionTile` "Ver detalle anterior"
    (`Key('ver_detalle_anterior')`, plegado por defecto) con `anteriores`, cada abono seguido de su
    consolidado.
  - Cada fiado: fecha hora, filas `descripcion · cantidad × precio = subtotal`, total; sin líneas:
    "Venta sin detalle". Cada abono: fecha hora y monto.
  - Al final `Key('saldo_actual_extracto')`: "Saldo actual $Y", o "Al día", o
    "Saldo a favor $Y".
- Detalle de Fiado: botón "Ver extracto" (`Key('boton_ver_extracto')`) en la tarjeta de saldo,
  visible si hay al menos un movimiento no anulado; abre `ExtractoFiadoScreen`.
- Hoja de ruta: tanda 3 pasa a "hecha" con una línea de resumen, y "aviso por pedir y extracto de
  fiado" se agrega a "Pendiente de verificar".

- [ ] **Step 1: Write failing tests**
```dart
testWidgets('muestra consolidado del último abono y saldo actual', ...);
testWidgets('Ver detalle anterior despliega los fiados y abonos previos', ...);
testWidgets('venta sin detalle y saldo a favor', ...);
testWidgets('sin botones de corrección: tocar un fiado no abre la hoja de movimiento', ...);
testWidgets('sin desborde a 2,0× en 360 dp', ...);
testWidgets('Ver extracto aparece con movimientos y abre la pantalla; no aparece sin ellos', ...);
```
- [ ] **Step 2:** Run `flutter test test/screens/fiado` — FAIL.
- [ ] **Step 3:** Implement the screen, the button and the roadmap update.
- [ ] **Step 4:** Run `flutter analyze` and `flutter test` (suite completa) — sin hallazgos y todo
  en verde; revisar contraste y `Semantics` de las vistas nuevas en claro y oscuro.
- [ ] **Step 5: Commit** `feat: show a customer's credit statement on screen`
