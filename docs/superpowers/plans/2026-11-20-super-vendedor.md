# Super vendedor y "cada vendedor ve lo suyo" Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Un vendedor con el permiso "maneja catálogo" puede gestionar productos, proveedores y
cualquier pedido; todo vendedor ve en Inicio e Historial solo lo suyo.

**Architecture:** Columna booleana `manejaCatalogo` en `usuarios` (BD v14) que viaja con la
sincronización de filas existente. Las reglas viven en `lib/util/permisos.dart` y se exponen en
`SesionState`; las pantallas reemplazan `esAdmin` por la regla que corresponde. Los providers de
resumen pasan a recibir `({dia, usuarioId})` como ya hace Historial.

**Tech Stack:** Flutter, Riverpod, Drift (SQLite), flutter_test.

**Spec:** `docs/superpowers/specs/2026-11-20-super-vendedor-design.md`

## Global Constraints

- Sin migración Supabase; sin dependencias nuevas.
- El super vendedor **no** ve Reportes, nombre de tienda, Clientes, Usuarios, Celulares, Cobro
  por QR ni Respaldo.
- "Por cobrar" y "clientes con deuda" siguen siendo de toda la tienda (ya lo son en
  `ResumenRepository.resumenDelDia`).
- Textos de UI en español; etiqueta en Usuarios: `Super vendedor N` (N = número de vendedor);
  interruptor: `Puede manejar productos, proveedores y pedidos`.
- `dart format` solo en archivos tocados; `flutter analyze` sin hallazgos; `flutter test` verde.
- Commits Conventional, directo a `master`, terminando con
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. Celular con versión anterior edita un usuario y sube la fila sin `maneja_catalogo`: en los
   celulares nuevos el valor local no debe borrarse (aplicarFila solo pisa columnas presentes) →
   prueba en Task 1.
2. Un admin nunca pierde permisos aunque tenga `manejaCatalogo = false` → prueba en Task 2.
3. Vendedor desactivado con el permiso: no entra, y al reactivarlo conserva el permiso → prueba
   en Task 1 (repositorio).
4. Super vendedor abre Ajustes: no hay forma de llegar al nombre de la tienda ni a Usuarios →
   prueba en Task 3.
5. Vendedor cambia de día en Inicio: los totales y la semana siguen filtrados a él → prueba en
   Task 5.

---

### Task 1: Columna `manejaCatalogo` (BD v14), sincronización y repositorio

**Files:**
- Modify: `lib/data/database.dart` (tabla `Usuarios`, `schemaVersion` 13 → 14, bloque
  `if (desde < 14)`)
- Modify: `lib/data/disparadores_sincronizacion.dart` (`columnasUsuarioCompartidas`)
- Modify: `lib/repositories/usuario_repository.dart`
- Create: `test/support/esquema_v13.dart` (`void crearBaseV13(String ruta)`, copia de
  `esquema_v12.dart` + columnas `activo`, `numero_vendedor`, `version_pin` en `usuarios` y los
  disparadores v13)
- Test: `test/data/migracion_test.dart`, `test/repositories/usuario_repository_test.dart`,
  `test/sincronizacion/filas_sincronizables_test.dart`

**Interfaces:**
- Produces: `Usuario.manejaCatalogo` (bool, default false; SQL `maneja_catalogo`);
  `UsuarioRepository.crearUsuario({..., bool manejaCatalogo = false})`;
  `Future<void> UsuarioRepository.cambiarManejaCatalogo(int usuarioId, bool valor)`.

- [ ] **Step 1: Write the failing tests**
  - `una base v13 abre en v14 con usuarios sin permiso de catálogo`: `crearBaseV13`, abrir,
    todos `manejaCatalogo == false`.
  - `una base v13 migrada tiene las mismas columnas que una base nueva` (patrón v12).
  - `cambiar el permiso de catálogo anota un cambio pendiente`: tras
    `cambiarManejaCatalogo(id, true)`, `cambios_pendientes` tiene la fila de `usuarios` con ese
    `id_global`.
  - `una fila de la nube sin maneja_catalogo no borra el permiso local`: usuario local con
    `true`; `aplicarFila(db, 'usuarios', datosSinLaColumna)` → sigue `true`.
  - `crearUsuario guarda el permiso` y `desactivar y activar conserva el permiso`.
- [ ] **Step 2:** `flutter test test/data/migracion_test.dart test/repositories/usuario_repository_test.dart` → FAIL (getter inexistente).
- [ ] **Step 3: Implement.** `BoolColumn get manejaCatalogo => boolean().withDefault(const Constant(false))();`
  agregar `maneja_catalogo` al final de `columnasUsuarioCompartidas`; en `desde < 14`:
  `addColumn(usuarios, usuarios.manejaCatalogo)`, `DROP TRIGGER IF EXISTS sincronizar_usuarios_edicion`,
  `_crearDisparadores()`. Correr `dart run build_runner build --delete-conflicting-outputs`.
- [ ] **Step 4:** mismos tests → PASS; `flutter test` completo → PASS.
- [ ] **Step 5: Commit** `feat: store the catalog permission on each user`

### Task 2: Reglas de permiso y pedidos de otros

**Files:**
- Modify: `lib/util/permisos.dart`, `lib/providers/sesion_provider.dart`,
  `lib/repositories/pedido_repository.dart:180`,
  `lib/screens/inventario/pedido_por_llegar_screen.dart:163`
- Test: `test/util/permisos_test.dart`, `test/providers/sesion_provider_test.dart`, test
  existente de `pedido_repository`

**Interfaces:**
- Consumes: `Usuario.manejaCatalogo` (Task 1).
- Produces: `bool puedeManejarCatalogo(Usuario? usuario)` (admin, o vendedor con
  `manejaCatalogo`); `bool puedeCambiarPedido(Usuario usuario, {required int autorId})`
  (`puedeManejarCatalogo(usuario) || usuario.id == autorId`);
  `SesionState.puedeManejarCatalogo` (getter que delega).

- [ ] **Step 1: Write the failing tests** — tabla de casos en `permisos_test.dart`: admin
  (con permiso false) → true; vendedor sin permiso → false; vendedor con permiso → true; null →
  false. `puedeCambiarPedido`: vendedor sin permiso con pedido ajeno → false, propio → true;
  super vendedor con pedido ajeno → true. Repositorio: `super vendedor anula el pedido de otro`
  no lanza `PermisoDenegado`; vendedor normal sí lanza.
- [ ] **Step 2:** correr esos tests → FAIL.
- [ ] **Step 3: Implement** las dos funciones y el getter; reemplazar las dos condiciones de
  pedidos por `puedeCambiarPedido`.
- [ ] **Step 4:** tests → PASS.
- [ ] **Step 5: Commit** `feat: let catalog managers change any order`

### Task 3: Pantallas de catálogo para el super vendedor

**Files:**
- Modify: `lib/screens/home/home_screen.dart:184` (pestaña Ajustes si
  `sesion.puedeManejarCatalogo`), `lib/screens/configuracion/ajustes_screen.dart`,
  `lib/screens/venta/registrar_venta_screen.dart:137,666`,
  `lib/screens/inventario/detalle_inventario_screen.dart:70`,
  `lib/screens/inventario/inventario_screen.dart:209`,
  `lib/screens/consulta/consultar_precio.dart:23`
- Test: `test/screens/configuracion/ajustes_screen_test.dart`, tests existentes de esas pantallas

**Interfaces:**
- Consumes: `SesionState.puedeManejarCatalogo` (Task 2).

Comportamiento: para un no-admin con permiso, `AjustesScreen` muestra **solo** la sección
TIENDA con `menu_productos` y `menu_proveedores` (sin `cabecera_ajustes`/`menu_nombre_tienda`,
sin Clientes, Usuarios, Celulares, COBROS Y DATOS, AYUDA ni CUENTA: el vendedor ya tiene ayuda y
cerrar sesión en el menú de Inicio). Los botones Editar producto y el mensaje de inventario usan
`puedeManejarCatalogo`. Todo lo demás con `esAdmin` (Reportes, solicitudes, nombre de tienda,
QR) no cambia.

- [ ] **Step 1: Write the failing tests** — `super vendedor ve Ajustes con solo productos y
  proveedores` (finds `menu_productos`, `menu_proveedores`; findsNothing `menu_nombre_tienda`,
  `menu_clientes`, `menu_usuarios`, `menu_respaldo`); `vendedor normal no tiene la pestaña
  Ajustes`; `super vendedor ve boton_editar_producto en el detalle de inventario`; `super
  vendedor no ve boton_ver_reportes`.
- [ ] **Step 2:** → FAIL.
- [ ] **Step 3: Implement** con un `bool soloCatalogo = !sesion.esAdmin` en `AjustesScreen`.
- [ ] **Step 4:** → PASS; `flutter test` completo.
- [ ] **Step 5: Commit** `feat: open products and suppliers to catalog managers`

### Task 4: Activar el permiso en Usuarios + preguntas frecuentes

**Files:**
- Modify: `lib/screens/configuracion/usuarios_screen.dart` (formulario y lista),
  `lib/screens/ayuda/preguntas_frecuentes.dart` (tema de usuarios)
- Test: `test/screens/configuracion/usuarios_screen_test.dart`

**Interfaces:**
- Consumes: `crearUsuario(manejaCatalogo:)`, `cambiarManejaCatalogo` (Task 1).

Comportamiento: en `_FormularioUsuario`, con rol `vendedor`, un `SwitchListTile`
(`Key('interruptor_maneja_catalogo')`, texto `Puede manejar productos, proveedores y pedidos`);
oculto con rol admin. En la lista, la píldora `rol_<id>` dice `Super vendedor N` si tiene el
permiso, y cada vendedor activo tiene un `IconButton` `Key('maneja_catalogo_<id>')` (tooltip
`Productos, proveedores y pedidos`) que invierte el permiso y avisa
`<nombre> ya puede manejar productos` / `<nombre> ya no maneja productos`.

- [ ] **Step 1: Write the failing tests** — crear vendedor con el interruptor → la píldora dice
  `Super vendedor 1`; interruptor no aparece al elegir Administrador; tocar
  `maneja_catalogo_<id>` cambia la píldora en ambos sentidos.
- [ ] **Step 2:** → FAIL.
- [ ] **Step 3: Implement**; agregar en preguntas frecuentes, tema usuarios, un párrafo: qué
  puede hacer el super vendedor y que no ve reportes.
- [ ] **Step 4:** → PASS.
- [ ] **Step 5: Commit** `feat: turn a seller into a catalog manager from Usuarios`

### Task 5: Cada vendedor ve solo lo suyo en Inicio e Historial

**Files:**
- Modify: `lib/repositories/resumen_repository.dart` (`ventasDiarias`),
  `lib/providers/resumen_providers.dart`, `lib/screens/home/resumen_screen.dart`,
  `lib/screens/historial/historial_screen.dart`
- Test: `test/repositories/resumen_repository_test.dart`,
  `test/screens/home/resumen_screen_test.dart`, `test/screens/historial/historial_screen_test.dart`

**Interfaces:**
- Produces: `ventasDiarias(DateTime hasta, {int dias = 7, int? usuarioId})`;
  `typedef FiltroResumen = ({DateTime dia, int? usuarioId});` y `resumenDelDiaProvider`,
  `ventasDiariasProvider` como `family<..., FiltroResumen>` (`resumenPorVendedorProvider` sigue
  por `DateTime`, solo lo usa el admin).

Comportamiento: en `ResumenScreen`, `usuarioId = esAdmin ? null : usuarioActivo.id`; la tarjeta
`tarjeta_por_vendedor` solo para admin (y su provider no se observa si no es admin). En
`HistorialScreen`, para no-admin `_usuarioId` es el del usuario activo y no se muestran los chips
de usuarios.

- [ ] **Step 1: Write the failing tests** — repositorio: `ventasDiarias con usuarioId solo suma
  sus ventas`; pantalla: `vendedor ve solo su total del día` (dos vendedores con ventas distintas;
  el monto visible es el del activo), `vendedor no ve la tarjeta por vendedor`, `al cambiar de día
  el vendedor sigue viendo solo lo suyo`; historial: `vendedor solo ve sus movimientos y no ve los
  filtros de usuario`; admin sin cambios (tests existentes).
- [ ] **Step 2:** → FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4:** → PASS; `flutter test` completo; `flutter analyze`.
- [ ] **Step 5: Commit** `feat: show each seller only their own sales`
