# Mejoras de tienda — Tanda 2 (letra grande y editar productos) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tamaño de letra propio de la app (Normal / Grande / Muy grande) sin desbordes en las
pantallas principales, y editar productos (solo admin) desde Nueva venta, el escáner, Inventario y
Ajustes → Productos.

**Architecture:** Un `Notifier` guarda el tamaño en `SharedPreferences` (como la apariencia) y
`MaterialApp.builder` combina esa escala con la del sistema con tope 2,0×. Para editar productos
se reutiliza `ProductoScreen(producto:)`; las nuevas entradas solo se muestran con
`sesionProvider.esAdmin`.

**Tech Stack:** Flutter, Riverpod, shared_preferences (ya en el proyecto), flutter_test. Sin
dependencias nuevas.

**Spec:** `docs/superpowers/specs/2026-10-26-vecitienda-mejoras-tienda-design.md` (secciones 2 y 5).

## Global Constraints

- Lineamientos UNIMINUTO v1.2; nombres en español como el resto del código; archivos en
  `snake_case`.
- `flutter analyze` sin hallazgos; todas las pruebas en verde en cada commit. No reformatear el
  repositorio con el formateador de Dart 3.13: formatear solo archivos nuevos; líneas nuevas en
  archivos existentes ≤ 100 caracteres.
- Escalas exactas: Normal 1,0×, Grande 1,3×, Muy grande 1,6×; escala total = sistema × app, con
  tope 2,0×. Se guarda por celular. Por defecto Normal.
- Textos fijos: "Tamaño de letra", "Normal", "Grande", "Muy grande", "Editar producto", "Editar".
- Solo el admin ve cualquier opción de editar producto; el vendedor no ve ninguna.
- Editar desde Nueva venta no cambia el precio de lo que ya está en el ticket.
- WCAG 2.1 AA: botones de ícono con `tooltip`, objetivos ≥ 48 dp.
- Commits Conventional Commits con `Co-Authored-By:` del modelo que los hizo. No fusionar ni
  subir sin autorización del usuario.

## Review Focus

1. Celular con letra del sistema 1,5× y la app en Muy grande (1,6×): la escala efectiva queda en
   2,0×, no 2,4×. Test en Task 1.
2. Un valor guardado desconocido o corrupto en preferencias arranca en Normal. Test en Task 1.
3. Mantener presionado un producto en la venta de práctica del recorrido no abre el editor (aunque
   sea admin). Test en Task 3.
4. Editar el precio desde Nueva venta con ese producto ya en el ticket: la línea conserva el
   precio viejo; tocar el mosaico otra vez suma a la misma línea (comportamiento actual de
   `agregarProducto`, que se mantiene). Test en Task 3.
5. Inicio en 360 dp a 2,0×: sin desborde (bug conocido de la hoja de ruta). Test en Task 2.

---

### Task 1: Tamaño de letra

**Files:**
- Create: `lib/providers/tamano_letra_provider.dart`
- Modify: `lib/main.dart` (`MaterialApp.builder`), `lib/screens/home/hoja_apariencia.dart`
- Test: `test/providers/tamano_letra_provider_test.dart`, `test/screens/home/hoja_apariencia_test.dart`

**Interfaces:**
- Produces:
  - `enum TamanoLetra { normal, grande, muyGrande }` con `double get factor` (1.0, 1.3, 1.6).
  - `final tamanoLetraProvider = NotifierProvider<TamanoLetraNotifier, TamanoLetra>` — lee la
    clave `'tamano_letra'` de `preferenciasProvider` (`'normal' | 'grande' | 'muy_grande'`;
    otro valor → `normal`); `Future<void> elegir(TamanoLetra)`.
  - `TextScaler escalaCombinada(TextScaler sistema, TamanoLetra tamano)` —
    `TextScaler.linear(min(sistema.scale(14) / 14 * tamano.factor, 2.0))`; con `normal`
    devuelve `sistema` tal cual (no altera el comportamiento actual).
- `MaterialApp.builder`: envuelve `child` en `MediaQuery(data: …copyWith(textScaler:
  escalaCombinada(...)))`.
- Hoja Apariencia: debajo del selector actual, título "Tamaño de letra" y un
  `SelectorSegmentado<TamanoLetra>` (`Key('selector_tamano_letra')`) con "Normal", "Grande",
  "Muy grande"; aplica al tocar.

- [ ] **Step 1: Write failing tests**
```dart
test('arranca en normal sin valor guardado o con uno desconocido', ...);
test('elegir guarda y recuerda el tamaño', ...); // 'muy_grande' en preferencias
test('escalaCombinada multiplica y topa en 2,0', () {
  expect(escalaCombinada(TextScaler.linear(1.0), TamanoLetra.grande).scale(10), closeTo(13, 0.01));
  expect(escalaCombinada(TextScaler.linear(1.5), TamanoLetra.muyGrande).scale(10), closeTo(20, 0.01));
  expect(escalaCombinada(TextScaler.linear(1.2), TamanoLetra.normal).scale(10), closeTo(12, 0.01));
});
testWidgets('la hoja Apariencia cambia el tamaño de letra al tocar', ...);
```
- [ ] **Step 2: Run** `flutter test test/providers/tamano_letra_provider_test.dart test/screens/home/hoja_apariencia_test.dart` — Expected: FAIL.
- [ ] **Step 3: Implement** siguiendo `apariencia_provider.dart`.
- [ ] **Step 4: Run** los tests — Expected: PASS.
- [ ] **Step 5: Commit** `feat: let each phone choose a larger text size`

---

### Task 2: Sin desbordes a 2,0× en las pantallas principales

**Files:**
- Modify: lo que haga falta en `lib/screens/home/` (Inicio / `ResumenScreen`), `lib/screens/venta/registrar_venta_screen.dart`, `lib/screens/venta/hoja_como_paga.dart`, `lib/screens/fiado/lista_fiado_screen.dart`
- Create: `test/screens/letra_grande_test.dart`
- Modify: `docs/hoja-de-ruta.md` (quitar de "Después" el desborde del Inicio)

**Interfaces:**
- Consumes: Task 1 no es necesario para la prueba (se fija `textScaler` directamente).

Prueba: un helper que monta cada pantalla con `tester.view.physicalSize = Size(360 * 3, 780 * 3)`,
`devicePixelRatio = 3` y `MediaQuery` con `TextScaler.linear(2.0)`, en claro, con datos de
ejemplo (productos con nombres largos, un cliente con deuda, una venta del día), y verifica
`tester.takeException()` nulo después de `pumpAndSettle`. Seguir los montajes de
`test/support/montaje.dart` y de `test/screens/home/home_screen_test.dart`.

- [ ] **Step 1: Write failing tests**
```dart
testWidgets('Inicio a 2,0× en 360 dp no desborda', ...);
testWidgets('Nueva venta a 2,0× en 360 dp no desborda', ...);
testWidgets('¿Cómo paga? abierta, con ¿Quién compra? desplegado, a 2,0× no desborda', ...);
testWidgets('Fiado a 2,0× en 360 dp no desborda', ...);
```
- [ ] **Step 2: Run** `flutter test test/screens/letra_grande_test.dart` — Expected: FAIL al menos en Inicio (bug conocido).
- [ ] **Step 3: Fix** cada desborde con `Flexible`/`Expanded`, `Wrap`, `maxLines` + `TextOverflow.ellipsis` o cambiando `Row` por `Wrap`; sin reducir la letra.
- [ ] **Step 4: Run** `flutter test` (suite completa, por los cambios de diseño) — Expected: PASS.
- [ ] **Step 5: Commit** `fix: keep the main screens readable at twice the text size`

---

### Task 3: Editar producto desde Nueva venta y el escáner

**Files:**
- Modify: `lib/ui/avisos.dart` (`avisar`), `lib/ui/mosaico.dart` (`Mosaico`), `lib/screens/venta/registrar_venta_screen.dart`
- Test: `test/screens/venta/editar_desde_venta_test.dart`, `test/ui/avisos_test.dart` (crear si no existe)

**Interfaces:**
- Produces:
  - `avisar(BuildContext, String, {VoidCallback? onDeshacer, bool error = false, String? etiquetaAccion, VoidCallback? onAccion})` — si `onAccion` no es null, el `SnackBar` lleva `SnackBarAction(label: etiquetaAccion!, ...)` (`onDeshacer` tiene prioridad si vienen ambos; no ocurre).
  - `Mosaico` gana `final VoidCallback? onLongPress` que pasa al `InkWell`.
  - En `registrar_venta_screen.dart`: `Future<void> _editarProducto(Producto p)` abre `ProductoScreen(producto: p)`.

Comportamiento:
- Mosaico de producto: con `esAdmin && !widget.practica`, `onLongPress` abre una hoja inferior con
  un `ListTile` `Key('menu_editar_producto')` "Editar producto" (`Icons.edit_outlined`) que llama
  `_editarProducto`. Vendedor o práctica: `onLongPress` null.
- Escáner con código existente y activo: `avisar(context, '${p.nombre} agregado', etiquetaAccion:
  'Editar', onAccion: () => _editarProducto(p))` solo si `esAdmin`; si no, el aviso de hoy.
- El ticket no se toca al volver del editor (las líneas guardan su precio).

- [ ] **Step 1: Write failing tests**
```dart
testWidgets('admin: mantener presionado un producto abre Editar producto', ...);
testWidgets('vendedor: mantener presionado no muestra el menú', ...);
testWidgets('práctica del recorrido: mantener presionado no muestra el menú', ...);
testWidgets('editar el precio no cambia la línea ya agregada al ticket', ...); // total igual tras volver
testWidgets('admin: al escanear un producto existente el aviso trae Editar', ...); // lector_falso.dart
testWidgets('vendedor: al escanear el aviso no trae Editar', ...);
testWidgets('avisar con acción muestra la etiqueta y la ejecuta', ...);
```
- [ ] **Step 2: Run** los tests — Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `flutter test test/screens/venta/ test/ui/` — Expected: PASS.
- [ ] **Step 5: Commit** `feat: let admins edit a product from the sale screen and the scanner`

---

### Task 4: Editar producto desde Inventario y lápiz en Productos

**Files:**
- Modify: `lib/screens/inventario/detalle_inventario_screen.dart`, `lib/screens/configuracion/productos_screen.dart`
- Test: `test/screens/inventario/` (archivo existente del detalle o nuevo `editar_desde_inventario_test.dart`), `test/screens/configuracion/productos_screen_test.dart`

Comportamiento:
- Detalle de Inventario: en el `AppBar`, `IconButton` `Key('boton_editar_producto')`,
  `tooltip: 'Editar'`, `Icons.edit_outlined`, solo admin → `ProductoScreen(producto:
  item.producto)`.
- Ajustes → Productos: cada fila activa muestra, antes del botón Desactivar, un `IconButton`
  `Key('boton_editar_${p.id}')` `tooltip: 'Editar'` `Icons.edit_outlined` que abre el editor (igual
  que tocar la fila). Ambos botones ≥ 48 dp y sin desbordar a 2,0× en 360 dp.

- [ ] **Step 1: Write failing tests**
```dart
testWidgets('admin ve Editar en el detalle de inventario y abre el producto', ...);
testWidgets('vendedor no ve Editar en el detalle de inventario', ...);
testWidgets('cada producto muestra el lápiz Editar y abre el editor', ...);
testWidgets('la fila con lápiz y desactivar no desborda a 2,0× en 360 dp', ...);
```
- [ ] **Step 2: Run** — Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `flutter test test/screens/inventario/ test/screens/configuracion/` — Expected: PASS.
- [ ] **Step 5: Commit** `feat: show product edit buttons in inventory and the product list`

---

### Task 5: Hoja de ruta y verificación final

- [ ] **Step 1:** `docs/hoja-de-ruta.md`: en "En curso" marcar la tanda 2 como hecha; en
  "Pendiente de verificar" agregar "tanda 2 en celular real (tamaño de letra en las tres
  opciones, editar producto desde venta, escáner, inventario y productos)".
- [ ] **Step 2: Run** `dart format --output=none --set-exit-if-changed` sobre los archivos creados en la rama — Expected: sin cambios.
- [ ] **Step 3: Run** `flutter analyze` — Expected: "No issues found!".
- [ ] **Step 4: Run** `flutter test` — Expected: todas pasan.
- [ ] **Step 5: Commit** `docs: mark text size and product editing as done in the roadmap`
