# Hoja de ruta — VeciTienda

Actualizada: 2026-10-16. Cada fase pasa por especificación (`docs/superpowers/specs/`) y plan
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
- Renovación R4 — administración: Ajustes con cabecera de tienda, inventario con resumen y niveles, barra de total fija al recibir y pedir, productos con buscador y margen, proveedores y usuarios con avatar y chips, respaldo y QR con el estilo nuevo.

## En curso

- Renovación terminada (R1–R4); falta el recorrido manual en un celular real.

## Después

- Mejoras pedidas el 2026-10-16 (planeadas, sin implementar; cada una con spec, plan, pruebas y los
  lineamientos UNIMINUTO; orden sugerido: 3 → 4; la 1 y la 2 ya están hechas).
  3. **Huella digital al ingresar** (rama `feature/ingreso-con-huella`). Paquete `local_auth`
     (versión fijada tras verificarla en pub.dev); `MainActivity` pasa a `FlutterFragmentActivity`
     y se agrega `USE_BIOMETRIC`. Cada usuario la activa en Ajustes después de ingresar con su
     PIN; en "¿Quién eres?" se ofrece la huella y el PIN queda siempre como respaldo (sin huella
     registrada, sensor bloqueado o fallos). Nada biométrico se guarda en la app: solo la marca
     "huella activada" por usuario. Riesgo: la huella es del celular, no del usuario; si varios
     comparten el celular, cualquier huella registrada abre ese usuario, así que se avisa al
     activarla.
  4. **Vender y reconocer productos por voz** (rama `feature/venta-por-voz`), en dos etapas:
     a) búsqueda por voz, el diseño aprobado el 2026-10-13: botón de micrófono en el buscador fijo
        con `speech_to_text` 7.5.0 (es-CO, hasta 8 s o 3 s de silencio), texto en vivo que filtra
        la lista, búsqueda tolerante (ignora guiones y exige todas las palabras en nombre, marca o
        tamaño), avisos sin permiso / sin reconocimiento / sin texto, permiso `RECORD_AUDIO`, sin
        guardar audio ni texto;
     b) dictar la venta ("dos coca colas y un pan"): se separa en partes por "y" y comas, se leen
        cantidades en número o palabra (un, dos… doce, media docena), cada parte se busca con el
        filtro tolerante y se muestra una hoja de confirmación con lo reconocido, lo dudoso (elegir
        entre opciones) y lo no encontrado; nada entra al ticket sin confirmar.
- Monetización sin cobrarle al tendero (ideas presentadas el 2026-10-13): pedido digital al
  distribuidor (recomendado para empezar), promociones de marca, crédito y pagos con
  bancos/billeteras, recargas y pagos de servicios, datos agregados a escala; requiere
  sincronización con consentimiento y cumplir la Ley 1581 de 2012.
- Preparar para uso real: llave de firma propia, compilar con las claves de Supabase y, si se
  publica, requisitos de Play Store.

## Pendiente de verificar

- Recorrido manual en un celular real de: Cargar QR (2D), corregir y anular (3A) y reportes
  (3B), detalle de tickets (3C) y catálogo, proveedores y nombre de la tienda (4A), inventario (4B), pedido sugerido (4C), pulido tanda 1 y pulido tanda 2 (incluido el ícono temático en
  Android 13+), renovación R1 en claro y oscuro (incluida la vibración) renovación R2a, renovación R2b (recorrido completo en un celular nuevo), renovación R3a, renovación R3b, renovación R4 y código de barras con productos reales (cámara) pedidos guardados con recepción como gasto e inicio de marca (claro, oscuro, Android 12+ y anteriores).
