# Hoja de ruta — VeciTienda

Actualizada: 2026-10-07. Cada fase pasa por especificación (`docs/superpowers/specs/`) y plan
(`docs/superpowers/plans/`) antes de programarse.

## Hecho

- Fase 1 — ventas, fiado, gastos, PIN, historial.
- Fase 2A–2E — mejoras, respaldo en Supabase, UX, cobro por QR; marca VeciTienda.
- Fase 3A — corregir y anular ventas, abonos y gastos.
- Fase 3B — reportes por semana y por mes.
- Fase 3C — detalle de tickets, productos más vendidos y horas de venta.
- Fase 4A — catálogo, proveedores, ganancia por producto y nombre de la tienda.
- Fase 4B — existencias, recibir mercancía, ajustes por conteo y "Por pedir".

## En curso

- Siguiente: Fase 4C (pedidos por proveedor).

## Siguiente

- **Fase 4 — Productos, inventario y proveedores** (pedido del usuario, 2026-10-07):
  - Modificar productos con más datos: precio de venta (ya existe, junto con editar nombre y
    desactivar), precio de compra y proveedor.
  - Proveedores: crear y editar (nombre, teléfono).
  - Existencias por producto, que bajan con cada venta (gracias al detalle de la 3C) y suben al
    recibir mercancía.
  - Productos que se van terminando: un mínimo por producto y una lista de lo que hay que
    pedir.
  - Preparar pedidos por proveedor: armar el pedido con lo que falta de ese proveedor (y
    poder enviarlo, por ejemplo por WhatsApp).
  - Con el precio de compra, la ganancia por producto en Reportes.
  - Probablemente se divide en subfases (catálogo y proveedores → existencias y alertas →
    pedidos); se decide en su lluvia de ideas.

## Después

- Recordatorios de fiado por WhatsApp.
- Pulido acumulado: 6 menores de la 3A, 5 de la 3B y 7 detalles visuales de la marca (ver
  `docs/marca/vecitienda-marca.md` y los commits de cada fase).
- Preparar para uso real: llave de firma propia, compilar con las claves de Supabase y, si se
  publica, requisitos de Play Store.

## Pendiente de verificar

- Recorrido manual en un celular real de: Cargar QR (2D), corregir y anular (3A) y reportes
  (3B), detalle de tickets (3C) y catálogo, proveedores y nombre de la tienda (4A) e inventario (4B).
