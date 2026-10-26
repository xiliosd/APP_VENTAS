# Mejoras de tienda — Tanda 1 (clientes, cliente habitual y reportes) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Clientes con nombre y apellido y aviso de parecidos, pantalla "Clientes" para todos los
usuarios, cliente habitual opcional en ventas de contado y reportes de "¿A quién le vendo?" y
"Mejores clientes".

**Architecture:** Drift v10 agrega `clientes.apellido`. `ClienteRepository` concentra crear,
editar, buscar parecidos y compras. Un formulario de cliente reutilizable (con la hoja de
parecido) alimenta `SelectorCliente`, que sirve para fiado, contado y corrección. `Ventas.clienteId`
(ya existe) guarda el cliente habitual en ventas de contado; `ReporteRepository` lo agrega.

**Tech Stack:** Flutter, Riverpod, Drift (SQLite), flutter_test. Sin dependencias nuevas.

**Spec:** `docs/superpowers/specs/2026-10-26-vecitienda-mejoras-tienda-design.md` (secciones 1 y 3).

## Global Constraints

- Lineamientos UNIMINUTO v1.2; nombres en español como el resto del código; archivos en
  `snake_case` (excepción de Dart ya documentada en el README).
- `dart format` y `flutter analyze` sin hallazgos; todas las pruebas en verde en cada commit.
- Cobertura ≥ 80 % en `cliente_repository.dart` y el formulario de cliente (datos personales).
- Nombre y teléfono de clientes nunca en logs, `print` ni mensajes de error técnicos.
- WCAG 2.1 AA en vistas nuevas: `tooltip`/`Semantics` en botones de ícono, objetivos táctiles
  ≥ 48 dp, sin desborde a 2,0× de letra en 360 dp de ancho.
- La venta de contado se cierra con los mismos toques de hoy si nadie elige cliente.
- El aviso de parecido **nunca bloquea**: el vendedor elige "Usar este cliente" o "Crear otro de
  todas formas".
- Admin y vendedor pueden crear y editar clientes.
- Textos fijos: "Ya existe un cliente parecido", "Usar este cliente", "Crear otro de todas
  formas", "Falta apellido", "¿Quién compra?", "De paso", "¿A quién le vendo?",
  "Clientes habituales", "De paso o sin marcar", "Mejores clientes".
- Commits Conventional Commits con `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
  No fusionar ni subir sin autorización del usuario.

## Review Focus

1. Cliente antiguo guardado como `nombre: 'Juan Pérez', apellido: null` frente a uno nuevo
   `Juan` + `Pérez`: debe avisar como parecido (se compara el nombre completo). Test en Task 2.
2. Teléfono escrito con espacios o con `+57` ("300 123 4567", "+57 3001234567") se guarda como
   `3001234567` y se compara así. Test en Task 2.
3. "Deshacer" de una venta de contado con cliente nuevo: la venta desaparece, el cliente queda
   (es correcto y no rompe nada); el ticket no debe volver a crear el cliente si se cobra de
   nuevo. Test en Task 5.
4. Corregir una venta fiada a contado conserva el cliente; corregir solo el cliente de una venta
   de contado cuenta como cambio y queda en `correcciones`. Test en Task 6.
5. Ventas anuladas y abonos no suman en "Mejores clientes"; un cliente solo con fiado sí aparece.
   Test en Task 8.

---

### Task 1: Base de datos v10 y nombre visible del cliente

**Files:**
- Modify: `lib/data/database.dart` (tabla `Clientes`, `schemaVersion`, `onUpgrade`)
- Regenerate: `lib/data/database.g.dart` (`dart run build_runner build --delete-conflicting-outputs`)
- Create: `lib/util/nombre_cliente.dart`
- Create: `test/support/esquema_v9.dart`
- Modify: `test/data/migracion_test.dart` (incluida la línea `expect(db.schemaVersion, 9)` → 10)
- Modify (mostrar nombre completo): `lib/screens/fiado/lista_fiado_screen.dart`,
  `lib/screens/fiado/detalle_cliente_screen.dart`, `lib/repositories/fiado_repository.dart:130`,
  `lib/repositories/cliente_repository.dart` (`nombresPorId`),
  `lib/repositories/correccion_repository.dart` (`_antesVenta`), `lib/widgets/selector_cliente.dart`
- Test: `test/util/nombre_cliente_test.dart`

**Interfaces:**
- Produces: columna `Clientes.apellido` (`TextColumn`, nullable); en `lib/util/nombre_cliente.dart`:
  - `extension NombreCliente on Cliente { String get nombreCompleto; }` — `"nombre apellido"`
    recortado; solo `nombre` si `apellido` es null o vacío.
  - `String claveCliente(String nombreCompleto)` — `sinTildes(claveNombre(x))` (de
    `util/texto_util.dart`), para comparar y buscar.
  - `String? telefonoNormalizado(String? texto)` — solo dígitos; quita un `57` inicial si quedan
    12 dígitos; devuelve null si queda vacío; devuelve los dígitos tal cual en otro caso (la
    validación de formato es del formulario).

- [ ] **Step 1: Write failing tests**

`test/util/nombre_cliente_test.dart`:
```dart
test('nombreCompleto une nombre y apellido', ...);   // 'Juan' + 'Pérez' → 'Juan Pérez'
test('nombreCompleto sin apellido es el nombre', ...); // apellido null y '' → 'Don Pedro'
test('claveCliente ignora mayúsculas, tildes y espacios', () {
  expect(claveCliente('  José   PÉREZ '), claveCliente('jose perez'));
});
test('telefonoNormalizado', () {
  expect(telefonoNormalizado('300 123 4567'), '3001234567');
  expect(telefonoNormalizado('+57 300-123-4567'), '3001234567');
  expect(telefonoNormalizado('  '), isNull);
  expect(telefonoNormalizado(null), isNull);
});
```
`test/data/migracion_test.dart`:
```dart
test('una base v9 abre en v10 con clientes sin apellido', () async {
  // crearBaseV9 (trae el cliente de v1); al abrir: nombre intacto, apellido null
});
test('una base v1 abre en v10 y guarda apellido', ...);
```
`test/support/esquema_v9.dart`: `void crearBaseV9(String ruta)` = `crearBaseV8` + SQL de
`pedidos`, `lineas_pedido` y `ALTER TABLE gastos ADD COLUMN entrada_id INTEGER NULL ...`,
`userVersion = 9` (copiar las sentencias del `CREATE TABLE` que genera drift en
`database.g.dart` para esas tablas).

- [ ] **Step 2: Run** `flutter test test/util/nombre_cliente_test.dart test/data/migracion_test.dart` — Expected: FAIL (archivo y columna no existen).

- [ ] **Step 3: Implement** columna, `schemaVersion => 10`, `if (desde < 10) await m.addColumn(clientes, clientes.apellido);`, regenerar, `nombre_cliente.dart`, y reemplazar cada `cliente.nombre` / `c.nombre` de clientes mostrado al usuario o usado para ordenar/buscar por `nombreCompleto` (buscar en Fiado con `claveCliente`). `nombresPorId` devuelve `nombreCompleto`.

- [ ] **Step 4: Run** `flutter test` (toda la suite) — Expected: PASS.

- [ ] **Step 5: Commit** `feat: store client last names (schema v10) and show full names`

---

### Task 2: Repositorio de clientes: crear, editar, parecidos y compras

**Files:**
- Modify: `lib/repositories/cliente_repository.dart`
- Test: `test/repositories/cliente_repository_test.dart` (reescribir los tests de `obtenerOCrearCliente`)

**Interfaces:**
- Consumes: Task 1 (`apellido`, `claveCliente`, `telefonoNormalizado`, `nombreCompleto`).
- Produces (en `ClienteRepository`):
  - `Future<int> crearCliente({required String nombre, required String apellido, String? telefono, String? notas})` — recorta; `ArgumentError('Escribe el nombre')` / `ArgumentError('Escribe el apellido')` si vacíos; guarda `telefonoNormalizado`; notas vacías → null. **No** revisa parecidos (eso lo hace la interfaz).
  - `Future<void> actualizarCliente(int id, {required String nombre, required String apellido, String? telefono, String? notas})` — mismas reglas.
  - `Future<List<Cliente>> clientesParecidos({required String nombre, required String apellido, String? telefono, int? salvo})` — clientes cuyo `claveCliente(nombreCompleto)` es igual al del nombre+apellido dado, **o** cuyo teléfono normalizado es igual al dado (si hay); excluye `salvo`; orden A–Z por `claveCliente`.
  - `Future<List<Venta>> comprasCliente(int clienteId)` — ventas no anuladas del cliente (contado y fiado), más recientes primero.
  - `obtenerOCrearCliente` se queda por ahora (lo usan el cobro y la corrección); Task 6 lo
    elimina cuando ya no tiene llamadas.

- [ ] **Step 1: Write failing tests**
```dart
test('crearCliente guarda nombre, apellido y teléfono normalizado', ...); // '300 123 4567' → '3001234567'
test('crearCliente exige nombre y apellido', () {
  expect(() => repo.crearCliente(nombre: 'Juan', apellido: '  '), throwsArgumentError);
});
test('clientesParecidos encuentra el mismo nombre completo sin tildes ni mayúsculas', ...);
test('clientesParecidos encuentra un cliente antiguo sin apellido con el nombre completo', () async {
  final viejo = await db.into(db.clientes).insert(ClientesCompanion.insert(nombre: 'Juan Pérez'));
  expect((await repo.clientesParecidos(nombre: 'juan', apellido: 'perez')).single.id, viejo);
});
test('clientesParecidos encuentra el mismo teléfono con otro nombre', ...);
test('clientesParecidos excluye al cliente que se edita (salvo)', ...);
test('clientesParecidos sin coincidencias devuelve vacío', ...);
test('actualizarCliente cambia datos y exige apellido', ...);
test('comprasCliente trae contado y fiado sin anuladas, recientes primero', ...);
```

- [ ] **Step 2: Run** `flutter test test/repositories/cliente_repository_test.dart` — Expected: FAIL.
- [ ] **Step 3: Implement** los métodos con las firmas de arriba (filtrado en Dart sobre `listarClientes()`, como hoy).
- [ ] **Step 4: Run** `flutter test` — Expected: PASS.
- [ ] **Step 5: Commit** `feat: create, edit and find similar clients by full name or phone`

---

### Task 3: Formulario de cliente y hoja de parecido

**Files:**
- Create: `lib/widgets/formulario_cliente.dart`
- Modify: `lib/providers/ticket_provider.dart` (`ClienteTicket`)
- Test: `test/widgets/formulario_cliente_test.dart`

**Interfaces:**
- Consumes: Task 2.
- Produces:
  - `ClienteTicket` pasa a `const ClienteTicket({this.id, required this.nombre, this.apellido = '', this.telefono})`, con `String get nombreCompleto`. `id` null = cliente nuevo por crear al cobrar con esos datos.
  - `Future<ClienteTicket?> pedirClienteNuevo(BuildContext context, {String textoInicial = ''})` — hoja inferior "Nuevo cliente" con campos Nombre, Apellido (ambos obligatorios, `TextCapitalization.words`) y Teléfono (opcional; si se escribe, `telefonoE164` de `respaldo/telefono.dart` debe aceptarlo tras normalizar, si no: "Escribe un celular de 10 dígitos"). `textoInicial` se reparte: primera palabra → Nombre, resto → Apellido. Al tocar "Continuar" llama `clientesParecidos`; sin parecidos devuelve `ClienteTicket(id: null, ...)`; con parecidos abre la hoja de parecido. **No guarda nada.**
  - `Future<bool> editarCliente(BuildContext context, Cliente cliente)` — mismo formulario con datos y Notas; parecidos con `salvo: cliente.id`; "Usar este cliente" no aplica al editar, así que la hoja muestra "Guardar de todas formas" y "Volver"; guarda con `actualizarCliente`; true si guardó.
  - `Future<int?> crearClienteDesdeFormulario(BuildContext context)` — para la pantalla Clientes: `pedirClienteNuevo` y, si devuelve uno nuevo, `crearCliente`; si eligió uno existente, devuelve su id sin crear.
  - Hoja de parecido (privada): título "Ya existe un cliente parecido"; por cada parecido: nombre completo, teléfono (o "Sin teléfono") y deuda (`saldoCliente`, "Al día" si 0); botones "Usar este cliente" (uno por parecido, `Key('usar_cliente_<id>')`) y "Crear otro de todas formas" (`Key('crear_otro_cliente')`).

- [ ] **Step 1: Write failing widget tests** (con `test/support/montaje.dart`)
```dart
testWidgets('exige nombre y apellido', ...);           // Continuar sin apellido → 'Escribe el apellido'
testWidgets('reparte el texto inicial en nombre y apellido', ...); // 'juan carlos pérez' → 'juan' | 'carlos pérez'
testWidgets('sin parecidos devuelve un cliente nuevo sin guardarlo', ...); // listarClientes sigue vacío
testWidgets('con un parecido avisa y "Usar este cliente" devuelve su id', ...);
testWidgets('"Crear otro de todas formas" devuelve un cliente nuevo', ...);
testWidgets('teléfono repetido avisa aunque el nombre sea distinto', ...);
testWidgets('teléfono inválido muestra el error', ...); // '12345'
testWidgets('editarCliente guarda el apellido de un cliente antiguo', ...);
```
- [ ] **Step 2: Run** `flutter test test/widgets/formulario_cliente_test.dart` — Expected: FAIL.
- [ ] **Step 3: Implement** con `mostrarHojaInferior` y `BotonPrincipal`, como `_FormularioProveedor`.
- [ ] **Step 4: Run** — Expected: PASS.
- [ ] **Step 5: Commit** `feat: client form with similar-client warning`

---

### Task 4: Selector de cliente con el formulario

**Files:**
- Modify: `lib/widgets/selector_cliente.dart`
- Modify: `lib/providers/ticket_provider.dart` (quitar `nombreEscrito` y `escribirCliente`; `clienteParaCobrar` = `cliente`)
- Modify: `lib/screens/venta/hoja_como_paga.dart` (dejar de pasar `onEscribir`)
- Test: `test/widgets/selector_cliente_test.dart` (crear), `test/providers/ticket_provider_test.dart`

**Interfaces:**
- Consumes: Task 3 (`pedirClienteNuevo`, `ClienteTicket`).
- Produces: `SelectorCliente({required ClienteTicket? elegido, required ValueChanged<ClienteTicket?> onElegir, String etiqueta = '¿A quién le fías?', bool exigir = false})` — sin `onEscribir`. Sugerencias buscan con `claveCliente` sobre `nombreCompleto` y teléfono. El chip "Nuevo: texto" (y ahora también si hay coincidencia exacta, como "Nuevo cliente") abre `pedirClienteNuevo(textoInicial: texto)` y pasa el resultado a `onElegir`. El chip del elegido muestra `nombreCompleto`.

Fiar ya no funciona con solo escribir: hay que tocar una sugerencia o crear el cliente. Eso es lo que exige el spec (nombre y apellido).

- [ ] **Step 1: Write failing tests**
```dart
testWidgets('buscar por apellido sugiere al cliente', ...);
testWidgets('buscar por teléfono sugiere al cliente', ...);
testWidgets('"Nuevo" abre el formulario con el texto y elige el resultado', ...);
test('el ticket fiado no puede cobrar solo con texto escrito', ...); // puedeCobrar false sin cliente
```
- [ ] **Step 2: Run** los tests — Expected: FAIL.
- [ ] **Step 3: Implement.** Actualiza los tests existentes que usaban `escribirCliente` / `campo_cliente` + Fiar directo para tocar "Nuevo" y llenar el formulario.
- [ ] **Step 4: Run** `flutter test` — Expected: PASS.
- [ ] **Step 5: Commit** `feat: pick or create clients with first and last name in the selector`

---

### Task 5: Cliente habitual en la venta de contado

**Files:**
- Modify: `lib/providers/ticket_provider.dart` (`cambiarFiado` conserva `cliente`)
- Modify: `lib/screens/venta/hoja_como_paga.dart`
- Modify: `lib/screens/venta/registrar_venta_screen.dart` (`_cobrar`, hoy líneas 369–415)
- Test: `test/screens/venta/` (archivo nuevo `cliente_habitual_test.dart`), `test/providers/ticket_provider_test.dart`

**Interfaces:**
- Consumes: Tasks 3–4.
- Produces: venta de contado registrada con `clienteId` del cliente elegido (o null = de paso).

Comportamiento:
- Hoja "¿Cómo paga?" sin Fiado elegido: encima de Efectivo, una fila compacta `Key('quien_compra')`: "¿Quién compra? **De paso**" con botón "Elegir cliente"; al tocarla se despliega `SelectorCliente(etiqueta: '¿Quién compra?')`. Con cliente elegido, la fila muestra su chip (quitable). Efectivo y Transferencia siguen siendo un toque.
- `cambiarFiado(false)` ya no borra `cliente`. Cerrar la hoja sin elegir forma deja el cliente en el ticket.
- `_cobrar`: si `ticket.cliente != null` (fiado o contado): `id ?? await clienteRepo.crearCliente(nombre:, apellido:, telefono:)`; luego `notifier.elegirCliente(ClienteTicket(id: idCreado, ...))` **antes** de registrar, para que un segundo cobro no lo cree otra vez.
- Práctica del recorrido: no mostrar la fila "¿Quién compra?" (`practica == true`).

- [ ] **Step 1: Write failing tests**
```dart
testWidgets('efectivo sin elegir cliente registra la venta sin cliente', ...); // clienteId null, mismos toques
testWidgets('efectivo con cliente existente guarda su clienteId', ...);
testWidgets('transferencia con cliente nuevo lo crea y lo guarda en la venta', ...);
testWidgets('deshacer la venta deja el cliente creado y no lo duplica al volver a cobrar', ...);
test('cambiarFiado(false) conserva el cliente', ...);
```
- [ ] **Step 2: Run** — Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `flutter test` — Expected: PASS.
- [ ] **Step 5: Commit** `feat: optionally mark the regular client on cash and transfer sales`

---

### Task 6: Corrección de ventas con cliente habitual

**Files:**
- Modify: `lib/repositories/correccion_repository.dart` (`corregirVenta`, `_antesVenta`)
- Modify: `lib/screens/correccion/hoja_movimiento.dart` (líneas ~156–250 y ~490–505)
- Test: `test/repositories/correccion_repository_test.dart`, `test/screens/correccion/hoja_movimiento_test.dart`

**Interfaces:**
- Consumes: Tasks 2–4.
- Produces: `corregirVenta(int id, {required int monto, required bool esFiado, int? clienteId, ClienteTicket? clienteNuevo, MedioPago medioPago, Map<int,int>? cantidades, required Usuario por})` — `clienteNuevo` (con `id` null) se crea con `crearCliente` dentro de la transacción. Contado: `clienteId` opcional y se guarda tal cual (ya no se fuerza a null). Fiado sin cliente sigue lanzando `CorreccionInvalida('Una venta fiada necesita cliente')`.
- Chequeo "nada cambió": compara `cliente == venta.clienteId` también en contado.
- `_antesVenta`: contado con cliente → `'$monto · Contado · <medio> · <nombreCompleto>'`.
- Hoja de corrección: en contado muestra el selector de medio **y** `SelectorCliente(etiqueta: '¿Quién compra?')` opcional; al pasar de fiado a contado el cliente se conserva.

- [ ] **Step 1: Write failing tests**
```dart
test('corregir fiado a contado conserva el cliente como habitual', ...);
test('cambiar solo el cliente de una venta de contado queda registrado', ...); // 1 corrección, antes con nombre
test('quitar el cliente de una venta de contado la deja de paso', ...);
test('clienteNuevo se crea con nombre y apellido en la misma transacción', ...);
testWidgets('la hoja de corrección muestra ¿Quién compra? en contado', ...);
```
- [ ] **Step 2: Run** — Expected: FAIL.
- [ ] **Step 3: Implement**, y elimina `ClienteRepository.obtenerOCrearCliente` y sus tests (ya sin llamadas).
- [ ] **Step 4: Run** `flutter test` — Expected: PASS.
- [ ] **Step 5: Commit** `feat: keep and edit the regular client when correcting sales`

---

### Task 7: Pantalla "Clientes"

**Files:**
- Create: `lib/screens/clientes/clientes_screen.dart`, `lib/screens/clientes/detalle_cliente_general_screen.dart`
- Modify: `lib/providers/clientes_providers.dart` (provider de compras)
- Modify: `lib/screens/fiado/lista_fiado_screen.dart` (entrada), `lib/screens/configuracion/ajustes_screen.dart` (entrada)
- Test: `test/screens/clientes/clientes_screen_test.dart`, `test/screens/clientes/detalle_cliente_general_test.dart`

**Interfaces:**
- Consumes: Tasks 1–3 (`listaClientesProvider`, `comprasCliente`, `editarCliente`, `crearClienteDesdeFormulario`, `saldoClienteProvider`).
- Produces: `ClientesScreen` y `DetalleClienteGeneralScreen({required int clienteId})`; `final comprasClienteProvider = FutureProvider.family<List<Venta>, int>` que se refresca con `_cambiosClientesProvider`.

Comportamiento:
- `ClientesScreen`: AppBar "Clientes"; buscador (`Key('buscador_clientes')`) por nombre, apellido o teléfono con `claveCliente`; lista A–Z de **todos** los clientes con `AvatarInicial`, `nombreCompleto`, teléfono si hay y `Pildora` "Falta apellido" cuando `apellido` es null/vacío; FAB "Agregar" → `crearClienteDesdeFormulario` (si eligió uno existente, abre ese); toque → detalle. Estado vacío: "Aún no tienes clientes".
- Detalle: tarjeta con nombre completo, teléfono, notas, deuda actual ("Al día" si 0) y botón ícono editar (`tooltip: 'Editar'`) → `editarCliente`; si tiene fiado (saldo ≠ 0 o movimientos de fiado), botón "Ver fiado" que abre `DetalleClienteScreen` existente; lista "Compras": fecha y hora (`fecha_util`), "Contado"/"Fiado" y monto.
- Entradas: en la pestaña Fiado, arriba de la lista (también con lista vacía), `ListTile`/botón `Key('ir_a_clientes')` "Todos los clientes"; en Ajustes, grupo TIENDA, `_Opcion` `Key('menu_clientes')` "Clientes" · "Datos y compras de tus clientes".

- [ ] **Step 1: Write failing tests**
```dart
testWidgets('lista a todos los clientes, también los de solo contado', ...);
testWidgets('marca "Falta apellido" en clientes antiguos', ...);
testWidgets('busca por teléfono', ...);
testWidgets('un vendedor entra desde Fiado y edita un cliente', ...); // sesión vendedor
testWidgets('el detalle muestra compras de contado y fiado con fecha y hora', ...);
testWidgets('sin desborde con letra 2,0× en 360 dp', ...);
```
- [ ] **Step 2: Run** — Expected: FAIL.
- [ ] **Step 3: Implement** siguiendo el estilo de `proveedores_screen.dart` (Card + ListTile, `EntradaEscalonada`, `EstadoVacio`).
- [ ] **Step 4: Run** `flutter test` — Expected: PASS.
- [ ] **Step 5: Commit** `feat: add a clients screen for every user`

---

### Task 8: Reportes "¿A quién le vendo?" y "Mejores clientes"

**Files:**
- Modify: `lib/repositories/reporte_repository.dart`
- Modify: `lib/screens/reportes/reportes_screen.dart` (`_Contenido`, después de la tarjeta de Fiado)
- Test: `test/repositories/reporte_clientes_test.dart` (crear), `test/screens/reportes/` (archivo existente de pantalla)

**Interfaces:**
- Produces: en `reporte_repository.dart`:
  - `class ClienteComprador { final int clienteId; final String nombre; final int compras; final int dinero; }`
  - `Reporte` gana `final int vendidoHabituales;` (ventas no anuladas del rango con `clienteId`, contado + fiado), `final int vendidoDePaso;` (ventas de **contado** sin `clienteId`) y `final List<ClienteComprador> mejoresClientes;` (top 10 por `dinero`, empate por `compras`, luego `claveCliente(nombre)`; `nombre` = `nombreCompleto` actual). Abonos no cuentan.
- Pantalla: `_Titulo('¿A quién le vendo?')` y una `Card` `Key('tarjeta_a_quien')` con dos filas: "Clientes habituales · $X · N %" y "De paso o sin marcar · $Y · M %" (porcentaje sobre `vendidoHabituales + vendidoDePaso`, redondeado; sin ventas: "Aún no hay ventas en este periodo"). Luego `_Titulo('Mejores clientes')` con filas `Key('mejor_cliente_$i')` "`i+1`. nombre · N compras · $dinero" y barra como el ranking de productos; vacío: "Marca al cliente al cobrar para ver aquí a tus mejores clientes".

- [ ] **Step 1: Write failing tests**
```dart
test('separa lo vendido a habituales y de paso', ...); // contado con y sin cliente, fiado con cliente
test('mejores clientes suma contado y fiado y excluye anuladas y abonos', ...);
test('mejores clientes ordena por dinero y luego por compras', ...);
test('mejores clientes usa el nombre completo actual', ...);
testWidgets('muestra porcentajes y la lista de mejores clientes', ...);
testWidgets('sin clientes marcados muestra la ayuda', ...);
```
- [ ] **Step 2: Run** — Expected: FAIL.
- [ ] **Step 3: Implement** dentro de `_reporte` reutilizando la lista `ventas` ya cargada.
- [ ] **Step 4: Run** `flutter test` — Expected: PASS.
- [ ] **Step 5: Commit** `feat: report sales to regular vs passing clients and best clients`

---

### Task 9: Hoja de ruta y verificación final

**Files:**
- Modify: `docs/hoja-de-ruta.md` ("En curso": mejoras de tienda tandas 1–4 con enlace al spec; "Después": proyecto "Tienda centralizada" — varios celulares, código único de tienda, alerta al admin por celular nuevo, información actualizada al ingresar, avisos de "por pedir" en todos los celulares; "Pendiente de verificar": tanda 1 en celular real).

- [ ] **Step 1:** Actualiza la hoja de ruta.
- [ ] **Step 2: Run** `dart format --output=none --set-exit-if-changed lib test` — Expected: sin cambios.
- [ ] **Step 3: Run** `flutter analyze` — Expected: "No issues found!".
- [ ] **Step 4: Run** `flutter test --coverage` — Expected: todas pasan; revisar en `coverage/lcov.info` que `lib/repositories/cliente_repository.dart` y `lib/widgets/formulario_cliente.dart` superen 80 %.
- [ ] **Step 5: Commit** `docs: track store improvements and the centralized store project in the roadmap`
