# Arreglos tanda B (venta, escáner y voz) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Corregir los detalles menores vigentes de venta, escáner y voz que el tendero nota al
vender: escáner sin trampas, búsqueda por código con respuesta, filtros que no se atascan,
consejos que no se pierden y un dictado más tolerante.

**Architecture:** Cambios pequeños en pantallas de `lib/screens/venta/`, `lib/screens/escaner/`,
`lib/screens/configuracion/`, en `lib/util/interpretar_dictado.dart` y en
`lib/ui/recorrido/globos.dart`. No hay cambios de esquema ni dependencias nuevas.

**Tech Stack:** Flutter, Riverpod 2, Drift y mobile_scanner 7.4.2; pruebas con `flutter_test`.

**Spec:** no hay spec aparte. La fuente es el triage del 2026-10-30 (ítems #32, #38, #39, #40, #41,
#42, #43, #45, #59, #60, #62, #63, #64, #66, #73 y #74), resumido en `docs/hoja-de-ruta.md` → paso 2,
"Tanda B".

## Global Constraints

- Trabajo directo en `master` (proyecto personal): un commit por tarea, Conventional Commits en
  inglés y trailer `Co-Authored-By: Claude <modelo> <noreply@anthropic.com>` con el modelo real.
- `dart format` solo sobre los archivos tocados; `flutter analyze` limpio; suite completa en verde.
- Textos al usuario en español de Colombia, tuteo, sin tecnicismos.
- Colores siempre con `ColoresApp.of(context)` o las constantes de `ColoresApp`.
- La venta de práctica (`widget.practica`) nunca crea ni edita productos reales.

## Fuera de alcance (decidido)

- #61 "1/2" en el dictado: las cantidades son enteras y no hay ventas por fracción. "1/2" aparece en
  tamaños ("1/2 libra"), y tratarlo exige una decisión de producto.

## Review Focus

- Buscar texto normal ("coca") y dar Enter: no debe salir ningún aviso de código (tarea 2).
- Filtro de tipo elegido y luego los productos bajan a un solo tipo: la lista no puede quedar
  vacía por un filtro invisible (tarea 2).
- Consejo abierto y el usuario sale de la pantalla sin tocar "Entendido": el consejo vuelve a
  salir la próxima vez (tarea 3).
- Hoja rápida sin conexión: el foco termina en Nombre, no en Precio con el nombre vacío (tarea 4).
- Doble toque rápido en el micrófono: un solo dictado (tarea 5).

---

### Task 1: Escáner sin trampas (#40, #41, #45, #73)

**Files:**
- Create: `lib/servicios/uso_escaner.dart` (mover ahí `enum UsoEscaner` tal cual, con sus textos)
- Modify: `lib/servicios/lector_codigo.dart` (importar y reexportar `uso_escaner.dart` para no romper
  a quien hoy importa `UsoEscaner` desde ahí), `lib/screens/escaner/escaner_screen.dart`
- Test: `test/screens/escaner/codigo_escrito_test.dart`, crear `test/screens/escaner/linterna_test.dart`

**Interfaces:**
- Produces: `bool linternaDisponible(MobileScannerState estado)` en `escaner_screen.dart`, que
  devuelve `estado.error == null && estado.torchState != TorchState.unavailable`.

- [ ] **Step 1: Write the failing tests**

```dart
// codigo_escrito_test.dart
testWidgets('el código escrito acepta letras (Code 128)', ...);
// El TextField 'campo_codigo_escrito' tiene keyboardType == TextInputType.text y al escribir
// 'AB-123' y tocar 'boton_usar_codigo' devuelve 'AB-123'.
// linterna_test.dart
test('sin cámara no hay linterna', ...);       // estado con error → false
test('con linterna no disponible no se ofrece', ...); // torchState unavailable → false
test('con cámara y linterna se ofrece', ...);  // torchState off, sin error → true
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/screens/escaner/`

- [ ] **Step 3: Implement**

- El teclado del código escrito pasa a `TextInputType.text`.
- El botón "Linterna" se envuelve en un `ValueListenableBuilder` sobre el controlador y solo se
  muestra si `linternaDisponible(estado)`.
- En `_escribir`, se detiene la cámara (`_controlador.stop()`) y se marca `_escribiendo = true`
  mientras el diálogo está abierto; `_alDetectar` ignora lecturas con `_escribiendo`. Al cancelar,
  se reanuda (`start()`) y se baja la marca.
- `escaner_screen.dart` deja de importar `lector_codigo.dart` e importa `uso_escaner.dart`.

- [ ] **Step 4: Run tests to verify they pass** — `flutter test test/screens/escaner/ test/ui/boton_escanear_test.dart`

- [ ] **Step 5: Commit** — `fix: hide the torch without a camera and pause scanning while typing a code`

### Task 2: Búsqueda por código y filtro de tipo en la venta (#42, #39)

**Files:**
- Modify: `lib/screens/venta/registrar_venta_screen.dart` (`_alEnviarBusqueda`, `visibles`),
  `lib/screens/configuracion/productos_screen.dart` (`_coincide`)
- Test: `test/screens/venta/escanear_venta_test.dart`, `test/screens/venta/registrar_venta_screen_test.dart`,
  la prueba existente de Productos que usa `filtro_tipo_producto_*`

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('Enter con un código que no existe avisa', ...);
// Escribir '7702004003508' en el buscador y enviar → aviso
// 'No hay ningún producto con el código 7702004003508' (error: true); el ticket sigue vacío.
testWidgets('Enter con texto normal no avisa', ...);
// Escribir 'coca' y enviar → ningún aviso con 'No hay ningún producto'.
testWidgets('si los chips de tipo desaparecen, el filtro deja de aplicar', ...);
// Venta: dos tipos, elegir uno; desactivar los productos del otro tipo para que quede uno
// solo → los chips no se ven y la lista muestra todos los productos activos.
// Mismo caso en Productos con 'filtro_tipo_producto_*'.
```

- [ ] **Step 2: Run tests to verify they fail**

- [ ] **Step 3: Implement**

- `_alEnviarBusqueda`: si no hay producto activo y el texto, sin espacios, tiene solo dígitos y 8
  o más caracteres (`RegExp(r'^\d{8,}$')`), avisa con el texto exacto de la prueba. Un producto
  inactivo usa el aviso que ya tiene `_usarCodigo` ('Ese código es de … (inactivo). Reactívalo en
  Productos'), compartiendo ese texto en un método, sin duplicarlo.
- El filtro de tipo solo aplica cuando los chips se muestran: en la venta, la misma condición
  `conBuscador && tiposEnUso.length >= 2`; en Productos, `tiposEnUso.length >= 2`. El tipo elegido
  se conserva, por si los chips vuelven.

- [ ] **Step 4: Run tests to verify they pass**

- [ ] **Step 5: Commit** — `fix: warn on unknown typed codes and ignore a hidden type filter`

### Task 3: Consejos que se marcan vistos al cerrarse (#74)

**Files:**
- Modify: `lib/ui/recorrido/globos.dart` (`mostrarConsejo`), `lib/screens/venta/registrar_venta_screen.dart:~305-317`,
  `lib/screens/configuracion/producto_screen.dart:~110-119`
- Test: `test/ui/globos_test.dart` y las pruebas de consejo existentes (buscar `Consejo.escanearVenta`
  y `Consejo.escanearProducto` en `test/`)

**Interfaces:**
- Produces: `ControladorGlobos mostrarConsejo(BuildContext context, PasoGlobo paso, {VoidCallback? alCerrar})`.
  `alCerrar` se llama una sola vez cuando el usuario cierra el consejo ("Entendido" o tocando el
  hueco, si eso lo cierra hoy), y nunca por `cerrar()` al desmontar la pantalla.

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('alCerrar se llama al tocar Entendido', ...);       // globos_test
testWidgets('alCerrar no se llama si se cierra con cerrar()', ...);
testWidgets('salir de la venta sin cerrar el consejo lo deja pendiente', ...);
// consejosVistosProvider no contiene Consejo.escanearVenta tras hacer pop sin tocar Entendido;
// con Entendido sí lo contiene. Mismo caso para Consejo.escanearProducto en ProductoScreen.
```

- [ ] **Step 2: Run tests to verify they fail**

- [ ] **Step 3: Implement** — en las dos pantallas, `marcarVisto` se mueve al `alCerrar`. La
  comprobación `vistos.contains(...)` antes de mostrar no cambia.

- [ ] **Step 4: Run tests to verify they pass**

- [ ] **Step 5: Commit** — `fix: mark first-use tips as seen only when closed`

### Task 4: Hoja rápida y Open Food Facts (#43, #38)

**Files:**
- Modify: `lib/screens/venta/hoja_producto_rapido.dart` (`_autocompletar`, campos),
  `lib/servicios/open_food_facts.dart:~77`
- Test: `test/servicios/open_food_facts_test.dart` y la prueba existente de la hoja rápida
  (buscar `campo_nombre_rapido` en `test/`)

- [ ] **Step 1: Write the failing tests**

```dart
test('toma la primera marca no vacía', ...);
// 'brands': ' , Alpina, Colanta' → marca 'Alpina'; 'brands': ' , ' → null.
testWidgets('si la consulta no trae nombre, el foco pasa a Nombre', ...);
// ConsultaProducto falsa que devuelve null → tras pumpAndSettle el campo 'campo_nombre_rapido'
// tiene el foco.
testWidgets('si la consulta trae nombre, el foco sigue en Precio', ...);
testWidgets('si ya se escribió el precio, el foco no se mueve', ...);
```

- [ ] **Step 2: Run tests to verify they fail**

- [ ] **Step 3: Implement**

- La marca es la primera de la lista separada por comas que no queda vacía tras `trim`.
- El precio conserva `autofocus`. Al terminar `_autocompletar` (con o sin datos), si el nombre
  sigue vacío y el precio también, el foco pasa a Nombre con un `FocusNode` propio, que se libera
  en `dispose`.

- [ ] **Step 4: Run tests to verify they pass**

- [ ] **Step 5: Commit** — `fix: focus the name when lookup finds none and skip empty brands`

### Task 5: Dictado más tolerante (#59, #60, #62, #63, #64)

**Files:**
- Modify: `lib/util/interpretar_dictado.dart` (`_vacias`, `_raiz`),
  `lib/screens/venta/registrar_venta_screen.dart` (`_dictar`, botón `boton_dictar`),
  `lib/screens/venta/hoja_dictado.dart:~214`
- Test: `test/util/interpretar_dictado_test.dart`, `test/screens/venta/dictado_venta_test.dart`

- [ ] **Step 1: Write the failing tests**

```dart
test('"unos" y "unas" no son productos', ...);
// 'unos panes' con producto 'Pan' → una línea Pan, cantidad 1, sin dudosos ni no encontrados.
test('plurales: raíz correcta', ...);
// Por la API pública del intérprete, cada plural encuentra su producto exacto: 'leches'→'Leche',
// 'panes'→'Pan', 'limones'→'Limón', 'arroces'→'Arroz', 'colas'→'Cola', 'huevos'→'Huevo'.
testWidgets('doble toque en el micrófono abre un solo dictado', ...);
// Dictado falso cuyo preparar() tarda (Completer); dos taps en 'boton_dictar' antes de completar
// → preparar se llama una vez.
testWidgets('Dictar otra vez vuelve a escuchar', ...); // regresión del cambio a bucle
testWidgets('la cantidad del dictado se lee como "Cantidad: 2"', ...);
// find.bySemanticsLabel('Cantidad: 2') en la hoja "¿Agrego esto?".
```

- [ ] **Step 2: Run tests to verify they fail**

- [ ] **Step 3: Implement**

- `_vacias` suma 'unos' y 'unas'.
- `_raiz`, para palabras de más de 3 letras: si termina en 'ces', cambia 'ces' por 'z'; si termina
  en 'es' y la letra anterior está en {l, n, r, d, j, y, s}, quita 'es'; si termina en 's', quita
  's'. Si no, la deja igual.
- Una marca `_preparandoDictado` se pone antes del `await preparar()` y se baja en `finally`. El
  botón se deshabilita con esa marca o con `_oyendo != null`, y `_dictar` sale de inmediato si la
  marca está puesta.
- "Dictar otra vez" se vuelve un bucle dentro de `_dictar` en vez de `await _dictar()` recursivo.
- El número de la cantidad va en `Semantics(label: 'Cantidad: N', excludeSemantics: true)`.

- [ ] **Step 4: Run tests to verify they pass**

- [ ] **Step 5: Commit** — `fix: make dictation ignore filler words, fix plurals and avoid double starts`

### Task 6: "¿Quién compra?" sin repetir y fila quitada estable (#66, #32)

**Files:**
- Modify: `lib/screens/venta/hoja_como_paga.dart:~176-181`, `lib/screens/correccion/hoja_movimiento.dart:~452-460`
- Test: `test/screens/venta/cliente_habitual_test.dart`, la prueba existente de corrección de líneas
  (buscar `quitar_linea_` en `test/`)

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('"¿Quién compra?" aparece una sola vez', ...);
// Con la lista desplegada sin cliente, y con un cliente elegido:
// find.textContaining('¿Quién compra?') findsOneWidget en ambos casos.
testWidgets('quitar una línea no mueve sus botones', ...);
// tester.getCenter(find.byKey(Key('sumar_linea_<id>'))) igual antes y después de tocar
// 'quitar_linea_<id>'.
```

- [ ] **Step 2: Run tests to verify they fail**

- [ ] **Step 3: Implement**

- El `SelectorCliente` de la hoja de cobro usa `etiqueta: 'Cliente'`.
- Cuando la línea está quitada, en lugar del botón de quitar va un `SizedBox` del mismo tamaño que
  un `IconButton` (48 × 48).

- [ ] **Step 4: Run tests to verify they pass**

- [ ] **Step 5: Commit** — `fix: say who buys once and keep removed rows steady`

### Task 7: Cierre

- [ ] `flutter analyze` sin hallazgos y `flutter test` completo en verde.
- [ ] En `docs/hoja-de-ruta.md`, paso 2: tanda B hecha, con #61 fuera de alcance. Commit
  `docs: record repair batch B` y `git push origin master`.
