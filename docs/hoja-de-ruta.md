# Hoja de ruta — VeciTienda

Actualizada: 2026-10-26. Cada fase pasa por especificación (`docs/superpowers/specs/`) y plan
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
- Pulido, tanda 2 — letra grande y detalles de la marca (incluido el ícono temático).
- Pulido, tanda 3 — mejoras internas (guardados atómicos, repositorios y Reportes).
- Renovación R1 — modo oscuro "Azul noche", estilo Expressive (formas, movimiento, vibración).
- Renovación R2a — Inicio tipo tablero, Nueva venta con "¿Cómo paga?", "¿Quién eres?" y PIN renovados.
- Renovación R2b — recorrido de primer uso (tienda, primeros productos, venta de práctica guiada, guía del Inicio).
- Renovación R3a — fiado (tarjeta, buscador, orden, antigüedad, línea de tiempo, abono rápido) y gasto con categorías.
- Renovación R3b — reportes renovados, historial con filtros por tipo y por hora, corrección y cobro QR con el estilo nuevo.
- Venta: buscador fijo con ✕ y botón −/caneca en cada mosaico para restar o quitar.
- Código de barras — escanear para crear (autocompleta desde Open Food Facts) y para vender; marca, tamaño, envase y tipo para buscar y filtrar.
- Pedidos guardados y pedido recibido como gasto — "Guardar pedido" desde el pedido sugerido, sección
  "Por llegar" (editar o anular), recepción contra el pedido con faltantes, extras y precios cambiados,
  gasto "Mercancía · proveedor" de la caja y sugerencia que descuenta lo que viene en camino.
- Inicio de marca "el toldo se abre" — completo la primera vez y breve en cada arranque, se salta
  tocando, quieto con "reducir movimiento"; pantalla de carga de Android del mismo color.
- Ingreso con huella — botón "Entrar con huella" en la pantalla del PIN para quien lo activa en
  Ajustes (aviso de celular compartido y confirmación); el PIN sigue siempre; se olvida al restaurar.
- Vender por voz — micrófono en Nueva venta y en el Inicio, reconocimiento solo en el celular,
  hoja "¿Agrego esto?" con lo reconocido, lo dudoso y lo no encontrado; se suma al ticket (venta mixta).
- Ordenar productos — botón "Ordenar" en Nueva venta (A–Z, como los creé, más vendidos de 30 días) y
  en Ajustes → Productos (A–Z, como los creé); cada listado recuerda su orden; arranca en A–Z.
- Renovación R4 — administración: Ajustes con cabecera de tienda, inventario con resumen y niveles, barra de total fija al recibir y pedir, productos con buscador y margen, proveedores y usuarios con avatar y chips, respaldo y QR con el estilo nuevo.

## En curso

- Renovación terminada (R1–R4); falta el recorrido manual en un celular real.
- Mejoras de tienda (spec: `docs/superpowers/specs/2026-10-26-vecitienda-mejoras-tienda-design.md`):
  - Tanda 1 — hecha: clientes con apellido, pantalla Clientes, cliente habitual en ventas de
    contado y por transferencia, y reportes de clientes (habituales, de paso y mejores clientes).
  - Tanda 2 — hecha: letra grande (normal, grande y muy grande, guardada por celular) y
    edición de productos desde Nueva venta, escáner, inventario y Productos.
  - Tanda 3 — hecha: aviso al vender cuando un producto queda en su mínimo o se agota, franja e
    indicador "N por pedir" en el Inicio, y extracto de fiado en pantalla con consolidado por abono.
  - Tanda 4 — pendiente: escáner y recorrido.

## Después

- Consultar precio por código de barras — escanear el código de barras de un producto para ver
  su precio sin agregarlo a una venta; requiere especificación y plan antes de programarse.
- Monetización sin cobrarle al tendero (ideas presentadas el 2026-10-13): pedido digital al
  distribuidor (recomendado para empezar), promociones de marca, crédito y pagos con
  bancos/billeteras, recargas y pagos de servicios, datos agregados a escala; requiere
  sincronización con consentimiento y cumplir la Ley 1581 de 2012.
- Tienda centralizada (proyecto aparte): varios celulares en la misma tienda con un código único
  de tienda, alerta al admin cuando entra un celular nuevo, información actualizada al ingresar
  y avisos de "por pedir" en todos los celulares; requiere sincronización y cumplir la Ley 1581
  de 2012.
- Preparar para uso real: llave de firma propia, compilar con las claves de Supabase y, si se
  publica, requisitos de Play Store.

## Pendiente de verificar

- Recorrido manual en un celular real de: Cargar QR (2D), corregir y anular (3A) y reportes
  (3B), detalle de tickets (3C) y catálogo, proveedores y nombre de la tienda (4A), inventario (4B), pedido sugerido (4C), pulido tanda 1 y pulido tanda 2 (incluido el ícono temático en
  Android 13+), renovación R1 en claro y oscuro (incluida la vibración) renovación R2a, renovación R2b (recorrido completo en un celular nuevo), renovación R3a, renovación R3b, renovación R4 y código de barras con productos reales (cámara), pedidos guardados con recepción como gasto, inicio de marca (claro, oscuro, Android 12+ y anteriores), ingreso con huella (activar, entrar, bloqueo, sin huellas) venta por voz (con y sin el español
  sin conexión descargado) y orden de productos y mejoras de tienda, tanda 1 (clientes con apellido, pantalla Clientes,
  cliente habitual y reportes de clientes).
- tanda 2 en celular real (tamaño de letra en las tres opciones, editar producto desde venta, escáner, inventario y productos).
- tanda 3 en celular real (aviso por pedir al vender, Deshacer, indicador del Inicio y extracto de fiado).
