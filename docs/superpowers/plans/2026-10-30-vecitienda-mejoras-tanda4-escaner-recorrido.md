# VeciTienda — Mejoras de tienda, tanda 4: escáner y recorrido — Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Que el escáner se entienda sin conocer el ícono (botón con texto, consejo de primera vez, texto dentro de la cámara) y que el recorrido inicial enseñe a crear y vender escaneando.

**Architecture:** Un enum `UsoEscaner` dice para qué se abre la cámara y lleva el texto de ayuda y si muestra "Seguir sin cámara"; `LectorCodigo.leer` lo recibe. Un widget `BotonEscanear` reemplaza los `IconButton`. El consejo de primera vez reutiliza `CapaGlobos` en modo consejo (sin "Saltar recorrido", con "Entendido") y se recuerda por celular en `SharedPreferences` con un `Notifier`. El recorrido suma "Crear escaneando" (paso 2) y "Vender escaneando" (paso 3), que abre la práctica con la cámara.

**Tech Stack:** Flutter 3.47 / Dart, Riverpod (`Notifier`), Drift, `mobile_scanner` (ya instalado), `shared_preferences`.

**Spec:** `docs/superpowers/specs/2026-10-26-vecitienda-mejoras-tienda-design.md`, sección 7 y "Orden de trabajo".

## Global Constraints

- Sin dependencias nuevas.
- Textos literales del spec: botón **"Escanear código"**; consejo de venta "Apunta la cámara al código de barras del producto para venderlo más rápido"; consejo de producto "Apunta la cámara al código de barras del producto para crearlo sin escribir"; ayuda en venta "Si el código no existe, te ofrezco crearlo; si existe, lo sumo a la venta"; recorrido **"Crear escaneando"**, **"Vender escaneando"**, **"Seguir sin cámara"**.
- Ayuda en Crear/editar producto (decisión del plan, el spec solo fija "lo lleno por ti"): "Si conozco el código, lo lleno por ti".
- El consejo se muestra una sola vez por celular (se marca visto al mostrarse, no al cerrarse) y nunca en la venta de práctica.
- Solo el admin ve editar productos (sin cambios de tanda 2); el vendedor sí ve y usa "Escanear código".
- En la práctica, un código desconocido crea un producto real (hoja rápida) y la venta sigue siendo de práctica.
- Sin permiso de cámara el recorrido no se bloquea.
- WCAG 2.1 AA: objetivos ≥ 48 dp, `Semantics`/`tooltip` donde haya solo ícono, contraste ≥ 4,5:1 (texto blanco sobre `c.velo`).
- Cada tarea: `dart format`, `flutter analyze` sin hallazgos, suite completa en verde. Commits con Conventional Commits en inglés y `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Rama: `feature/mejoras-tienda-tanda4` desde `master` (81cbc5b). Fusionar o subir solo con autorización del usuario.

## Review Focus

1. **Consejo que queda flotando:** salir de la pantalla (atrás) con el consejo abierto debe quitar la capa; `dispose` llama `cerrar()`. Prueba en Tarea 3.
2. **Pruebas viejas que abren Nueva venta o Crear producto con preferencias vacías:** el consejo taparía la pantalla. `containerConSesion` siembra los consejos como vistos; las pruebas con preferencias propias usan `consejosVistos`. Tarea 2.
3. **"Vender escaneando" cancelado o sin cámara:** volver del escáner sin código debe dejar la práctica normal con el primer globo; con código leído, los globos empiezan en "Toca Cobrar". Pruebas en Tarea 5.
4. **Globos encima del escáner:** los globos van en el overlay raíz; en la práctica con cámara al abrir, los globos se muestran solo después de volver del escáner. Prueba en Tarea 5.
5. **Código ya existente en "Crear escaneando":** no abre la hoja; avisa "Ese código ya es de <nombre>". Prueba en Tarea 5.

---

### Task 1: Uso del escáner, texto de ayuda y "Seguir sin cámara"

**Files:**
- Modify: `lib/servicios/lector_codigo.dart`
- Modify: `lib/screens/escaner/escaner_screen.dart`
- Modify: `test/support/lector_falso.dart`
- Test: `test/screens/escaner/pie_escaner_test.dart` (nuevo)

**Interfaces:**
- Produces:
  - `enum UsoEscaner { venta, practica, producto, primerosProductos }` en `lector_codigo.dart`, con `String get ayuda` y `bool get conSeguirSinCamara` (true solo para `practica` y `primerosProductos`). `ayuda`: venta y practica → texto de venta; producto → "Si conozco el código, lo lleno por ti"; primerosProductos → "Si el código no existe, te ofrezco crearlo".
  - `LectorCodigo.leer(BuildContext context, {UsoEscaner uso = UsoEscaner.venta})`.
  - `EscanerScreen({super.key, this.uso = UsoEscaner.venta})`.
  - `PieEscaner({super.key, required UsoEscaner uso, required VoidCallback onEscribir, required VoidCallback onSeguirSinCamara})` público en `escaner_screen.dart` (la columna inferior actual, extraída para probarla sin cámara).
  - `LectorFalso` guarda `List<UsoEscaner> usos` con cada lectura.

- [ ] **Step 1: Escribir pruebas que fallan** en `pie_escaner_test.dart` (montar `PieEscaner` dentro de `MaterialApp(theme: temaClaro())`):
  - `'venta muestra la ayuda de venta y no Seguir sin cámara'`: `find.text('Si el código no existe, te ofrezco crearlo; si existe, lo sumo a la venta')` → findsOneWidget; `find.byKey(Key('boton_seguir_sin_camara'))` → findsNothing; `find.byKey(Key('boton_escribir_codigo'))` → findsOneWidget.
  - `'producto muestra lo lleno por ti'`: texto `'Si conozco el código, lo lleno por ti'`.
  - `'práctica ofrece Seguir sin cámara y lo avisa al tocar'`: tocar `boton_seguir_sin_camara` llama `onSeguirSinCamara` (contador == 1); texto visible `'Seguir sin cámara'`.
  - `'los objetivos táctiles miden al menos 48'`: `tester.getSize(find.byKey(Key('boton_seguir_sin_camara'))).height >= 48`.

- [ ] **Step 2:** `flutter test test/screens/escaner/pie_escaner_test.dart` → falla (no existe `PieEscaner`).

- [ ] **Step 3: Implementar.** `PieEscaner` muestra `'Apunta al código de barras'`, debajo `uso.ayuda` (ambos blanco `ColoresApp.blancoMarca`, 16 y 14), el `BotonPrincipal` "Escribir código" de hoy y, si `uso.conSeguirSinCamara`, un `TextButton` blanco `'Seguir sin cámara'` con `minimumSize: Size(48, 48)`. `EscanerScreen` lo usa; `onSeguirSinCamara` hace `Navigator.pop(context)` (null). `LectorCamara.leer` pasa `uso` a `EscanerScreen`. Actualizar `LectorFalso.leer` a la nueva firma (agrega `uso` a `usos`).

- [ ] **Step 4:** prueba nueva + `flutter test` completo en verde; `flutter analyze` limpio.

- [ ] **Step 5: Commit** `feat: tell what the scanner does and allow skipping it in the tour`

### Task 2: Botón "Escanear código", consejo de primera vez y su memoria

**Files:**
- Create: `lib/ui/boton_escanear.dart`
- Create: `lib/providers/consejos_provider.dart`
- Create: `lib/screens/escaner/consejos_escaner.dart`
- Modify: `lib/ui/recorrido/globos.dart`
- Modify: `test/support/montaje.dart`
- Test: `test/ui/boton_escanear_test.dart`, `test/providers/consejos_provider_test.dart`, `test/ui/recorrido/consejo_test.dart` (nuevos)

**Interfaces:**
- Produces:
  - `BotonEscanear({super.key, required VoidCallback? onPressed, String texto = 'Escanear código'})`: `FilledButton.tonalIcon` con `Icons.qr_code_scanner_rounded`, `minimumSize: Size.fromHeight(48)`, texto con `overflow: TextOverflow.ellipsis`.
  - `enum Consejo { escanearVenta, escanearProducto }`; `ConsejosVistos extends Notifier<Set<Consejo>>` lee la clave `'consejo_visto_${c.name}'` (bool) de `preferenciasProvider`; `Future<void> marcarVisto(Consejo c)`; `final consejosVistosProvider`.
  - `ControladorGlobos mostrarConsejo(BuildContext context, PasoGlobo paso)` en `globos.dart`: un solo paso; `CapaGlobos` recibe `esConsejo: true` → sin `boton_saltar_recorrido`, con `FilledButton` `'Entendido'` (key `boton_entendido_consejo`) que cierra; el velo deja pasar toques en el hueco.
  - `const consejoEscanearVenta = PasoGlobo(objetivos: ['boton_escanear_venta'], texto: 'Apunta la cámara al código de barras del producto para venderlo más rápido')` y `consejoEscanearProducto` (objetivo `'boton_escanear_producto'`, texto "...para crearlo sin escribir") en `consejos_escaner.dart`.
  - En `test/support/montaje.dart`: `const consejosVistos = {'consejo_visto_escanearVenta': true, 'consejo_visto_escanearProducto': true};` y `containerConSesion` lo siembra cuando no recibe `preferencias`.

- [ ] **Step 1: Pruebas que fallan.**
  - `boton_escanear_test`: muestra `'Escanear código'` y el ícono; alto ≥ 48; con `onPressed: null` no llama nada; con texto `'Crear escaneando'` lo muestra.
  - `consejos_provider_test`: con preferencias vacías el estado es `{}`; tras `marcarVisto(Consejo.escanearVenta)` el estado lo contiene y `prefs.getBool('consejo_visto_escanearVenta') == true`; un container nuevo con las mismas preferencias arranca con `{Consejo.escanearVenta}`.
  - `consejo_test`: montar un `ObjetivoRecorrido(id: 'boton_escanear_venta', child: ...)`, llamar `mostrarConsejo`, `pumpAndSettle`: texto del consejo visible, `boton_entendido_consejo` visible, `boton_saltar_recorrido` ausente; tocar "Entendido" → `capa_globos` desaparece y `ctrl.activo == false`.

- [ ] **Step 2:** correr las tres → fallan.

- [ ] **Step 3: Implementar** según Interfaces. `mostrarGlobos` y `CapaGlobos` conservan su comportamiento actual (`esConsejo` por defecto false).

- [ ] **Step 4:** pruebas nuevas + suite completa en verde; analyze limpio.

- [ ] **Step 5: Commit** `feat: add a labeled scan button and one-time tips`

### Task 3: Nueva venta con "Escanear código" y su consejo

**Files:**
- Modify: `lib/screens/venta/registrar_venta_screen.dart`
- Test: `test/screens/venta/escanear_venta_test.dart` (nuevo); ajustar pruebas existentes que usen preferencias propias (añadir `...consejosVistos`)

**Interfaces:**
- Consumes: `BotonEscanear`, `consejosVistosProvider`, `mostrarConsejo`, `consejoEscanearVenta`, `UsoEscaner` (Tareas 1–2).

- [ ] **Step 1: Pruebas que fallan** (`containerConSesion` con preferencias propias para controlar el consejo; `lectorCodigoProvider` con `LectorFalso`):
  - `'muestra Escanear código con texto, también al vendedor'`: con rol `'vendedor'`, `find.widgetWithText(BotonEscanear, 'Escanear código')` findsOneWidget, key `boton_escanear_venta`.
  - `'la primera vez muestra el consejo y lo recuerda'`: preferencias vacías → texto del consejo visible; `prefs.getBool('consejo_visto_escanearVenta') == true`; tocar "Entendido"; cerrar y reabrir la pantalla → el consejo no aparece.
  - `'tocar Escanear código cierra el consejo y escanea'`: con el consejo abierto, tocar el botón (en el hueco) → `capa_globos` ausente y `lector.usos == [UsoEscaner.venta]`.
  - `'salir con el consejo abierto lo quita'`: abierto el consejo, `navegador.currentState!.pop()` + `pumpAndSettle` → `capa_globos` findsNothing.
  - `'en la práctica hay botón de escanear, sin consejo, y usa UsoEscaner.practica'`: `RegistrarVentaScreen(practica: true, conGlobos: false)` con preferencias vacías → botón visible, consejo ausente; al tocarlo `lector.usos == [UsoEscaner.practica]`.

- [ ] **Step 2:** correr → fallan.

- [ ] **Step 3: Implementar.** Quitar el `IconButton` de escanear del `AppBar`. Poner `ObjetivoRecorrido(id: 'boton_escanear_venta', child: BotonEscanear(key: Key('boton_escanear_venta'), onPressed: _escanear))` fijo arriba del buscador (`EdgeInsets.fromLTRB(16, 12, 16, 0)`), también en práctica. `_escanear` cierra el consejo si está activo y llama `leer(context, uso: widget.practica ? UsoEscaner.practica : UsoEscaner.venta)`. En `initState` (post-frame), si `!widget.practica && !widget.dictarAlAbrir` y el consejo no está visto: `marcarVisto` y `_consejo = mostrarConsejo(context, consejoEscanearVenta)`. `dispose` llama `_consejo?.cerrar()`.

- [ ] **Step 4:** suite completa en verde (incluidas `practica_test`, `editar_desde_venta_test`, `registrar_venta_screen_test`); analyze limpio.

- [ ] **Step 5: Commit** `feat: show a labeled scan button and a first-time tip on new sale`

### Task 4: Crear/editar producto con "Escanear código" y su consejo

**Files:**
- Modify: `lib/screens/configuracion/producto_screen.dart` (botón en tarjeta DATOS, ~líneas 455–478; `_escanear` ~110)
- Test: `test/screens/configuracion/escanear_producto_test.dart` (nuevo)

**Interfaces:**
- Consumes: igual que Tarea 3 con `consejoEscanearProducto` y `UsoEscaner.producto`.

- [ ] **Step 1: Pruebas que fallan:**
  - `'crear producto muestra Escanear código bajo el campo de código'`: `find.widgetWithText(BotonEscanear, 'Escanear código')` con key `boton_escanear_producto`.
  - `'al crear, la primera vez muestra el consejo de crear'`: preferencias vacías, `ProductoScreen()` → texto "...para crearlo sin escribir" visible; `consejo_visto_escanearProducto == true`.
  - `'al editar no muestra el consejo'`: `ProductoScreen(producto: p)` con preferencias vacías → sin `capa_globos`.
  - `'escanear usa UsoEscaner.producto y llena el código'`: `LectorFalso(['7702004003508'])` → campo `campo_codigo_producto` con ese texto y `lector.usos == [UsoEscaner.producto]`.

- [ ] **Step 2:** correr → fallan.

- [ ] **Step 3: Implementar.** Reemplazar el `Row` campo+`IconButton` por el campo y debajo (`SizedBox(height: 8)`) `ObjetivoRecorrido(id: 'boton_escanear_producto', child: BotonEscanear(...))` (a ancho completo, para que quepa con letra "Muy grande"). Consejo solo si `widget.producto == null`, con el mismo manejo que la Tarea 3 (marcar al mostrar, cerrar al escanear y en `dispose`).

- [ ] **Step 4:** suite completa en verde; analyze limpio.

- [ ] **Step 5: Commit** `feat: show a labeled scan button and a first-time tip when creating a product`

### Task 5: Recorrido — "Crear escaneando" y "Vender escaneando"

**Files:**
- Modify: `lib/screens/venta/hoja_producto_rapido.dart`
- Modify: `lib/screens/recorrido/paso_productos_screen.dart`
- Modify: `lib/screens/recorrido/paso_venta_screen.dart`
- Modify: `lib/screens/venta/registrar_venta_screen.dart`
- Modify: `docs/hoja-de-ruta.md`, `README.md` (sección Usage/examples: escáner en el recorrido)
- Test: `test/screens/recorrido/paso_productos_screen_test.dart`, `test/screens/recorrido/practica_test.dart`, `test/screens/recorrido/paso_venta_screen_test.dart` (nuevo)

**Interfaces:**
- Produces:
  - `mostrarHojaProductoRapido(context, {required String codigo, String textoGuardar = 'Guardar y agregar'})`.
  - `RegistrarVentaScreen({..., this.escanearAlAbrir = false})`.
- Consumes: `BotonEscanear`, `UsoEscaner.primerosProductos`, `UsoEscaner.practica`, `LectorFalso.usos`.

- [ ] **Step 1: Pruebas que fallan.**
  - Paso productos (`consultaProductoProvider` falso que devuelve null, como en las pruebas existentes de la hoja rápida):
    - `'Crear escaneando crea el producto y lo lista'`: `LectorFalso(['123'])`; tocar `boton_crear_escaneando` (texto `'Crear escaneando'`), llenar `campo_nombre_rapido` 'Arroz' y `campo_precio_rapido` '3000', tocar `boton_guardar_producto_rapido` (texto `'Guardar'`) → `find.byKey(Key('escaneado_0'))` con texto que contiene 'Arroz'; en la base existe 'Arroz' con `codigoBarras == '123'`; `lector.usos == [UsoEscaner.primerosProductos]`.
    - `'código ya existente avisa y no abre la hoja'`: producto 'Pan' con código '123' → aviso `'Ese código ya es de Pan'`, `hoja_producto_rapido` findsNothing.
    - `'cancelar el escáner no cambia nada'`: `LectorFalso([null])` → sin hoja, sin filas `escaneado_`.
    - `'después de escanear, Guardar y continuar no duplica'`: tras crear 'Arroz' escaneando y escribir 'Arroz' en `fila_nombre_0` → `error_fila_0` 'Ya está en la lista'.
  - Paso venta:
    - `'ofrece Vender escaneando además de Empezar'`: `boton_vender_escaneando` con texto `'Vender escaneando'` y `boton_empezar_practica`.
  - Práctica (`practica_test.dart`, recorrido en `venta`):
    - `'Vender escaneando con código conocido suma y lleva a Cobrar'`: 'Pan' con código '111', `LectorFalso(['111'])`, `RegistrarVentaScreen(practica: true, escanearAlAbrir: true)` → ticket con 1 artículo; burbuja con 'Aquí ves el total. Toca Cobrar.'; `lector.usos == [UsoEscaner.practica]`.
    - `'sin cámara sigue la práctica normal'`: `LectorFalso([null])` → burbuja 'Toca un producto para sumarlo al ticket.'.
    - `'los globos no aparecen mientras el escáner está abierto'`: con un `LectorCodigo` falso que devuelve un `Completer<String?>().future` sin completar → tras `pump`, `capa_globos` findsNothing; al completar con null → aparece.
    - `'código desconocido crea un producto real y la venta sigue de práctica'`: `LectorFalso(['999'])` → `hoja_producto_rapido`; guardar 'Leche' 4000 → producto existe en la base; terminar la práctica con Efectivo → `db.ventas` vacío.

- [ ] **Step 2:** correr → fallan.

- [ ] **Step 3: Implementar.**
  - Hoja rápida: el botón usa `textoGuardar`.
  - Paso productos: `BotonEscanear(key: Key('boton_crear_escaneando'), texto: 'Crear escaneando')` entre la descripción y las filas, con la descripción ampliada: "Escríbelo o escanea su código." al final del texto actual. `_crearEscaneando()`: `leer(uso: primerosProductos)` → null: nada; `productoPorCodigo` existente → `avisar(context, 'Ese código ya es de ${p.nombre}', error: true)`; si no, hoja rápida con `textoGuardar: 'Guardar'` y, si devuelve producto, agregarlo a `_escaneados` (lista de `Producto`), mostrado como filas `Key('escaneado_$i')` con ícono de check, nombre y `formatoMoneda(precio)`.
  - Paso venta: debajo de "Empezar", `BotonEscanear(key: Key('boton_vender_escaneando'), texto: 'Vender escaneando')` que hace `pushReplacement` de `RegistrarVentaScreen(practica: true, escanearAlAbrir: true)`; "Omitir" se queda.
  - Venta: en `initState`, si `escanearAlAbrir`, en el post-frame primero `await _escanear()`; en la práctica con globos, mostrar los globos solo después y, si el ticket ya no está vacío, `_globos!.irA(1)`. Fuera de la práctica, `escanearAlAbrir` solo abre el escáner.
  - Docs: en `docs/hoja-de-ruta.md` marcar el escáner fácil y en el recorrido como hecho; README, una línea en Usage/examples.

- [ ] **Step 4:** suite completa en verde; `dart format` y `flutter analyze` limpios. Revisión WCAG de las vistas cambiadas (48 dp, contraste del texto blanco sobre `velo`, lector de pantalla lee "Escanear código", "Crear escaneando", "Vender escaneando", "Seguir sin cámara").

- [ ] **Step 5: Commit** `feat: teach scanning in the first-use tour`
