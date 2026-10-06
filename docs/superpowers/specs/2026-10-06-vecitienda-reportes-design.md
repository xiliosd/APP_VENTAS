# Fase 3B — Reportes por semana y por mes

**Fecha:** 2026-10-06
**Estado:** Diseño aprobado, pendiente de plan
**Base:** master con Fase 1, 2A–2E, marca VeciTienda, pulido 2D y Fase 3A integradas.

## Objetivo

El dueño de la tienda ve, por semana o por mes, cómo le fue (ventas, gastos, ganancia y la
comparación con el periodo anterior), cuánto entró en efectivo y por transferencia para cuadrar
caja y banco, cómo se movió el fiado y qué días vendió más.

## Decisiones tomadas con el usuario

- **Propósitos (todos):** saber si le está yendo bien, cuadrar caja y banco, ver qué se vende
  más, controlar el fiado.
- **Productos más vendidos: fuera de esta fase.** Hoy un ticket con varios productos no guarda
  su detalle (solo `productoId` si el ticket tiene una única línea), así que un ranking saldría
  incompleto. Una fase siguiente empezará a guardar el detalle de cada ticket y agregará el
  ranking (y las horas de más venta).
- **Periodos:** Semana (lunes a domingo) y Mes (calendario), navegables hacia atrás con flechas;
  no se puede pasar del periodo actual.
- **Acceso:** solo el administrador, con un botón "Ver reportes" en Inicio (sin pestaña nueva).
- **Enfoque (B):** un `ReporteRepository` con consultas por rango que calcula todo en Dart en una
  pasada. Se descartaron reusar el resumen diario día por día (A) y sumas SQL agrupadas por día
  (C).

## Contenido del reporte

Nada anulado cuenta. Todo sale de los datos del celular, sin internet.

### Periodo

- `Semana`: de lunes 00:00 a domingo 23:59:59.999 (hora local).
- `Mes`: del día 1 al último día del mes.
- **Título:** semana "Semana del 6 al 12 oct." (si cruza de mes: "Semana del 29 sep. al 5 oct.";
  si cruza de año se agrega el año al final: "Semana del 29 dic. al 4 ene. 2027"); mes
  "Octubre 2026". Meses abreviados en minúscula con punto: ene., feb., mar., abr., may., jun.,
  jul., ago., sep., oct., nov., dic.
- **Periodo actual:** el que contiene hoy. Para él, el reporte cuenta hasta hoy (`hasta = hoy`).

### 1. ¿Cómo te fue?

- **Ventas:** suma de todas las ventas (contado + fiado) del periodo.
- **Cantidad de ventas** y **venta promedio** = ventas ÷ cantidad, redondeado al peso (0 si no
  hay ventas).
- **Gastos** y **Ganancia** = ventas − gastos (misma definición que Inicio).
- **Comparación** con el periodo anterior, en ventas y en ganancia:
  `cambio % = redondear((actual − anterior) ÷ |anterior| × 100)`. Si `anterior == 0` no hay
  porcentaje (no se muestra nada).
  - Periodo cerrado: se compara completo contra el anterior completo.
  - Periodo actual (a medias): se compara contra **los mismos días** del anterior: desde su
    inicio hasta `inicio anterior + (hoy − inicio actual)` días, sin pasar del fin del anterior
    (p. ej. 31 de marzo contra febrero llega hasta el 28 o 29).
  - Texto: "↑ 12 % vs. semana pasada" (verde) / "↓ 8 % vs. mes pasado" (rojo) / "= vs. semana
    pasada" si el cambio es 0.

### 2. Caja y banco

- **Efectivo:** ventas de contado en efectivo + abonos en efectivo del periodo.
- **Transferencia:** ventas de contado por transferencia + abonos por transferencia.
- **Gastos** del periodo.
- No se calcula "efectivo neto": los gastos no guardan con qué se pagaron.

### 3. Fiado

- **Fiaste:** suma de ventas fiadas del periodo. **Cobraste:** suma de abonos del periodo.
- **Deuda:** `deudaTotalAl(día anterior al inicio)` → `deudaTotalAl(fin o hoy si es el
  actual)`, con la función que ya existe en `FiadoRepository`.

### 4. Ventas por día

- Una fila por día del periodo hasta `hasta` (en el actual, los días futuros no aparecen):
  etiqueta ("Lun 6"), barra proporcional al día de más venta y monto.
- **Mejor día:** el de mayores ventas (empate: el primero); se resalta y se escribe
  "Mejor día: sábado 10 · $250.000". Sin ventas en el periodo no hay mejor día.

## Pantallas

### Inicio

- Debajo de las tarjetas del día, un botón "Ver reportes" (ícono de gráfica), visible solo si
  `sesion.esAdmin`. Abre `ReportesScreen`.

### Reportes (`lib/screens/reportes/reportes_screen.dart`)

AppBar blanca "Reportes" con atrás. De arriba abajo:

1. `SelectorSegmentado` Semana | Mes (al cambiar, va al periodo actual del nuevo tipo).
2. Navegador: ‹ título ›. La flecha › se deshabilita en el periodo actual.
3. **¿Cómo te fue?:** tarjeta grande Ventas con su comparación; fila con tarjetas Gastos y
   Ganancia (con su comparación); línea gris "18 ventas · promedio $12.500".
4. **Caja y banco:** tarjetas Efectivo y Transferencia (estilo de las de Inicio) y la línea de
   gastos.
5. **Fiado:** "Fiaste $40.000 · Cobraste $25.000" y "Deuda: $80.000 → $95.000".
6. **Ventas por día:** `BarrasPorDia` (`lib/screens/reportes/barras_por_dia.dart`), barras
   horizontales hechas con widgets (sin librería de gráficas); mejor día en `ColoresApp.entra`,
   los demás en `ColoresApp.entraSuave`.
7. Sin ventas ni gastos ni abonos en el periodo: `EstadoVacio` "Sin ventas en este periodo",
   con el selector y el navegador visibles.

Se recalcula sola cuando cambia la base (mismo patrón `tableUpdates()` que Inicio).

## Código

- **`lib/util/periodo.dart`:** `enum TipoPeriodo { semana, mes }` y clase inmutable `Periodo`
  (`tipo`, `inicio`) con `fin`, `anterior`, `siguiente`, `contiene(DateTime)`, `titulo`,
  `factory Periodo.actual(TipoPeriodo tipo, DateTime hoy)`, igualdad por valor (para usarlo como
  clave de provider). Lógica pura.
- **`lib/repositories/reporte_repository.dart`:**
  - `class Reporte` con `ventas`, `cantidadVentas`, `ventaPromedio`, `gastos`, `ganancia`,
    `recibidoEfectivo`, `recibidoTransferencia`, `fiado`, `cobrado`, `deudaInicio`, `deudaFin`,
    `ventasPorDia` (`Map<DateTime, int>` con cada día de `inicio` a `hasta`, incluidos los de 0),
    `mejorDia` (`DateTime?`).
  - `class ComparacionReporte` con `actual`, `anterior`, `cambioVentas` (`int?`),
    `cambioGanancia` (`int?`).
  - `ReporteRepository(AppDatabase, FiadoRepository)`:
    `Future<Reporte> reporte(DateTime desde, DateTime hasta)` (tres consultas por rango sobre
    `ventas`, `pagos_fiado` y `gastos` con `anulado = false`, más `deudaTotalAl`) y
    `Future<ComparacionReporte> comparar(Periodo periodo, {required DateTime hoy})`.
- **`lib/providers/reporte_providers.dart`:** `comparacionReporteProvider` (family por
  `Periodo`, autoDispose, escucha `tableUpdates()`).
- **Inicio** (`resumen_screen.dart`): botón "Ver reportes" solo admin.

## Pruebas (TDD)

- **Periodo:** semana de un miércoles va de lunes a domingo; semana que cruza de mes y de año
  (títulos); anterior de la primera semana de enero; febrero bisiesto (2028) y no bisiesto;
  `Periodo.actual` y que el actual no tenga siguiente navegable.
- **ReporteRepository:** totales con datos de varios días; lo anulado no cuenta; efectivo y
  transferencia igual que Inicio; fiado y cobrado; deuda al inicio y al final; días sin ventas
  en 0; mejor día y empate; periodo sin datos.
- **Comparación:** periodo cerrado contra anterior completo; periodo actual a medias contra los
  mismos días; 31 de marzo contra febrero; anterior en 0 sin porcentaje; ganancia anterior
  negativa usa el valor absoluto.
- **Pantallas:** el admin ve "Ver reportes" y el vendedor no; Semana → Mes y la flecha anterior
  cambian las cifras; › deshabilitada en el actual; estado vacío; mejor día resaltado; la
  comparación muestra ↑/↓ con el texto exacto.

## Fuera de alcance

- Ranking de productos y horas de más venta (fase siguiente, con detalle de tickets).
- Rango de fechas libre.
- Exportar o compartir el reporte.
- Reporte por vendedor.
- Efectivo neto (los gastos no guardan medio de pago).
