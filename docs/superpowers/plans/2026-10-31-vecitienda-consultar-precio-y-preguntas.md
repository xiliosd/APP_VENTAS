# Consultar precio y preguntas frecuentes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Que cualquier vendedor consulte el precio de un producto escaneándolo desde el Inicio sin
tocar ninguna venta, que el recorrido lo enseñe, y que haya preguntas frecuentes de toda la app.

**Architecture:** Un flujo nuevo `consultarPrecio` reutiliza el lector de códigos
(`lectorCodigoProvider`), `ProductoRepository.productoPorCodigo`, la hoja rápida de producto y
`mostrarHojaInferior`; muestra una hoja propia según el resultado. Un botón en la barra fija del
Inicio lo abre. Las preguntas frecuentes son contenido constante en Dart con una pantalla de
secciones expansibles, abierta desde Ajustes → AYUDA y desde el menú de cuenta.

**Tech Stack:** Flutter, Riverpod 2, Drift; pruebas con `flutter_test` y `test/support/lector_falso.dart`.

**Spec:** `docs/superpowers/specs/2026-10-31-vecitienda-consultar-precio-y-preguntas-design.md`

## Global Constraints

- Trabajo directo en `master`: un commit por tarea, Conventional Commits en inglés y trailer
  `Co-Authored-By: Claude <modelo> <noreply@anthropic.com>` con el modelo real.
- `dart format` en archivos nuevos y tocados (salvo que reformatee regiones grandes ajenas: entonces
  solo las líneas editadas, y se dice en el reporte); `flutter analyze` limpio; suite en verde.
- Sin dependencias nuevas ni cambios de esquema.
- Textos en español de Colombia, tuteo, sin tecnicismos; colores con `ColoresApp`.
- WCAG 2.1 AA: botones con texto, semántica, letra 2,0× sin desbordes, modo oscuro.
- La consulta nunca toca `ticketProvider` ni ninguna venta. El vendedor nunca ve el precio de compra ni la ganancia.

## Review Focus

- Consultar con un borrador de venta abierto (productos en el ticket): el ticket queda igual (tarea 1).
- Cancelar el escáner sin leer: vuelve al Inicio sin mensajes ni hojas (tarea 1).
- Agregar producto y cancelar la hoja rápida: vuelve a la hoja de "no está", sin crear nada (tarea 1).
- Letra 2,0× en 360 dp: la barra del Inicio con el botón nuevo y la hoja de consulta no desbordan (tareas 1 y 2).
- Vendedor (no administrador): no ve "Editar producto" en la consulta (tarea 1).

---

### Task 1: Flujo y hoja de consulta de precio

**Files:**
- Modify: `lib/servicios/uso_escaner.dart` (valor nuevo `consulta`)
- Create: `lib/screens/consulta/consultar_precio.dart`
- Test: crear `test/screens/consulta/consultar_precio_test.dart`; ajustar las pruebas de
  `UsoEscaner` existentes si enumeran los valores

**Interfaces:**
- Produces:
  - `UsoEscaner.consulta`: `ayuda` = `'Te muestro el precio; no se agrega a ninguna venta'`,
    `conSeguirSinCamara` = false.
  - `Future<void> consultarPrecio(BuildContext context, WidgetRef ref)` en `consultar_precio.dart`:
    el flujo completo, que termina cuando el usuario elige "Listo" o cancela el escáner.
  - `enum AccionConsulta { otra, listo, agregar, editar }`, que devuelve la hoja.
  - `class HojaConsultaPrecio extends StatelessWidget` con `{required String codigo, Producto? producto, required bool esAdmin}`.

- [ ] **Step 1: Write the failing tests** (con `LectorFalso` y la base en memoria de `test/support/montaje.dart`)

```dart
testWidgets('producto activo: muestra nombre, precio, marca y tamaño', ...);
// Producto 'Gaseosa' precio 2500 marca 'Postobón' tamano '400 ml' código '7702'. Lector ['7702'].
// Hoja: 'Gaseosa', formatoMoneda(2500), 'Postobón · 400 ml', botones 'Consultar otro' y 'Listo';
// LectorFalso.usos == [UsoEscaner.consulta].
testWidgets('no toca el ticket abierto', ...);
// ticketProvider con una línea antes; tras consultar y 'Listo' el ticket es idéntico.
testWidgets('Consultar otro vuelve a escanear', ...);   // lector ['7702', null] → 2 lecturas
testWidgets('cancelar el escáner no muestra nada', ...); // lector [null] → sin hoja
testWidgets('código desconocido: lo dice y deja agregar', ...);
// Lector ['999']: texto 'Este código aún no está en tus productos' y botón 'Agregar producto';
// al tocarlo se abre la hoja rápida (campo 'campo_nombre_rapido'); llenar nombre 'Pan' y precio
// 500 y guardar → la hoja de consulta muestra 'Pan' y formatoMoneda(500).
testWidgets('agregar y cancelar la hoja rápida no crea nada', ...);
testWidgets('producto inactivo: lo dice sin precio', ...);
// Texto 'Este producto está inactivo' y 'El administrador lo reactiva en Productos.';
// no aparece formatoMoneda(precio).
testWidgets('el vendedor no ve Editar producto; el administrador sí', ...);
testWidgets('a letra 2,0× en 360 dp la hoja no desborda', ...);
```

- [ ] **Step 2: Run tests to verify they fail** — `flutter test test/screens/consulta/`

- [ ] **Step 3: Implement**

- Bucle en `consultarPrecio`:
  1. Leer con `uso: UsoEscaner.consulta`; si es null, termina.
  2. Buscar con `productoPorCodigo`.
  3. Mostrar la hoja con `mostrarHojaInferior` (título 'Consultar precio') y actuar según la acción:
     - `otra`: vuelve a leer.
     - `listo` o null: termina.
     - `agregar`: abre `mostrarHojaProductoRapido(context, codigo: codigo, textoGuardar: 'Guardar')` y, si
       se creó, vuelve a mostrar la hoja con el nuevo; si se canceló, vuelve a la hoja de "no está".
     - `editar`: abre `ProductoScreen(producto: …)` y al volver relee el producto por código y vuelve a
       mostrar la hoja.
- Precio con `formatoMoneda`, en tamaño de titular y en semántica ("Precio: $ 2.500").
- `esAdmin` sale de `sesionProvider`.

- [ ] **Step 4: Run tests to verify they pass**

- [ ] **Step 5: Commit** — `feat: look up a product price by scanning without touching the sale`

### Task 2: Botón "Consultar precio" en el Inicio y globo del recorrido

**Files:**
- Modify: `lib/screens/home/resumen_screen.dart` (`_BarraAcciones`, ~144-216), `lib/screens/recorrido/globos_inicio.dart`
- Test: `test/screens/home/resumen_screen_test.dart`, la prueba que cubre `globosInicio` (buscar `globosInicio` y
  `tarjeta_ventas` en `test/`), `test/screens/letra_grande_test.dart` si ya prueba el Inicio a 2,0×

**Interfaces:**
- Consumes: `consultarPrecio(context, ref)` de la tarea 1.

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('el Inicio muestra Consultar precio sobre la barra y lo abre', ...);
// find.byKey(Key('boton_consultar_precio')) con texto 'Consultar precio'; su rect queda por encima
// de 'boton_nueva_venta'; al tocarlo con LectorFalso(['7702']) aparece la hoja de consulta.
testWidgets('el vendedor también lo ve', ...);
testWidgets('el recorrido del Inicio señala Consultar precio después de + Venta', ...);
// globosInicio[i].objetivos == ['boton_consultar_precio'] justo después del de 'boton_nueva_venta';
// texto '¿Te preguntan cuánto vale algo? Escanéalo aquí y ves el precio sin vender.'
testWidgets('Inicio a letra 2,0× en 360 dp no desborda con el botón nuevo', ...);
```

- [ ] **Step 2: Run tests to verify they fail**

- [ ] **Step 3: Implement**

- Dentro de `_BarraAcciones`, en el mismo `SafeArea` y encima de la fila actual, va un botón de ancho
  completo con borde primario, ícono `Icons.sell_outlined` y texto 'Consultar precio', con key
  `boton_consultar_precio`.
- Lo envuelve `ObjetivoRecorrido(id: 'boton_consultar_precio')`.
- Como vive dentro de la barra, el `Expanded` del tablero ya le cede el alto.
- La barra debe convertirse en `ConsumerWidget` para pasarle `ref` a `consultarPrecio`.

- [ ] **Step 4: Run tests to verify they pass**

- [ ] **Step 5: Commit** — `feat: add a Consultar precio button to the home bar and the tour`

### Task 3: Preguntas frecuentes

**Files:**
- Create: `lib/screens/ayuda/preguntas_frecuentes.dart` (contenido), `lib/screens/ayuda/preguntas_frecuentes_screen.dart`
- Modify: `lib/screens/configuracion/ajustes_screen.dart` (grupo AYUDA, ~172),
  `lib/screens/home/home_screen.dart` (menú `menu_cuenta`, ~245-290)
- Test: crear `test/screens/ayuda/preguntas_frecuentes_test.dart`; ajustar las pruebas del menú de cuenta y de Ajustes

**Interfaces:**
- Produces:
  - `class PreguntaFrecuente { const PreguntaFrecuente(this.pregunta, this.respuesta); final String pregunta, respuesta; }`
  - `class TemaAyuda { const TemaAyuda(this.titulo, this.preguntas); final String titulo; final List<PreguntaFrecuente> preguntas; }`
  - `const List<TemaAyuda> temasAyuda`
  - `class PreguntasFrecuentesScreen extends StatelessWidget`

- [ ] **Step 1: Write the failing tests**

```dart
test('hay temas de toda la app y ninguno vacío', ...);
// Títulos exactos en este orden: 'Ventas', 'Fiado y clientes', 'Gastos', 'Inventario y pedidos',
// 'Reportes', 'Productos y escáner', 'Cuenta y seguridad', 'Respaldo', 'Apariencia';
// cada tema con al menos 2 preguntas; ninguna pregunta repetida.
testWidgets('una pregunta se abre y muestra su respuesta', ...);
testWidgets('Ajustes → AYUDA abre Preguntas frecuentes', ...);   // key 'boton_preguntas_frecuentes'
testWidgets('el menú de cuenta abre Preguntas frecuentes (también el vendedor)', ...);
// PopupMenuItem key 'menu_preguntas_frecuentes', texto 'Preguntas frecuentes'.
testWidgets('a letra 2,0× en 360 dp y en modo oscuro no desborda', ...);
```

- [ ] **Step 2: Run tests to verify they fail**

- [ ] **Step 3: Implement**

- **Pantalla:** `AppBar` con 'Preguntas frecuentes' y una lista con `TituloSeccion` por tema más un
  `ExpansionTile` por pregunta (respuesta en `Text` con `textoSecundario`).
- **Ajustes:** opción `_Opcion` 'Preguntas frecuentes', subtítulo 'Cómo hacer cada cosa en la app' e
  ícono `Icons.help_outline_rounded`, debajo de "Ver el recorrido otra vez".
- **Menú de cuenta:** ítem entre 'Apariencia' y 'Cerrar sesión'.
- **Contenido:** cada respuesta sale de leer la pantalla real en `lib/screens/`. Los nombres de
  botones y pestañas van entre comillas, tal como aparecen. Las respuestas solo para el administrador
  empiezan con 'Solo el administrador: '. Va una pregunta de consultar precio en 'Productos y escáner'.
  Nada de funciones que no existen (no hay WhatsApp, ni varios celulares por tienda, ni ventas por
  fracción).
- Se reporta la lista de preguntas para que el usuario la revise.

- [ ] **Step 4: Run tests to verify they pass**

- [ ] **Step 5: Commit** — `feat: add frequently asked questions for the whole app`

### Task 4: Cierre

- [ ] `flutter analyze` sin hallazgos y `flutter test` completo en verde.
- [ ] `docs/hoja-de-ruta.md`: mover "Consultar precio por código de barras" a "Hecho" (con las
  preguntas frecuentes), marcar el paso 3 como hecho en "Orden de lo que falta" y agregar a
  "Pendiente de verificar" la consulta de precio y las preguntas frecuentes en el celular. README → "Usage/examples": una línea de
  consultar precio. Commit `docs: record price lookup and FAQ` y `git push origin master`.
