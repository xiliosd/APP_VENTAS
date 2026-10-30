# Arreglos tanda A (inventario y pedidos) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Corregir los detalles menores vigentes de inventario y pedidos que el tendero nota: lo escrito
al recibir no se pierde, los errores dicen qué pasó, el precio esperado no queda vacío, el número
de la franja "por pedir" se mantiene al día y el vacío del grupo "Sin proveedor" se lee bien.

**Architecture:** Cambios pequeños en pantallas existentes de `lib/screens/inventario/` y en
`AvisoPorPedirNotifier`. No hay cambios de esquema ni dependencias nuevas.

**Tech Stack:** Flutter, Riverpod 2, Drift; pruebas con `flutter_test` y base en memoria.

**Spec:** no hay spec aparte. La fuente es el triage del 2026-10-30, ítems #29, #46, #47, #49, #51 y #69,
resumido en `docs/hoja-de-ruta.md` → "Orden de lo que falta", paso 2.

## Global Constraints

- Trabajo directo en `master` (proyecto personal): un commit por tarea, Conventional Commits en
  inglés, terminando con `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- `dart format` solo sobre los archivos tocados; `flutter analyze` limpio; toda la suite en verde.
- Textos al usuario en español de Colombia, tuteo, sin tecnicismos.
- Colores siempre con `ColoresApp.of(context)` (hay una prueba que prohíbe hex sueltos).

## Fuera de alcance (decidido)

- #48 Entrada anulada pierde la comparación con su pedido: exige una columna nueva y una migración
  (v11) para un dato que solo se ve en entradas anuladas.
- #50 `LineaInicial` sin uso: es la API que usan las pruebas para arrancar la pantalla. Quitarla no
  cambia nada para el tendero.
- #72 `existenciasDe` ignora la venta del mismo segundo del conteo: las fechas se guardan con
  precisión de segundos y una persona no cuenta y vende en el mismo segundo. Corregirlo exige cambiar
  la precisión de las fechas.

## Review Focus

- Recibir mercancía sin nada escrito: elegir un pedido no debe pedir confirmación (cubierto en la tarea 1).
- Falla de la base al cargar el pedido: la pantalla no debe quedar con el indicador de carga para
  siempre (cubierto en la tarea 1).
- Pedido recibido o anulado desde otra pantalla mientras se edita: el mensaje dice que ya no está
  por llegar (cubierto en la tarea 2).
- Producto sin precio con ese proveedor: se agrega sin precio esperado, como hoy (cubierto en la tarea 2).
- Franja abierta y otra venta que baja el mismo producto sin cruzar el mínimo: el número se
  actualiza (cubierto en la tarea 3).

---

### Task 1: Recibir mercancía no pierde lo escrito ni se queda cargando (#46, #47)

**Files:**
- Modify: `lib/screens/inventario/recibir_mercancia_screen.dart` (`_cargarPedido`, `_preguntarPedido`)
- Test: `test/screens/inventario/recibir_pedido_screen_test.dart`

**Interfaces:**
- Produces: nada que usen otras tareas.

- [ ] **Step 1: Write the failing tests** (en el `main` existente, reutilizando su helper de montaje)

```dart
testWidgets('con líneas escritas, elegir un pedido pide confirmar y Cancelar las conserva', ...);
// Arranca sin pedido y con proveedor que tiene un pedido por llegar; agrega un producto a mano,
// elige el pedido en "¿Llegó alguno?"; espera AlertDialog con título
// '¿Reemplazar lo que escribiste?' y botones 'Cancelar' y 'Reemplazar' (Key 'confirmar_reemplazar').
// Al tocar 'Cancelar': sigue el producto escrito y no se ve ninguna línea del pedido.
testWidgets('sin líneas escritas, elegir un pedido lo carga sin preguntar', ...);
// expect(find.byType(AlertDialog), findsNothing) y aparecen las líneas del pedido.
testWidgets('si falla cargar el pedido, muestra el error y deja de cargar', ...);
// Override de pedidoRepositoryProvider cuyo detallePedido lanza; espera el texto
// 'No se pudo cargar el pedido, intenta de nuevo' y ningún CircularProgressIndicator.
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/screens/inventario/recibir_pedido_screen_test.dart`
Expected: las 3 nuevas fallan.

- [ ] **Step 3: Implement**

En `_preguntarPedido`, después de elegir y antes de `_cargarPedido`: si `_lineas.isNotEmpty`, mostrar
el diálogo de confirmación y salir si no se confirma (`true` solo con 'Reemplazar'). En `_cargarPedido`,
envolver la lectura en `try/catch`. En el `catch`, poner `_error = 'No se pudo cargar el pedido, intenta de nuevo'`
y `_cargandoPedido = false` sin tocar `_lineas`. La carga inicial (`widget.pedidoId`) no pregunta,
porque arranca sin líneas.

- [ ] **Step 4: Run tests to verify they pass** — mismo comando, todo en verde.

- [ ] **Step 5: Commit** — `fix: confirm before replacing typed lines with an order and recover from load errors`

### Task 2: Pedido por llegar con errores claros y precio esperado (#49, #51)

**Files:**
- Modify: `lib/screens/inventario/pedido_por_llegar_screen.dart` (`_agregarProducto`, `_guardar`, `_anular`)
- Test: `test/screens/inventario/pedido_por_llegar_screen_test.dart`

**Interfaces:**
- Consumes: `ProveedorRepository.productosDe(int proveedorId)` → `List<({Producto producto, int precioCompra})>`
  (`lib/repositories/proveedor_repository.dart:115`), vía `proveedorRepositoryProvider`. El
  `proveedorId` sale de `detalle.resumen.proveedor.id`.
- Errores del repositorio: `PermisoDenegado` (`correccion_repository.dart`) y
  `ArgumentError('El pedido ya no está por llegar')` (`pedido_repository.dart:178`).

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('al agregar un producto del proveedor usa su precio de compra', ...);
// Producto con precio de compra 2500 con el proveedor del pedido; tras agregarlo, el total
// estimado incluye 2500 (formatoMoneda) y al guardar la línea queda con precioEsperado == 2500.
testWidgets('si el pedido ya no está por llegar, lo dice al guardar', ...);
// Recibir o anular el pedido en la base antes de tocar Guardar; espera
// 'Este pedido ya se recibió o se anuló'.
testWidgets('sin permiso, lo dice al anular', ...);
// Sesión de vendedor que no creó el pedido (o el caso que hoy lanza PermisoDenegado); espera
// 'No tienes permiso para cambiar este pedido'.
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/screens/inventario/pedido_por_llegar_screen_test.dart`

- [ ] **Step 3: Implement**

Agregar `String _motivo(Object error)` con un `switch` como el de `hoja_movimiento.dart:222`. Los
casos son `PermisoDenegado()` → 'No tienes permiso para cambiar este pedido',
`ArgumentError(message: 'El pedido ya no está por llegar')` → 'Este pedido ya se recibió o se anuló'
y el resto → el texto genérico actual de cada acción. `_guardar` y `_anular` lo usan en su `catch`.
En `_agregarProducto`, buscar el precio de compra del producto en `productosDe(proveedorId)` y usarlo
como `precioEsperado` (null si no está).

- [ ] **Step 4: Run tests to verify they pass**

- [ ] **Step 5: Commit** — `fix: explain order edit errors and prefill the expected price`

### Task 3: El número de la franja "por pedir" se mantiene al día (#69)

**Files:**
- Modify: `lib/providers/aviso_por_pedir_provider.dart`, `lib/screens/venta/registrar_venta_screen.dart:515-522`
- Test: `test/providers/aviso_por_pedir_provider_test.dart`, `test/screens/venta/aviso_por_pedir_venta_test.dart`

**Interfaces:**
- Produces: `Future<void> AvisoPorPedirNotifier.trasVenta(List<AvisoExistencias> nuevos)`. Une los
  nuevos con los que ya estaban (como `mostrar`) y después recalcula con `avisosVigentes`. Si
  recalcular falla, se queda con la unión.

- [ ] **Step 1: Write the failing tests**

```dart
test('trasVenta actualiza la cantidad de un aviso que ya estaba', ...);
// Producto mínimo 5; venta lo deja en 4 → aviso 'Quedan 4 …'; otra venta lo deja en 2 sin
// cruzar → tras trasVenta([]) el estado tiene existencias == 2.
test('trasVenta quita los que ya no están en el mínimo', ...);
// Tras recibir mercancía, trasVenta([]) deja el estado vacío.
testWidgets('dos ventas seguidas: la franja muestra el número nuevo', ...); // en aviso_por_pedir_venta_test
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/providers/aviso_por_pedir_provider_test.dart test/screens/venta/aviso_por_pedir_venta_test.dart`

- [ ] **Step 3: Implement**

`trasVenta` reutiliza `mostrar` y `recalcular`. En `registrar_venta_screen.dart`, cambiar
`if (avisos.isNotEmpty) avisoNotifier.mostrar(avisos);` por una llamada a `trasVenta(avisos)` dentro
de `try {} catch (_) {}`, también cuando `avisos` esté vacío y haya avisos abiertos. Hacerlo antes
del `pop`: el notifier ya está leído y la llamada no depende de `mounted`.

- [ ] **Step 4: Run tests to verify they pass**

- [ ] **Step 5: Commit** — `fix: keep the reorder strip count current after each sale`

### Task 4: Vacío del pedido sugerido sin proveedor (#29)

**Files:**
- Modify: `lib/screens/inventario/pedido_sugerido_screen.dart:139`
- Test: `test/screens/inventario/pedido_sugerido_screen_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
testWidgets('sin proveedor y sin nada por pedir dice "No hay nada por pedir"', ...);
// PedidoSugeridoScreen(proveedor: null) sin productos bajo el mínimo:
// find.text('No hay nada por pedir') findsOneWidget; find.textContaining('a este proveedor') findsNothing.
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/inventario/pedido_sugerido_screen_test.dart`

- [ ] **Step 3: Implement** — el título del `EstadoVacio` es 'No hay nada por pedir a este proveedor'
  cuando `widget.proveedor != null` y 'No hay nada por pedir' cuando es null.

- [ ] **Step 4: Run tests to verify they pass**

- [ ] **Step 5: Commit** — `fix: word the empty suggested order without a supplier`

### Task 5: Cierre

- [ ] `dart format` sobre los archivos tocados, `flutter analyze` sin hallazgos y `flutter test` completo en verde.
- [ ] En `docs/hoja-de-ruta.md`, anotar en el paso 2 que la tanda A está hecha (y los tres ítems
  fuera de alcance). Commit `docs: record repair batch A` y `git push origin master`.
