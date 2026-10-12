# Renovación de la interfaz — R3b: reportes, historial, corrección y cobro QR

**Fecha:** 2026-10-12
**Estado:** Implementado (falta el recorrido manual en un celular real)
**Base:** master con R1, R2a, R2b y R3a (dac61ab, 667 pruebas).

## Contexto

Segunda mitad de la R3 (pantallas de dinero). Reportes ya calcula comparación, barras por día,
ranking y hora pico, e Historial ya filtra por vendedor: la R3b es sobre todo **presentación**
al estilo de la R2a/R3a, más **filtro por tipo**, **total del filtro** y **agrupación por hora**
en el Historial. Corrección y cobro QR: solo estilo.

Sin cambios de esquema, de repositorios ni dependencias nuevas.

## 1. Reportes (`lib/screens/reportes/reportes_screen.dart`)

Se conservan el selector de periodo, la navegación ‹ › y todas las claves existentes
(`selector_periodo`, `periodo_anterior`, `titulo_periodo`, `periodo_siguiente`,
`reintentar_reporte`, `reporte_ventas`, `cambio_ventas`, `reporte_gastos`, `reporte_ganancia`,
`cambio_ganancia`, `texto_promedio`, `reporte_efectivo`, `reporte_transferencia`,
`texto_gastos_caja`, `texto_fiado`, `texto_deuda`, `texto_sin_detalle`,
`texto_ganancia_productos`, `ranking_{i}`, `texto_otros_montos`, `texto_sin_costo`,
`texto_hora_pico`).

- **Tarjeta "Ventas"** (`reporte_ventas`): fondo `tarjetaPrincipal`, radio
  `radioTarjetaPrincipal`; `Monto(ventas, 36, claro, animado)`; **etiqueta de cambio**
  (`cambio_ventas`) "▲ N % vs. semana anterior" / "▼ N % vs. mes anterior" (píldora con fondo
  `entra`/`sale` al 22 % y texto `sobreTarjetaPrincipal`, como en la R2a); si el cambio es null
  (periodo anterior en 0) no se muestra; si es 0, "Igual que la semana/el mes anterior".
  Debajo, "N ventas · promedio {monto}" (`texto_promedio`).
- **Mosaicos**: Ganancia y Gastos lado a lado (`TarjetaMonto`); la ganancia con su etiqueta
  de cambio pequeña (`cambio_ganancia`, texto `entra`/`sale` según signo, 12 px); Efectivo y
  Transferencia lado a lado.
- **Tarjeta de fiado** (`tarjeta_fiado_reporte`): "Cobraste {cobrado}" (`texto_fiado`) y
  "Deuda: {inicio} → {fin}" (`texto_deuda`) con ícono `trending_up` en `sale` si la deuda subió,
  `trending_down` en `entra` si bajó, ninguno si igual.
- **Ventas por día**: `BarrasPorDia` actual, con crecimiento animado (`Movimiento.resorte`,
  `Movimiento.larga`, respeta reducir movimiento) y el mejor día resaltado (como hoy).
- **Productos más vendidos**: hasta 5 filas (`ranking_{i}`), cada una con nombre, "N und ·
  {dinero}" y una **barra horizontal** (`barra_ranking_{i}`) cuyo ancho es
  `dinero / dinero del primero` (mínimo 4 px), color `primario` (el primero `marcaVerde`).
  "Otros montos" y "sin costo" como hoy.
- **Hora pico**: tarjeta `texto_hora_pico` "Tu hora pico: 6 p. m. · {monto}" (formato 12 h con
  "a. m."/"p. m."; 12 → "12 m.", 0 → "12 a. m.") y las barras por hora actuales con la hora pico
  resaltada.
- Secciones con `EntradaEscalonada` (índices 0..n); `.when(skipLoadingOnReload: true)`.
- Estado vacío y error: como hoy.

Función pura nueva `String horaCorta(int hora)` en `lib/util/fecha_util.dart`.

## 2. Historial (`lib/screens/historial/historial_screen.dart`)

- Arriba: `SelectorFecha` (píldora, como el Inicio) y dos filas de chips con desplazamiento
  horizontal:
  - **Tipo** (`filtro_tipo_{todo|contado|fiado|gastos}`): Todo · Contado · Fiado · Gastos.
  - **Vendedor**: los actuales (`filtro_usuario_todos`, `filtro_usuario_{id}`).
- Filtro por tipo: `contado` = ventas con `esFiado == false`; `fiado` = ventas con
  `esFiado == true`; `gastos` = gastos. Se aplica en la pantalla sobre los datos de
  `historialProvider` (que ya filtra por vendedor).
- **Tarjeta de resumen** (`resumen_historial`, reemplaza `total_ventas`/`total_gastos`):
  "Ventas {suma ventas no anuladas visibles}" (`total_ventas_filtro`), "Gastos {suma gastos no
  anulados visibles}" (`total_gastos_filtro`) y "N movimientos" (cuenta todos los visibles,
  anulados incluidos). Si el filtro es Gastos, no se muestra la línea de ventas; si es
  Contado o Fiado, no se muestra la de gastos.
- **Agrupación por hora** (más recientes primero): encabezado `horaCorta(hora)` con clave
  `hora_{h}` antes del primer movimiento de cada hora.
- **Fila** (`movimiento_{venta|gasto}_{id}`, se conserva): ícono redondo de 36 px con fondo del
  color al 15 %:
  | Tipo | Color | Ícono |
  |---|---|---|
  | Venta de contado | `entra` | `shopping_cart_rounded` (+ `EtiquetaQr` si transferencia) |
  | Venta fiada | `fiado` | `menu_book_rounded`, con el nombre del cliente |
  | Gasto | `sale` | `call_made_rounded` |
  | Anulado | `textoSecundario` | el del tipo; monto tachado |
  Detalle, vendedor y corrección como hoy; la hora ya no va a la derecha (está en el
  encabezado) y en su lugar va el `Monto`. Tocar abre la corrección como hoy.
- **Vacío según filtro** (`EstadoVacio`): Todo "Sin movimientos este día" (actual);
  Contado "Sin ventas de contado este día"; Fiado "Sin ventas fiadas este día"; Gastos "Sin
  gastos este día".
- Filas con `EntradaEscalonada` (hasta 8).

## 3. Hoja de corrección (`lib/screens/correccion/hoja_movimiento.dart`) — solo estilo

- Cabecera: ícono del tipo (misma tabla del Historial) y `Monto` de 32 en el color del tipo.
- Botones: "Corregir" `BotonPrincipal` (primario, píldora) y "Anular" variante `peligro`;
  espaciado 12/16 del tema.
- Sin cambios de flujo, textos ni claves (`boton_corregir`, `boton_anular`,
  `confirmar_anular`, `boton_guardar_correccion`, etc.).

## 4. Cobro QR (`lib/screens/qr/cobro_qr_screen.dart`) — solo estilo

- Sigue forzado a `temaClaro()` (R1).
- Monto en una tarjeta (`tarjeta_monto_qr`) con `Monto` de 44 centrado.
- QR dentro de una tarjeta blanca (`ColoresApp.blancoMarca`) con radio 24, padding 16 y sombra
  suave.
- "Recibido" (`boton_qr_recibido`) `BotonPrincipal` variante `entra`; "Cancelar"
  (`boton_qr_cancelar`) variante `contorno`. Mismos resultados (true/false).

## Fuera de alcance

Abonos en el Historial, exportar reportes, administración (R4).

## Pruebas

- `horaCorta`: 0 → "12 a. m.", 9 → "9 a. m.", 12 → "12 m.", 18 → "6 p. m.".
- **Reportes**: etiqueta de cambio con "vs. semana anterior"/"vs. mes anterior"; sin
  etiqueta si el anterior fue 0; barras del ranking proporcionales (la primera la más ancha,
  la mitad de dinero ≈ mitad de ancho); hora pico con formato 12 h; tarjeta de fiado con
  flecha según suba/baje; se mantienen las pruebas actuales.
- **Historial**: filtros de tipo (contado/fiado/gastos) combinados con vendedor; el resumen
  excluye anulados y oculta líneas según el filtro; encabezados por hora en orden; ícono por
  tipo; vacío según filtro; tocar abre la corrección.
- **Corrección y QR**: las pruebas actuales siguen pasando; cabecera de la corrección con el
  color del tipo.
- **Modo oscuro y letra grande**: Reportes, Historial, hoja de corrección y cobro QR sin
  excepciones.

## Entrega

Rama `renovacion-r3b`; plan en `docs/superpowers/plans/`; APK al final; actualizar
`docs/hoja-de-ruta.md`.
