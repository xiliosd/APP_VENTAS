# Pedidos guardados y pedido recibido como gasto — Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Guardar el pedido sugerido como pedido por llegar, recibirlo días después comparando
pedido contra llegado, y registrar lo recibido como gasto de la caja.

**Architecture:** BD v9 con `Pedidos`/`LineasPedido` y `Gastos.entradaId`. Un `PedidoRepository`
nuevo maneja el ciclo del pedido; `InventarioRepository.recibirMercancia` crea en la misma
transacción la entrada, el gasto enlazado y el cierre del pedido; `anularEntrada` lo revierte.
Las etiquetas de diferencia salen de una función pura compartida por la recepción y el detalle.

**Tech Stack:** Flutter, Drift 2.34 (`build_runner`), Riverpod 2.6, SharedPreferences.

**Spec:** `docs/superpowers/specs/2026-10-16-vecitienda-pedido-como-gasto-design.md`

## Global Constraints

- Rama `feature/pedido-como-gasto` desde `master`; Conventional Commits con
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`; sin push ni merge sin autorización.
- Sin dependencias nuevas.
- Textos exactos: botón "Guardar pedido"; sección "Por llegar"; botón "Llegó este pedido";
  interruptor "Lo pagué de la caja (efectivo)" con "Se registra gasto Mercancía · <proveedor> por
  $ X"; gasto con descripción `aplicarCategoria(proveedor.nombre, 'Mercancía')`; etiquetas
  "Completo", "Faltan N", "No llegó", "Llegaron N de más", "Extra", "Ya pedido · llegan N";
  bloqueo "Viene de la mercancía recibida; para cambiarlo anula la entrada"; aviso de una vez
  "Ya no registres la mercancía como gasto a mano; se anota sola"; pregunta "¿Llegó alguno de
  estos pedidos?" con "No, es otra mercancía".
- Interruptor encendido por defecto, siempre.
- Permisos: anular entrada con gasto → `puedeCorregir`; editar/anular pedido → autor o admin.
- Accesibilidad: `Semantics`/`tooltip` en etiquetas e interruptor, contraste ≥ 4,5:1, modo
  oscuro y letra 2,0×.
- `dart format` + `flutter analyze` limpios; `flutter test` completo en verde al final de cada
  tarea; cobertura de lo nuevo ≥ 80 % en repositorios (dinero).

## Review Focus

1. Recibir contra un pedido que otro celular o toque ya recibió o anuló → error claro, sin
   entrada ni gasto duplicados (prueba en Tarea 3).
2. Anular dos veces la misma entrada con gasto → el gasto no se anula dos veces ni se registran
   dos correcciones (Tarea 3).
3. Producto del pedido desactivado antes de que llegue → el pedido se sigue mostrando y
   recibiendo (Tarea 2: `detallePedido` no filtra por `activo`).
4. Recibir un pedido de un proveedor que luego se desactivó → hoy `recibirMercancia` lo
   rechaza; se mantiene y la tarjeta lo dice: "Proveedor inactivo: actívalo para recibir"
   (Tarea 6).
5. Línea del pedido sin precio esperado → la recepción exige precio antes de guardar, como hoy
   (Tarea 7).

---

### Task 1: BD v9

**Files:**
- Modify: `lib/data/inventario.dart` (enum), `lib/data/database.dart` (tablas, versión 9,
  migración), `lib/data/database.g.dart` (generado)
- Test: `test/data/migracion_test.dart`, `test/data/database_test.dart`

**Interfaces:**
- Produces: `enum EstadoPedido { porLlegar, recibido, anulado }`; tabla `Pedidos`
  (`@DataClassName('Pedido')`: id, proveedorId → Proveedores, usuarioId → Usuarios, fecha,
  `estado` textEnum<EstadoPedido> con default `porLlegar`, `entradaId` nullable →
  EntradasMercancia); tabla `LineasPedido` (`@DataClassName('LineaPedido')`: id, pedidoId →
  Pedidos, productoId → Productos, cantidad, `precioEsperado` nullable); `Gastos.entradaId`
  nullable → EntradasMercancia.

- [ ] **Step 1:** Pruebas nuevas, con el mismo patrón que `'una base v7 abre en v8 sin código ni
  detalles'`: `'una base v8 abre en v9 sin pedidos y con gastos sin entrada'` (crear v8, insertar
  un gasto, abrir: `pedidos` vacía, el gasto conserva monto y `entradaId == null`) y
  `'una base v1 abre en v9 y guarda pedidos'` (insertar pedido con una línea y un gasto con
  `entradaId`; leerlos de vuelta, estado por defecto `porLlegar`).
- [ ] **Step 2:** `flutter test test/data/migracion_test.dart` → FALLA (tablas inexistentes).
- [ ] **Step 3:** Agregar enum y tablas, registrar en `@DriftDatabase`, `schemaVersion => 9`,
  bloque `if (desde < 9) { createTable(pedidos); createTable(lineasPedido);
  addColumn(gastos, gastos.entradaId); }`. Generar con
  `dart run build_runner build --delete-conflicting-outputs`.
- [ ] **Step 4:** `flutter test test/data` → PASA; `flutter analyze` limpio.
- [ ] **Step 5:** Commit `feat: add orders tables and link expenses to stock entries (db v9)`.

### Task 2: PedidoRepository

**Files:**
- Create: `lib/repositories/pedido_repository.dart`
- Modify: `lib/providers/repository_providers.dart`, `lib/providers/inventario_providers.dart`
- Test: `test/repositories/pedido_repository_test.dart`

**Interfaces:**
- Consumes: tablas de la Tarea 1; `PermisoDenegado` de `correccion_repository.dart`.
- Produces:
  - `class LineaPedidoNueva { productoId; cantidad; int? precioEsperado }`
  - `class PedidoResumen { Pedido pedido; Proveedor proveedor; String usuario; int productos;
    int totalEstimado }` (total = Σ cantidad × precioEsperado, nulos cuentan 0)
  - `class LineaPedidoDetalle { LineaPedido linea; Producto producto }`
  - `PedidoRepository(AppDatabase db, {DateTime Function()? reloj})` con:
    `Future<int> guardarPedido({required int proveedorId, required List<LineaPedidoNueva> lineas,
    required Usuario por})`; `Future<void> editarPedido(int pedidoId, List<LineaPedidoNueva>
    lineas, {required Usuario por})` (reemplaza todas las líneas); `Future<void>
    anularPedido(int pedidoId, {required Usuario por})`; `Future<List<PedidoResumen>>
    pedidosPorLlegar({int? proveedorId})` (más viejo primero); `Future<({PedidoResumen resumen,
    List<LineaPedidoDetalle> lineas})> detallePedido(int pedidoId)`.
  - Función de nivel superior `Future<Map<int, int>> cantidadesPorLlegar(AppDatabase db)`:
    productoId → Σ cantidad en pedidos `porLlegar`.
  - Providers: `pedidoRepositoryProvider`, `pedidosPorLlegarProvider`
    (FutureProvider, escucha `_cambiosInventarioProvider`), `detallePedidoProvider`
    (autoDispose.family<…, int>).

- [ ] **Step 1:** Pruebas: guardar valida (sin líneas → `ArgumentError`; cantidad ≤ 0 →
  `ArgumentError`; producto repetido → `ArgumentError`; proveedor inactivo → `ArgumentError`);
  guarda fecha del reloj, usuario y estado `porLlegar`; `pedidosPorLlegar` excluye recibidos y
  anulados y filtra por proveedor; total estimado con un precio nulo; editar reemplaza líneas;
  editar o anular un pedido no `porLlegar` → `ArgumentError('El pedido ya no está por
  llegar')`; vendedor que no es autor → `PermisoDenegado`, admin sí puede;
  `cantidadesPorLlegar` suma dos pedidos del mismo producto e ignora anulados;
  `detallePedido` muestra un producto desactivado.
- [ ] **Step 2:** `flutter test test/repositories/pedido_repository_test.dart` → FALLA.
- [ ] **Step 3:** Implementar; cada escritura en `_db.transaction`.
- [ ] **Step 4:** Pruebas → PASAN; `flutter analyze` limpio.
- [ ] **Step 5:** Commit `feat: save, edit and cancel pending supplier orders`.

### Task 3: Recibir con gasto y anular entrada

**Files:**
- Modify: `lib/repositories/inventario_repository.dart` (`recibirMercancia`, `anularEntrada`,
  `detalleEntrada`), `lib/repositories/correccion_repository.dart`,
  `lib/providers/inventario_providers.dart` (tipo de `detalleEntradaProvider`)
- Test: `test/repositories/inventario_entradas_test.dart`, `test/repositories/pedido_recepcion_test.dart`
  (nuevo), `test/repositories/correccion_repository_test.dart`

**Interfaces:**
- Consumes: Tareas 1–2.
- Produces:
  - `recibirMercancia({required int proveedorId, required List<LineaRecibida> lineas, String?
    nota, required Usuario por, int? pedidoId, bool pagadoDeCaja = true})` → id de la entrada.
  - `detalleEntrada` añade al registro: `Gasto? gasto` y `List<LineaPedidoDetalle>?
    lineasPedido` (null si no vino de pedido).
  - `CorreccionRepository.anularGastoDeEntrada(int gastoId, {required Usuario por})`: anula y
    registra la corrección sin la regla de "gasto enlazado" (solo la llama `anularEntrada`).

- [ ] **Step 1:** Pruebas:
  - con `pagadoDeCaja` por defecto se crea un gasto con monto = total, descripción
    `'Mercancía · Postobón'`, fecha del reloj, `usuarioId` y `entradaId`; con `false` no hay gasto;
  - con `pedidoId`: el pedido queda `recibido` con `entradaId`; pedido de otro proveedor →
    `ArgumentError`; pedido ya `recibido` o `anulado` → `ArgumentError` y sin entrada ni gasto
    nuevos (Review Focus 1);
  - `anularEntrada` anula el gasto, registra una corrección `anulado` de tipo gasto y devuelve el
    pedido a `porLlegar` con `entradaId` null; segunda anulación → `ArgumentError` sin segunda
    corrección (Review Focus 2);
  - `anularEntrada` con gasto por un vendedor de otro día o de otro usuario → `PermisoDenegado`;
    sin gasto, sigue permitido como hoy;
  - `corregirGasto` y `anularGasto` sobre un gasto con `entradaId` → `CorreccionInvalida('Viene
    de la mercancía recibida; para cambiarlo anula la entrada')`;
  - `detalleEntrada` devuelve gasto y líneas del pedido.
- [ ] **Step 2:** Correr esos archivos → FALLAN.
- [ ] **Step 3:** Implementar; todo en la transacción existente. `anularEntrada` comprueba
  permisos con `puedeCorregir` (dueño = usuario de la entrada) antes de escribir.
- [ ] **Step 4:** Pruebas → PASAN; también `test/repositories` completo (reportes y resumen
  ahora ven el gasto: ajustar solo las pruebas que creaban entradas y sumaban gastos).
- [ ] **Step 5:** Commit `feat: record received stock as a cash expense and revert it on cancel`.

### Task 4: Sugerencia con lo que está por llegar

**Files:**
- Modify: `lib/repositories/inventario_repository.dart` (`ProductoPorPedir`, `LineaSugerida`,
  `porPedir`, `sugerenciaPedido`)
- Test: `test/repositories/pedido_sugerido_test.dart`, `test/repositories/inventario_por_pedir_test.dart`

**Interfaces:**
- Consumes: `cantidadesPorLlegar` (Tarea 2).
- Produces: `ProductoPorPedir.porLlegar` (int, 0 por defecto); `LineaSugerida.porLlegar` (int);
  `sugerido = (pedirHasta ?? 2 × minimo) − existencias − porLlegar`, y la línea se omite si
  `sugerido ≤ 0` (ya no hay `clamp(1, …)` cuando hay algo por llegar; sin nada por llegar sigue
  el mínimo de 1).

- [ ] **Step 1:** Pruebas: Coca (quedan 2, hasta 24) con 10 por llegar → sugerido 12 y
  `porLlegar` 10; con 22 por llegar → no está en la sugerencia pero sí en `porPedir` con
  `porLlegar` 22; dos pedidos (8 + 6) suman 14; pedido anulado no cuenta; tras recibir 10 de 22
  pedidos (existencias 12, mín. 6) el producto ya no está en `porPedir` (decisión del usuario).
- [ ] **Step 2:** → FALLAN. **Step 3:** Implementar. **Step 4:** → PASAN.
- [ ] **Step 5:** Commit `feat: discount pending orders from the suggested order`.

### Task 5: Guardar pedido desde Pedido sugerido

**Files:**
- Modify: `lib/screens/inventario/pedido_sugerido_screen.dart`, `lib/screens/inventario/inventario_screen.dart`
  (`_verPedido` y lista "Por pedir")
- Test: `test/screens/inventario/pedido_sugerido_screen_test.dart`, `test/screens/inventario/inventario_screen_test.dart`

**Interfaces:**
- Consumes: `PedidoRepository.guardarPedido`, `LineaSugerida.porLlegar`, `ProductoPorPedir.porLlegar`.
- Produces: `PedidoSugeridoScreen` hace `pop(true)` al guardar; Inventario avisa "Pedido guardado".

- [ ] **Step 1:** Pruebas de pantalla: el botón `boton_guardar_pedido` dice "Guardar pedido"
  (ya no existe `boton_recibir_pedido`); al tocarlo se guarda un pedido con las cantidades
  editadas (sin las líneas en 0) y vuelve a Inventario con el aviso; en "Sin proveedor" aparecen
  chips `opcion_proveedor_pedido_<id>` y el botón está deshabilitado hasta elegir uno; la línea
  con `porLlegar > 0` muestra "llegan N"; en "Por pedir" un producto excluido de la sugerencia
  muestra la etiqueta "Ya pedido · llegan N" (`ya_pedido_<id>`).
- [ ] **Step 2:** → FALLAN. **Step 3:** Implementar (quitar `_recibir`; reutilizar el patrón de
  chips de proveedor de Recibir). **Step 4:** → PASAN.
- [ ] **Step 5:** Commit `feat: save the suggested order instead of receiving it at once`.

### Task 6: Por llegar en Inventario y pantalla del pedido

**Files:**
- Create: `lib/screens/inventario/pedido_por_llegar_screen.dart`
- Modify: `lib/screens/inventario/inventario_screen.dart`
- Test: `test/screens/inventario/pedido_por_llegar_screen_test.dart`, `test/screens/inventario/inventario_screen_test.dart`

**Interfaces:**
- Consumes: `pedidosPorLlegarProvider`, `detallePedidoProvider`, `editarPedido`, `anularPedido`.
- Produces: `PedidoPorLlegarScreen({required int pedidoId})`; navega a
  `RecibirMercanciaScreen(pedidoId: …)` (Tarea 7).

- [ ] **Step 1:** Pruebas: con un pedido por llegar aparece `TituloSeccion('POR LLEGAR')` y la
  tarjeta `pedido_por_llegar_<id>` con proveedor, "pedido el <día>", productos y total estimado,
  y el botón `llego_pedido_<id>`; sin pedidos la sección no aparece; la pantalla del pedido
  permite sumar/restar/quitar/agregar y "Guardar cambios"; "Anular pedido" pide confirmación y
  luego desaparece de Por llegar; a un vendedor que no es autor no se le muestran editar ni
  anular; proveedor inactivo → la tarjeta dice "Proveedor inactivo: actívalo para recibir" y
  el botón está deshabilitado (Review Focus 4).
- [ ] **Step 2:** → FALLAN. **Step 3:** Implementar con el estilo R4 (tarjetas, `BarraAccionFija`).
  **Step 4:** → PASAN.
- [ ] **Step 5:** Commit `feat: list pending orders in inventory and let them be edited or cancelled`.

### Task 7: Recibir contra el pedido

**Files:**
- Create: `lib/util/diferencia_pedido.dart`
- Modify: `lib/screens/inventario/recibir_mercancia_screen.dart`
- Test: `test/util/diferencia_pedido_test.dart`, `test/screens/inventario/recibir_mercancia_screen_test.dart`

**Interfaces:**
- Consumes: `detallePedido`, `pedidosPorLlegar(proveedorId:)`, `recibirMercancia(pedidoId:,
  pagadoDeCaja:)`, `preferenciasProvider`.
- Produces:
  - `enum EstadoLineaPedido { completo, faltan, noLlego, deMas, extra }`
  - `EstadoLineaPedido estadoLineaPedido({int? pedido, required int llego})` (`pedido` null →
    `extra`)
  - `String textoEstadoLinea(EstadoLineaPedido estado, {int? pedido, required int llego})` →
    "Completo" / "Faltan N" / "No llegó" / "Llegaron N de más" / "Extra"
  - `RecibirMercanciaScreen({…, int? pedidoId})`; con `pedidoId` carga proveedor y líneas.

- [ ] **Step 1:** Pruebas puras de las cinco etiquetas y textos (24/24, 6/12, 0/12, 14/12,
  null/6). Pruebas de pantalla: con pedido, cada línea muestra "pedido N · llegó M" y su etiqueta,
  la cantidad baja hasta 0 en líneas del pedido (en extras el mínimo sigue en 1); precio distinto
  del esperado muestra "$ 2.500 → $ 2.700"; el resumen `resumen_recepcion` muestra total pedido,
  total que llegó y el conteo; el interruptor `interruptor_caja` arranca encendido con el texto del
  gasto; guardar envía solo las líneas con cantidad > 0, `pedidoId` y `pagadoDeCaja`; todo en 0 →
  Guardar deshabilitado y botón "Anular pedido"; línea sin precio → Guardar deshabilitado (Review
  Focus 5); aviso de una vez tras el primer guardado con interruptor encendido (clave
  `aviso_mercancia_gasto` en preferencias), no reaparece; sin pedido, al elegir un proveedor con
  pedidos por llegar sale la hoja "¿Llegó alguno de estos pedidos?": elegir uno carga sus líneas,
  "No, es otra mercancía" sigue como hoy.
- [ ] **Step 2:** → FALLAN. **Step 3:** Implementar; `_Linea` gana `int? pedido` y
  `int? precioEsperado`. **Step 4:** → PASAN.
- [ ] **Step 5:** Commit `feat: compare received stock against the order and pay it from the cash box`.

### Task 8: Detalle de entrada, gasto bloqueado, accesibilidad y documentos

**Files:**
- Modify: `lib/screens/inventario/detalle_entrada_screen.dart`, `lib/repositories/historial_repository.dart`
  (`MovimientoHistorial.entradaId`), `lib/screens/correccion/hoja_movimiento.dart`
  (`MovimientoEditable.entradaId`), `docs/hoja-de-ruta.md`, `README.md` si lista funciones
- Test: `test/screens/inventario/detalle_inventario_screen_test.dart` o nuevo
  `detalle_entrada_screen_test.dart`, `test/screens/correccion/hoja_movimiento_test.dart`,
  `test/screens/administracion_oscuro_test.dart`

**Interfaces:**
- Consumes: `detalleEntrada` (Tarea 3), `estadoLineaPedido`/`textoEstadoLinea` (Tarea 7).

- [ ] **Step 1:** Pruebas: el detalle de una entrada con pedido lista pedido vs llegó con
  etiquetas (incluido "No llegó") y muestra "Gasto Mercancía · Postobón $ X" (tachado si se
  anuló); el diálogo de anular dice además "También se anula el gasto de $ X"; la hoja de un
  gasto con `entradaId` no muestra corregir ni anular y muestra el texto de bloqueo; modo oscuro
  y letra 2,0× sin desbordes en Recibir con pedido, pantalla del pedido y detalle.
- [ ] **Step 2:** → FALLAN. **Step 3:** Implementar. **Step 4:** `flutter test` completo y
  `flutter analyze` → limpios.
- [ ] **Step 5:** Mover la mejora 1 a "Hecho" en `docs/hoja-de-ruta.md` y a "Pendiente de
  verificar" el recorrido en celular; `flutter build apk --release`.
- [ ] **Step 6:** Commit `feat: show order differences and the linked expense on stock entries`.
