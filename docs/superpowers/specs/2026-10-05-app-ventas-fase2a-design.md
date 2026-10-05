# App de ventas — Fase 2A (completar pantallas pendientes de la Fase 1)

**Fecha:** 2026-10-05
**Estado:** Implementado
**Base:** `docs/superpowers/specs/2026-09-02-app-ventas-fase1-design.md`

## Contexto y alcance

La "Fase 2" del proyecto se descompuso en cuatro subproyectos independientes, cada uno con su
propio spec → plan → implementación:

| # | Subproyecto | Estado |
|---|---|---|
| **2A** | Completar pantallas pendientes de la Fase 1 | **Este spec** |
| 2B | Respaldo/sincronización con Supabase | Pendiente (se diseñará junto con 2C) |
| 2C | Identidad de la tienda por OTP (SMS/WhatsApp) | Pendiente |
| 2D | Cobro digital vía QR (Bre-B / Nequi / Daviplata) | Pendiente |

La Fase 1 dejó cinco capacidades especificadas cuyo repositorio existe y está probado, pero sin
pantalla (ver "Alcance no cubierto en esta fase" en `README.md`). 2A las conecta a la UI, corrige
un defecto de refresco del historial y agrega dos ajustes de producto que salieron del diseño:
múltiples administradores y reactivar productos.

Todo es local: sin red, sin dependencias nuevas, sin cambios al esquema de la base de datos.

## Objetivo

Que la app cumpla completamente las pantallas descritas en el spec de la Fase 1:

1. Un admin puede resetear el PIN de cualquier usuario, incluido otro admin.
2. Un admin puede crear otros admins (no solo vendedores), para que el olvido del PIN de un
   admin no deje la tienda sin acceso a Configuración.
3. Un admin puede editar nombre y precio de un producto, y reactivar un producto desactivado.
4. El detalle de un cliente con fiado muestra su historial de ventas fiadas y abonos, y su saldo
   se actualiza en pantalla tras registrar un abono.
5. El resumen puede consultarse para días anteriores.
6. El historial muestra ventas **y gastos**, puede consultarse para cualquier día, filtrarse por
   usuario, y se refresca solo cuando se registra una venta o un gasto.
7. `README.md` deja de listar estas capacidades en "Alcance no cubierto en esta fase" (la
   sección se elimina o se reemplaza por los pendientes de 2B/2C/2D).

## Permisos por rol

Sin cambios respecto a la Fase 1: Configuración (productos y usuarios) es solo para admin;
resumen e historial son visibles para ambos roles, con todos los datos de la tienda.

## Comportamiento por pantalla

### Configuración → Usuarios (solo admin)

- El formulario de creación agrega un selector de rol: **Vendedor** (por defecto) o
  **Administrador**. El texto del botón pasa a "Agregar usuario".
- Tocar un usuario de la lista abre un diálogo **"Resetear PIN de &lt;nombre&gt;"** con un campo de
  PIN de 4 dígitos (oculto). Validación: exactamente 4 dígitos (`^\d{4}$`, igual que en la
  creación). Si es inválido, el diálogo muestra el error "El PIN debe tener 4 dígitos" y no se
  cierra. Si es válido, guarda vía `UsuarioRepository.resetearPin` y cierra mostrando un
  SnackBar "PIN actualizado".
- Un admin puede resetear su propio PIN desde aquí también.
- Si al crear un usuario el nombre está vacío o el PIN es inválido, se muestra el mensaje de
  error correspondiente bajo el campo (hoy el formulario no hace nada en silencio).

### Configuración → Productos (solo admin)

- Tocar un producto activo abre un diálogo **"Editar producto"** con nombre y precio
  precargados. Validación: nombre no vacío, precio entero > 0. Guarda vía
  `ProductoRepository.actualizarProducto`. Cambiar el precio no afecta ventas ya registradas
  (cada venta guarda su propio `monto`).
- Debajo de la lista de activos, una sección **"Inactivos"** (solo visible si hay alguno) lista
  los productos desactivados, cada uno con un botón **"Reactivar"**.
- El botón de desactivar existente se mantiene.

### Fiado → Detalle del cliente

- El saldo ("Debe: $X") se lee de un provider reactivo, no del valor recibido al abrir la
  pantalla, de modo que se actualiza en cuanto se registra un abono.
- El monto del abono acepta separador de miles ("2.000"). Un monto inválido muestra "Escribe un
  monto válido"; un abono mayor que la deuda se rechaza con "El abono no puede ser mayor que la
  deuda ($X)" y no se registra.
- Tras registrar un abono la pantalla **ya no se cierra**: limpia el campo, muestra un SnackBar
  "Abono registrado" y el saldo e historial se actualizan. Si el saldo llega a 0 el cliente sale
  de la lista "me deben" (comportamiento existente del provider de la lista).
- Debajo del formulario de abono, una lista **"Movimientos"**: ventas fiadas y abonos mezclados,
  del más reciente al más antiguo. Cada fila: fecha (dd/mm/aaaa hh:mm), monto formateado, y
  etiqueta "Venta fiada" o "Abono" (los abonos con un color distinto).

### Resumen

- Encabezado con un **selector de fecha**: flecha ‹ (día anterior), la fecha en el centro y
  flecha › (día siguiente). Tocar la fecha abre un `showDatePicker`.
- La fecha muestra "Hoy" cuando el día seleccionado es el actual; si no, "dd/mm/aaaa".
- No se puede seleccionar un día posterior a hoy: la flecha › se deshabilita en hoy y el
  date picker tiene `lastDate` = hoy.
- Los totales generales y el desglose por vendedor corresponden al día seleccionado.
- La pantalla abre siempre en hoy.

### Historial

- Título "Historial". Mismo selector de fecha que el resumen.
- Filtro de usuario: un desplegable "Todos" + cada usuario de la tienda. Por defecto "Todos".
- La lista mezcla **ventas y gastos** del día y usuario seleccionados, ordenados por hora
  descendente (lo más reciente arriba):
  - Venta: monto, "Contado" o "Fiado", nombre del usuario, hora.
  - Gasto: monto en color de gasto con ícono distinto, descripción (o "Gasto" si no tiene),
    nombre del usuario, hora.
- Si no hay movimientos: texto "Sin movimientos este día".
- La lista se refresca sola al registrarse una venta o un gasto (hoy no lo hace).

## Arquitectura

Mismas capas que la Fase 1 (UI → providers Riverpod → repositorios → Drift). Sin cambios de
esquema.

### Repositorios

- **`ProductoRepository`** — nuevos:
  - `Future<void> reactivarProducto(int id)`
  - `Stream<List<Producto>> observarProductosInactivos()`
- **`FiadoRepository`** — nuevo:
  - `Future<List<MovimientoFiado>> movimientosCliente(int clienteId)`: une
    `ventasFiadasCliente` y `pagosCliente`, ordenado por fecha descendente.
  - `MovimientoFiado { TipoMovimientoFiado tipo (venta | abono), int monto, DateTime fecha }`.
- **Nuevo `HistorialRepository`** (`lib/repositories/historial_repository.dart`), construido
  con `VentaRepository` y `GastoRepository` (mismo patrón que `ResumenRepository`):
  - `Future<List<MovimientoHistorial>> movimientosDelDia(DateTime dia, {int? usuarioId})`:
    une `ventasDelDia` y `gastosDelDia` con el mismo filtro, ordenado por fecha descendente.
  - `MovimientoHistorial { TipoMovimientoHistorial tipo (venta | gasto), int monto,
    DateTime fecha, int usuarioId, bool esFiado (false para gastos), String? descripcion }`.
- `UsuarioRepository`: sin cambios (`crearUsuario` ya recibe `rol`; `resetearPin` ya existe).

### Providers

Todos los providers de lectura que dependen de datos mutables escuchan
`databaseProvider.tableUpdates()` (patrón ya usado en `fiado_providers.dart` y
`resumen_providers.dart`) para recalcularse solos.

- `resumenDelDiaProvider` y `resumenPorVendedorProvider` pasan a
  `FutureProvider.autoDispose.family<…, DateTime>`. La clave es el día **normalizado**
  (`inicioDelDia(dia)`); la pantalla siempre normaliza antes de leer el provider, para que la
  clave no cambie con cada `DateTime.now()`.
- `historialDelDiaProvider` se reemplaza por
  `historialProvider = FutureProvider.autoDispose.family<List<MovimientoHistorial>, FiltroHistorial>`,
  donde `FiltroHistorial` es un record `({DateTime dia, int? usuarioId})` con el día normalizado.
- Nuevos: `saldoClienteProvider.family<int, int>`, `movimientosClienteProvider.family<List<MovimientoFiado>, int>`,
  `productosInactivosProvider` (StreamProvider), `historialRepositoryProvider`.
- El día seleccionado y el filtro de usuario son estado local (`StatefulWidget`) de cada
  pantalla, no estado global.

### Widgets nuevos

- `lib/widgets/selector_fecha.dart` — `SelectorFecha({required DateTime dia, required ValueChanged<DateTime> onCambio})`:
  flechas, etiqueta "Hoy"/fecha, date picker con `lastDate` = hoy. Usado por Resumen e
  Historial.
- Diálogos de editar producto y resetear PIN, cada uno en el archivo de su pantalla o en un
  archivo propio si el archivo de la pantalla crece demasiado.

## Manejo de errores

- Los campos de dinero (precio de producto, abono) aceptan el separador de miles colombiano
  ("3.000", "$3.000") y rechazan signos y decimales.
- Validación en formularios y diálogos con mensaje visible (`errorText` del campo); nunca un
  botón que no hace nada sin explicar por qué.
- Errores de carga de providers: se mantiene el patrón existente (`Text('Error: $e')`).

## Pruebas

TDD como en la Fase 1; base de datos Drift en memoria (`NativeDatabase.memory()`), sin mocks.

- **Unit (repositorios):**
  - `reactivarProducto` lo devuelve a `observarProductosActivos` y lo saca de
    `observarProductosInactivos`.
  - `movimientosCliente` mezcla ventas fiadas y abonos en orden descendente y excluye ventas
    de contado y movimientos de otros clientes.
  - `movimientosDelDia` mezcla ventas y gastos ordenados por hora, respeta el filtro por
    usuario y excluye otros días.
- **Widget:**
  - Usuarios: crear un admin; resetear PIN válido (y verificar con `verificarPin`); PIN
    inválido muestra error y no cierra el diálogo.
  - Productos: editar nombre/precio; desactivar y reactivar.
  - Detalle cliente: muestra movimientos; tras un abono el saldo se actualiza y la pantalla
    sigue abierta.
  - Resumen: navegar al día anterior muestra los totales de ese día; la flecha › está
    deshabilitada en hoy.
  - Historial: muestra ventas y gastos; el filtro por usuario oculta los de otros; una venta
    registrada después de abrir la pantalla aparece sin reabrirla.
- Los 53 tests existentes deben seguir pasando (ajustando los que dependan de textos o
  providers renombrados).
- Verificación manual final en el emulador `app_ventas_ligero`.

## Fuera de alcance

- Editar o anular una venta, abono o gasto ya registrado.
- Eliminar usuarios o cambiar el rol de un usuario existente.
- Exportar reportes, rangos de fechas (semana/mes) en resumen o historial.
- Todo lo de 2B/2C/2D (nube, OTP, QR).
