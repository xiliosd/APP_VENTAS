# Renovación de la interfaz — R3a: fiado y gasto

**Fecha:** 2026-10-11
**Estado:** Diseño aprobado en conversación; pendiente revisión de esta especificación
**Base:** master con R1, R2a y R2b (3636e30, 637 pruebas).

## Contexto

La renovación busca que VeciTienda impresione al **mostrarla y venderla**. La R3 (pantallas de
dinero) se dividió:

- **R3a (esta):** lista de fiado, detalle del cliente (con abono rápido) y nuevo gasto con
  categorías.
- **R3b (siguiente):** reportes, historial, corrección y cobro QR.

El usuario eligió para la R3a: **fiado más potente** y **gasto con categorías**. Pidió además
**quitar del plan el recordatorio de fiado por WhatsApp** (se elimina de
`docs/hoja-de-ruta.md`).

Sin cambios de esquema de base de datos ni dependencias nuevas.

## 1. Lista de fiado (`lib/screens/fiado/lista_fiado_screen.dart`)

- **Tarjeta principal "Te deben"** (`tarjeta_te_deben`): fondo `tarjetaPrincipal`, radio
  `radioTarjetaPrincipal`, `Monto(total, tamano: 36, tono: claro, animado: true)`, detalle
  "N clientes" y, si hay al menos un cliente, "Mayor deuda: {nombre} {monto}"
  (`texto_mayor_deuda`).
- **Buscador** (`buscador_fiado`, "Buscar cliente…", lupa) cuando hay **más de 5** clientes con
  deuda; filtra por nombre con `sinTildes` (coincidencia en cualquier parte). Sin coincidencias:
  "Sin resultados" (`texto_sin_resultados_fiado`).
- **Orden** (`selector_orden_fiado`, `SelectorSegmentado`): **"Mayor deuda"** (por defecto;
  saldo descendente, empate por nombre) y **"Más antigua"** (`fechaDeudaMasAntigua`
  ascendente, empate por saldo descendente). Visible con 2 o más clientes con deuda.
- **Tarjeta por cliente** (`cliente_deuda_{id}`, se conserva la clave): avatar, nombre, monto
  en `fiado` y una **etiqueta de antigüedad** (`antiguedad_{id}`) con el texto actual de
  `textoDebeDesde`:
  | Días desde la deuda más antigua | Fondo / texto |
  |---|---|
  | 0–7 | `primarioSuave` / `texto` |
  | 8–30 | `fiadoSuave` / `fiado` |
  | > 30 | `sale` 15 % / `texto`, con ícono de reloj en `sale` |
  (Con `textoSecundario` o `sale` como texto no se llegaba a 4,5:1.)
  Días = diferencia en días calendario entre `inicioDelDia(fecha)` y `inicioDelDia(hoy)`.
- Las tarjetas entran con `EntradaEscalonada`.
- **Al día**: sección plegable (`boton_al_dia`, "Al día (N)" con flecha), **cerrada** por
  defecto; al abrirla muestra las filas actuales (`cliente_al_dia_{id}`).
- Sin clientes con deuda: el `EstadoVacio` actual.
- Los datos vienen de `clientesConDeudaProvider` y `clientesAlDiaProvider` (sin cambios); el
  orden y el filtro se hacen en la pantalla.

## 2. Detalle del cliente (`lib/screens/fiado/detalle_cliente_screen.dart`)

### Tarjeta de la deuda

`tarjeta_deuda_cliente`: fondo `tarjetaPrincipal`, radio `radioTarjetaPrincipal`; nombre del
cliente (estiloTitulo 14, 75 %), `Monto(saldo, 36, claro, animado)`, y:

- Saldo > 0: `textoDebeDesde(fechaDeudaMasAntigua)` y el botón **"Registrar abono"**
  (`boton_registrar_abono`, `BotonPrincipal` variante `entra`) dentro de la tarjeta.
- Saldo = 0: "Al día", sin botón.
- Saldo < 0: "Saldo a favor {monto}", sin botón.

### Línea de tiempo

Reemplaza la lista de "Movimientos" (`linea_tiempo`):

- Agrupada por día del movimiento (más reciente primero); encabezados "Hoy", "Ayer" o
  `fechaCorta` ("7 oct"; con año si no es el año en curso: "7 oct 2025").
- Cada movimiento (`movimiento_{tipo}_{id}`, conservar la clave actual si existe) es una fila
  con un punto de color sobre una línea vertical continua: venta fiada `fiado` con
  "+ {monto}" y "Venta fiada"; abono `entra` con "− {monto}" y "Abono · efectivo|transferencia";
  hora (`formatoHora`) y la corrección (`textoCorreccion`) como hoy.
- **"Quedó debiendo {saldo}"** (`saldo_tras_{tipo}_{id}`, 12 px, `textoSecundario`): saldo
  acumulado después de ese movimiento, calculado recorriendo los movimientos **no anulados**
  del más antiguo al más reciente (venta suma, abono resta). Si es negativo: "Saldo a favor
  {monto}".
- Anulados: monto tachado y en `textoSecundario`, sin línea de saldo.
- Tocar un movimiento abre `abrirHojaMovimiento` como hoy.
- Función pura nueva `saldosAcumulados(List<MovimientoFiado>) → Map<(TipoMovimientoFiado,
  int), int>` en `lib/util/saldos_fiado.dart`.

### Abono rápido

`_HojaAbono` recibe el `saldo` actual. Arriba del teclado, chips (`ChoiceChip`):

- **"Todo · {saldo}"** (`abono_todo`): fija el monto en el saldo.
- **"Mitad · {mitad}"** (`abono_mitad`): `mitad = ((saldo / 2) / 100).round() * 100`; se
  oculta si `mitad <= 0` o `mitad >= saldo`.

Elegir un chip reemplaza el monto; luego el teclado sigue editándolo. Medio de pago, tope ("El
abono no puede ser mayor que la deuda"), cobro QR y guardado: sin cambios.

## 3. Nuevo gasto (`lib/screens/gasto/registrar_gasto_screen.dart`)

- Monto grande (`MontoAnimado`, tono `sale`, 36) sobre el teclado actual.
- **Categorías** (`ChoiceChip`, una a la vez, claves `categoria_{nombre en minúscula sin
  tilde}`): **Mercancía, Servicios, Arriendo, Transporte, Otro**.
  - Al elegir una (salvo Otro), la descripción queda `"{Categoría}"` si estaba vacía, o
    `"{Categoría} · {texto}"` si había texto escrito (si el texto ya empezaba por otra
    categoría + " · ", se reemplaza esa categoría).
  - "Otro" quita la categoría del inicio de la descripción y deja el resto.
  - Volver a tocar la categoría elegida la quita.
- Campo de descripción y botón "Registrar gasto" como hoy; se guarda en `descripcion`.

## Hoja de ruta

`docs/hoja-de-ruta.md`: quitar "Recordatorios de fiado por WhatsApp" de "Siguiente".

## Fuera de alcance

Recordatorios por WhatsApp (eliminados del plan), reportes, historial, corrección y cobro QR
(R3b), administración (R4).

## Pruebas

- **Lista de fiado:** orden por mayor deuda y por más antigua (con empates); buscador con
  tildes y "Sin resultados"; buscador oculto con ≤ 5; etiqueta de antigüedad con color en 7,
  8, 30 y 31 días; "Al día" cerrado por defecto y se abre; "Mayor deuda" correcto; se conservan
  las pruebas actuales ajustadas.
- **`saldosAcumulados`:** ventas y abonos alternados, anulados ignorados, saldo a favor.
- **Detalle:** tarjeta según saldo (> 0 con botón, = 0 "Al día", < 0 saldo a favor);
  agrupación "Hoy"/"Ayer"/fecha; "Quedó debiendo" visible por movimiento.
- **Abono rápido:** "Todo" y "Mitad" llenan el monto; Mitad redondeada y oculta con saldo
  pequeño; tras registrar "Todo" el cliente pasa a "Al día".
- **Gasto:** cada categoría llena la descripción; combinación con texto; cambiar de categoría
  la reemplaza; "Otro" y re-toque la quitan; el gasto se guarda con la descripción.
- **Modo oscuro y letra grande:** las tres pantallas sin excepciones.

## Entrega

Rama `renovacion-r3a`; plan en `docs/superpowers/plans/`; APK al final; actualizar
`docs/hoja-de-ruta.md`.
