# Fase 3C — Detalle de tickets, productos más vendidos y horas de venta

**Fecha:** 2026-10-07
**Estado:** Diseño aprobado, pendiente de plan
**Base:** master con Fases 1–3B (esquema v3, Reportes por semana/mes).

## Objetivo

Guardar qué productos lleva cada venta para que el dueño vea en Reportes los productos más
vendidos y las horas de más venta, y dejar ese detalle listo para que la Fase 4 descuente
existencias con cada venta.

## Decisiones tomadas con el usuario

- **Corregir también los productos:** al corregir una venta con detalle se cambian cantidades o
  se quitan líneas; el total sale de las líneas.
- **Ranking:** top 10 por unidades (empate: por dinero), con el dinero al lado; los montos
  sueltos van juntos en "Otros montos" al final.
- **Horas:** barras por franja de 1 hora, con la hora pico resaltada, reutilizando las barras de
  "Ventas por día".
- **Enfoque (A):** tabla `lineas_venta`; la venta conserva su `monto` (= suma de sus líneas).
  Se descartaron JSON dentro de la venta (B) y una venta por producto (C).
- **Ventas viejas:** no se reconstruye su detalle; el ranking se llena desde esta versión. Las
  horas sí incluyen las ventas viejas (solo dependen de la hora de cada venta).

## Modelo de datos (esquema v3 → v4)

- Tabla nueva `LineasVenta` (`@DataClassName('LineaVenta')`):
  - `id` autoincremental
  - `ventaId` → `Ventas.id`
  - `productoId` → `Productos.id`, nullable (null = monto suelto: "+ Otro" o monto rápido)
  - `descripcion`: texto tal como estaba al vender (nombre del producto o el monto formateado,
    p. ej. "$5.000")
  - `precioUnitario`: entero en pesos
  - `cantidad`: entero ≥ 1
- Migración `desde < 4`: `createTable(lineasVenta)`. No toca datos; las ventas existentes
  quedan sin líneas. `CopiaBaseDatos.tablas` no cambia.
- Invariante: si una venta tiene líneas, `venta.monto == Σ precioUnitario × cantidad`.

## Reglas

- **Registrar:** venta y líneas en una sola transacción, desde las líneas del ticket. Si se
  pasan líneas y el monto no es su suma, se rechaza.
- **Deshacer tras cobrar:** borra líneas y venta en una transacción.
- **Corregir una venta con detalle:**
  - Se cambian cantidades (− / +) o se quitan líneas; no se agregan productos (para eso se
    anula y se registra de nuevo).
  - El total se recalcula con las líneas; debe quedar al menos una línea (si no, Guardar
    deshabilitado con "Para quitar todo, anula la venta"; el repositorio también lo rechaza).
  - Contado/Fiado, cliente y medio de pago se corrigen como hoy.
  - El texto `antes` agrega los productos: "$8.000 · Contado · Efectivo · 2× Arepa, 1×
    Cocacola 400 ml" (montos sueltos como "1× $5.000").
  - Todo (líneas, venta y fila de `correcciones`) en una transacción.
- **Corregir una venta sin detalle (vieja):** igual que hoy, con el teclado de monto.
- **Anular:** las líneas quedan guardadas; todo lo que suma las excluye por la venta anulada.
- **Ranking:** agrupa líneas de producto por `productoId` y muestra el **nombre actual** del
  producto (un renombre no parte el historial); un producto desactivado sigue saliendo si se
  vendió en el periodo. Unidades = Σ cantidad; dinero = Σ precioUnitario × cantidad. Orden:
  unidades desc, luego dinero desc, luego nombre. Máximo 10. "Otros montos" = dinero de las
  líneas sin producto.
- **Horas:** ventas no anuladas del periodo agrupadas por la hora local de `fecha` (0–23),
  sumando el monto. Hora pico = la de más dinero (empate: la más temprana).

## Pantallas

### Registrar venta

Sin cambios visibles; al cobrar se guardan las líneas del ticket.

### Hoja de movimiento (Historial y Fiado)

- **Detalle:** bajo el monto, si la venta tiene líneas, una por fila: "2× Arepa · $7.000",
  "1× $5.000".
- **Corregir una venta con detalle:** en vez del teclado de monto, la lista de líneas con
  botones − / + y quitar; el total se recalcula en vivo. Tipo, cliente y medio de pago como
  hoy. Sin líneas: Guardar deshabilitado y el texto "Para quitar todo, anula la venta".
- **Corregir una venta sin detalle:** igual que hoy.

### Reportes (después de "Ventas por día")

1. **Productos más vendidos:** hasta 10 filas "1. Arepa · 42 u · $147.000"; al final
   "Otros montos · $85.000" si los hubo. Sin líneas en el periodo: texto gris "Aún no hay
   ventas con detalle de productos en este periodo".
2. **Horas de más venta:** "Hora pico: 6 p. m. · $85.000" y barras de las horas con ventas,
   ordenadas de la mañana a la noche, etiquetas "7 a. m.", "12 m.", "6 p. m.". El widget de
   barras se generaliza (`Barras`, filas con etiqueta, valor y llave) y lo usan los días y las
   horas.

## Código

- `lib/data/database.dart`: tabla `LineasVenta`, `schemaVersion = 4`, migración.
- `VentaRepository`:
  - `registrarVenta(..., List<LineaNueva> lineas = const [])` con
    `class LineaNueva { int? productoId; String descripcion; int precioUnitario; int cantidad; }`.
  - `Future<List<LineaVenta>> lineasDeVenta(int ventaId)`.
  - `eliminarVenta` borra también las líneas.
- `CorreccionRepository.corregirVenta(..., Map<int, int>? cantidades)`: id de línea → nueva
  cantidad (0 = quitar). Con líneas, el monto se recalcula y el parámetro `monto` se ignora.
- `ReporteRepository`: `Reporte` gana `ranking` (`List<ProductoVendido>` con `productoId`,
  `nombre`, `unidades`, `dinero`), `otrosMontos`, `ventasPorHora` (`Map<int, int>`, solo horas
  con ventas, ordenado) y `horaPico` (`int?`).
- Pantallas: registrar venta pasa las líneas; `HojaMovimiento` carga las líneas (provider por
  `ventaId`) y edita cantidades; `ReportesScreen` agrega las dos secciones; `Barras` genérico.

## Pruebas (TDD)

- Migración v3 → v4 (y v2/v1 → v4 siguen funcionando).
- Registrar con líneas: se guardan; monto descuadrado rechazado; Deshacer borra las líneas.
- Corregir: cambiar cantidades recalcula el monto; quitar todas rechazado; `antes` con
  productos; venta sin detalle se corrige por monto como hoy; transacción (si falla, nada
  cambia).
- Ranking: orden por unidades y empate por dinero; "Otros montos" aparte; anulado no cuenta;
  producto renombrado agrupa su historial; corte en 10.
- Horas: agrupación por hora local, hora pico y empate.
- Pantallas: cobrar un ticket de dos productos guarda dos líneas; la hoja muestra el detalle y
  corrige cantidades; Reportes muestra ranking, mensaje sin detalle y hora pico.

## Fuera de alcance

- Agregar productos a una venta en la corrección.
- Reconstruir el detalle de ventas viejas.
- Existencias, precio de compra y proveedores (Fase 4).
