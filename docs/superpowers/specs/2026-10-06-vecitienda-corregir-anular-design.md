# Fase 3A — Corregir y anular movimientos

**Fecha:** 2026-10-06
**Estado:** Implementado (falta el recorrido manual en un celular real)
**Base:** master con Fase 1, 2A, 2E, 2B+2C, marca VeciTienda y 2D integradas.

## Objetivo

El tendero puede arreglar un movimiento mal registrado (venta, abono de fiado o gasto) sin
descuadrar la caja ni la deuda de los clientes, y el dueño puede ver qué se cambió, quién lo
cambió y cómo estaba antes.

## Decisiones tomadas con el usuario

- **Errores a cubrir (todos):** movimiento que no debió existir (se anula), monto equivocado,
  contado/fiado o cliente equivocado, medio de pago equivocado.
- **Alcance:** ventas, abonos de fiado y gastos.
- **Permisos:** el administrador corrige o anula cualquier movimiento de cualquier fecha; el
  vendedor solo los suyos y del día de hoy.
- **Rastro:** lo anulado queda visible tachado ("Anulada por X · 15:40") y no suma en ningún
  total; lo corregido muestra "Corregida por X · antes: …". No hay historial de versiones en
  pantalla, pero cada cambio queda guardado.
- **Enfoque de datos (B):** una marca `anulado` en cada tabla de movimientos y una tabla aparte
  `Correcciones` con el rastro. Se descartaron columnas de rastro por tabla (A) y
  contra-movimientos con montos negativos (C).

## Modelo de datos (esquema v2 → v3)

- `Ventas.anulado`, `PagosFiado.anulado`, `Gastos.anulado`: `BOOLEAN NOT NULL DEFAULT false`.
  Los movimientos existentes quedan sin anular.
- Tabla nueva `Correcciones` (`@DataClassName('Correccion')`):
  - `id` autoincremental
  - `tipoMovimiento`: `textEnum<TipoMovimiento>` con `venta | abono | gasto`
  - `movimientoId`: entero (id en la tabla correspondiente; sin llave foránea porque apunta a
    tres tablas)
  - `accion`: `textEnum<AccionCorreccion>` con `anulado | corregido`
  - `usuarioId`: referencia a `Usuarios`
  - `fecha`: cuándo se hizo
  - `antes`: texto corto con los valores previos, armado al momento del cambio
- Migración `desde < 3`: `addColumn` de las tres columnas `anulado` y `createTable` de
  `Correcciones`. Solo agrega; no reescribe datos. Un respaldo v2 restaurado pasa por la misma
  migración al abrirse.
- El respaldo en la nube no cambia: copia el archivo SQLite completo.

### Texto `antes`

Se arma con los valores del movimiento justo antes del cambio, con el formato de pesos de la app:

- Venta de contado: `$50.000 · Contado · Efectivo` (o `· Transferencia`)
- Venta fiada: `$50.000 · Fiado · Doña Rosa`
- Abono: `$20.000 · Efectivo` (o `· Transferencia`)
- Gasto: `$15.000 · Hielo` (o `$15.000` si no tiene descripción)

Una anulación también guarda `antes` (los valores con que quedó anulado el movimiento).

## Qué se puede cambiar

| Movimiento | Se puede cambiar | No se cambia |
|---|---|---|
| Venta | monto; contado/fiado; cliente (si es fiada); medio de pago (si es de contado) | fecha, vendedor, producto |
| Abono | monto; medio de pago | cliente, fecha, vendedor |
| Gasto | monto; descripción | fecha, vendedor |

- Un abono registrado al cliente equivocado se anula y se registra de nuevo en el correcto.
- Venta de contado → fiada: exige cliente; `medioPago` vuelve a `efectivo` (valor por defecto
  de las fiadas, que no cuentan en los totales por medio de pago).
- Venta fiada → contado: `clienteId` queda en null y se elige el medio de pago.
- Corregir a Transferencia solo cambia el registro; no abre la pantalla del QR.

## Reglas

- **Permiso:** función pura `puedeCorregir({required Usuario usuario, required int duenoId,
  required DateTime fechaMovimiento, required DateTime ahora})` en
  `lib/util/permisos.dart`: `true` si `usuario.rol == 'admin'`, o si `duenoId == usuario.id` y
  `fechaMovimiento` cae en el mismo día local que `ahora`. La pantalla la usa para mostrar u
  ocultar los botones; el repositorio la vuelve a comprobar y lanza `PermisoDenegado` si no
  se cumple.
- **Lo anulado no cuenta en nada:** totales de Inicio, efectivo/transferencia, resumen por
  vendedor, tarjetas del Historial, saldo de cada cliente, deuda total y clientes con deuda.
- **No hay "desanular".** Si se anuló por error, se registra el movimiento de nuevo.
- **No se corrige ni se anula algo ya anulado.**
- **Atomicidad:** cada corrección o anulación actualiza el movimiento e inserta su fila en
  `Correcciones` dentro de una misma transacción.
- **Validación:** el monto corregido debe ser mayor que 0 (para dejarlo en cero se anula); una
  venta fiada debe tener cliente. "Guardar" solo se habilita si algo cambió.
- **Saldo a favor:** si una corrección o anulación deja a un cliente con más abonos que
  ventas fiadas, queda con saldo a favor; ya se maneja hoy (cuenta como 0 en la deuda total y
  no aparece en la lista de Fiado).
- **"Deshacer" tras cobrar** no cambia: sigue borrando la venta sin dejar rastro
  (`VentaRepository.eliminarVenta`).

## Repositorios

- **`CorreccionRepository` (nuevo, `lib/repositories/correccion_repository.dart`):** único
  punto que anula o corrige.
  - `anularVenta(id, {required Usuario por})`, `corregirVenta(id, {monto, esFiado,
    clienteId, medioPago, required Usuario por})`
  - `anularPago(id, …)`, `corregirPago(id, {monto, medioPago, …})`
  - `anularGasto(id, …)`, `corregirGasto(id, {monto, descripcion, …})`
  - Cada método lee el movimiento, comprueba que exista y no esté anulado, aplica
    `puedeCorregir`, valida, arma `antes`, y en una transacción actualiza e inserta en
    `Correcciones`.
  - `ultimasCorrecciones(TipoMovimiento tipo, Iterable<int> ids)` → mapa id → corrección más
    reciente (con nombre de quien la hizo resuelto en pantalla con la lista de usuarios).
- **Filtro `anulado = false`** en todas las consultas que suman: `VentaRepository.ventasDelDia`,
  `FiadoRepository.pagosDelDia`, `GastoRepository.gastosDelDia`, `FiadoRepository.saldoCliente`,
  `listaClientesConDeuda`, `_saldosAl`. `ResumenRepository` hereda el filtro.
- **Consultas que sí traen lo anulado**, solo para mostrar listas: el Historial
  (`HistorialRepository.movimientosDelDia`) y el detalle del cliente
  (`FiadoRepository.movimientosCliente`) pasan `incluirAnulados: true` a
  `ventasDelDia`, `gastosDelDia`, `ventasFiadasCliente` y `pagosCliente` (parámetro nuevo,
  `false` por defecto) y adjuntan la última corrección de cada movimiento.
- **`MovimientoHistorial` y `MovimientoFiado`** ganan `id`, `anulado` y `ultimaCorreccion`
  (`Correccion?`), más lo necesario para editar (`clienteId` en ventas).
- Los totales del Historial (tarjetas Ventas/Gastos) se calculan solo con los no anulados.

## Pantallas

### Hoja de movimiento (`lib/screens/correccion/hoja_movimiento.dart`, nueva)

Se abre con `mostrarHojaInferior` al tocar un movimiento. Reutilizada desde Historial y Fiado.

- **Modo detalle:** monto, tipo (Contado/Fiado, Abono o Gasto), medio de pago o cliente o
  descripción, vendedor y hora, y la última corrección si la hay. Si `puedeCorregir` da true y
  el movimiento no está anulado, muestra **Corregir** y **Anular** (rojo). Si no, solo el
  detalle.
- **Modo corregir:** campo de monto (como "Otro monto"), `SelectorSegmentado` de
  Contado/Fiado y de Efectivo/Transferencia (como en Registrar venta), buscador de cliente
  (el `_SelectorCliente` de Registrar venta se extrae a `lib/widgets/selector_cliente.dart` y
  se usa en ambas pantallas) y campo
  de descripción para gastos. Botón **Guardar** habilitado solo si algo cambió. Al guardar:
  aviso "Venta corregida" / "Abono corregido" / "Gasto corregido".
- **Anular:** `AlertDialog` "¿Anular esta venta de $5.000? Ya no contará en los totales." con
  [Cancelar] y [Anular] en rojo (mismo patrón que "Quitar QR"). Al confirmar: aviso "Venta
  anulada" / "Abono anulado" / "Gasto anulado".
- **Error al guardar:** texto rojo dentro de la hoja "No se pudo guardar, intenta de nuevo" (como el error del abono; un aviso abajo quedaría tapado por la hoja); no cambia nada.

### Historial

- Tocar una venta o un gasto abre la hoja. Los abonos siguen sin aparecer en el Historial
  (se corrigen desde Fiado).
- **Anulado:** monto tachado y en gris; subtítulo "Anulada por Ana · 15:40" (hora con `formatoHora`) (o
  "Anulado" para gastos).
- **Corregido:** fila normal con una línea gris extra "Corregida por Ana · antes: $50.000 ·
  Efectivo".
- Tarjetas Ventas y Gastos sin lo anulado.

### Fiado → detalle del cliente

- Tocar una venta fiada o un abono abre la misma hoja, con las mismas marcas de anulado y
  corregido. El saldo mostrado ya excluye lo anulado.
- Si una corrección deja la venta como de contado, deja de aparecer en el detalle del cliente
  (ya no es fiada); su rastro sigue en el Historial.

### Inicio

Sin cambios de interfaz; sus totales excluyen lo anulado.

## Pruebas (TDD)

- **Migración v2 → v3:** una base v2 con datos abre en v3, los movimientos quedan con
  `anulado = false` y existe `Correcciones`.
- **`puedeCorregir`:** admin cualquier día y dueño; vendedor propio de hoy sí; vendedor propio
  de ayer no; vendedor de otro no.
- **`CorreccionRepository`:** cada anular/corregir cambia el movimiento y crea su fila con
  `antes` correcto; vendedor sin permiso recibe `PermisoDenegado` y nada cambia; no se puede
  anular dos veces; monto 0 y fiado sin cliente se rechazan.
- **Totales y saldos:** anulado no cuenta en `resumenDelDia` (total, efectivo, transferencia,
  cantidades), `resumenPorVendedor`, `saldoCliente`, `deudaTotalAl`, `clientesConDeudaAl`,
  `listaClientesConDeuda`; contado → fiado suma a la deuda del cliente; fiado → contado la
  resta y suma al medio de pago elegido.
- **Pantallas:** la hoja muestra u oculta los botones según el usuario; corregir actualiza la
  fila y muestra "Corregida por …"; anular pide confirmación, tacha y descuenta de las
  tarjetas; cancelar no cambia nada; lo mismo desde el detalle del cliente.

## Fuera de alcance

- Desanular.
- Ver el historial completo de cambios de un movimiento (los datos quedan guardados para
  hacerlo después).
- Cambiar fecha, vendedor o producto de un movimiento.
- Mostrar abonos en el Historial.
- Corregir clientes o productos (ya tienen su propia edición o no aplica).
