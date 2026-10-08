# Hoja de ruta — VeciTienda

Actualizada: 2026-10-08. Cada fase pasa por especificación (`docs/superpowers/specs/`) y plan
(`docs/superpowers/plans/`) antes de programarse.

## Hecho

- Fase 1 — ventas, fiado, gastos, PIN, historial.
- Fase 2A–2E — mejoras, respaldo en Supabase, UX, cobro por QR; marca VeciTienda.
- Fase 3A — corregir y anular ventas, abonos y gastos.
- Fase 3B — reportes por semana y por mes.
- Fase 3C — detalle de tickets, productos más vendidos y horas de venta.
- Fase 4A — catálogo, proveedores, ganancia por producto y nombre de la tienda.
- Fase 4B — existencias, recibir mercancía, ajustes por conteo y "Por pedir".
- Fase 4C — pedido sugerido por proveedor (sin envío ni historial, por decisión del usuario).
- Pulido, tanda 1 — 18 detalles visibles de las fases 3A–4C.

## En curso

- Pulido, tandas 2 (letra grande y marca) y 3 (mejoras internas).

## Siguiente

- Pulido, tanda 2 — textos que se parten con letra grande (barras de reportes, etiquetas de
  hora, encabezado de Inicio, botón del pedido) y 7 detalles visuales de la marca (ver
  `docs/marca/vecitienda-marca.md`).
- Pulido, tanda 3 — mejoras internas sin efecto visible (transacciones, providers, consultas
  repetidas, guardado atómico del producto).

## Después

- Recordatorios de fiado por WhatsApp.
- Preparar para uso real: llave de firma propia, compilar con las claves de Supabase y, si se
  publica, requisitos de Play Store.

## Pendiente de verificar

- Recorrido manual en un celular real de: Cargar QR (2D), corregir y anular (3A) y reportes
  (3B), detalle de tickets (3C) y catálogo, proveedores y nombre de la tienda (4A), inventario (4B), pedido sugerido (4C) y pulido tanda 1.
