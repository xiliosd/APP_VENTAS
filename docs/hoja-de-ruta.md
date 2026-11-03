# Hoja de ruta — VeciTienda

Actualizada: 2026-10-30. Cada fase pasa por especificación (`docs/superpowers/specs/`) y plan
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
- Mejoras de tienda (spec: `docs/superpowers/specs/2026-10-26-vecitienda-mejoras-tienda-design.md`):
  - Tanda 1 — hecha: clientes con apellido, pantalla Clientes, cliente habitual en ventas de
    contado y por transferencia, y reportes de clientes (habituales, de paso y mejores clientes).
  - Tanda 2 — hecha: letra grande (normal, grande y muy grande, guardada por celular) y
    edición de productos desde Nueva venta, escáner, inventario y Productos.
  - Tanda 3 — hecha: aviso al vender cuando un producto queda en su mínimo o se agota, franja e
    indicador "N por pedir" en el Inicio, y extracto de fiado en pantalla con consolidado por abono.
  - Tanda 4 — hecha: escáner fácil (botón "Escanear código" con texto, consejos de primera
    vez, ayuda en el escáner) y escáner en el recorrido ("Crear escaneando" y "Vender
    escaneando").
- Consultar precio y preguntas frecuentes (spec: `docs/superpowers/specs/2026-10-31-vecitienda-consultar-precio-y-preguntas-design.md`):
  botón "Consultar precio" sobre la barra del Inicio (escanea y muestra el precio sin tocar la
  venta; si el código no está, deja agregar el producto), globo nuevo en el recorrido, y
  "Preguntas frecuentes" de toda la app (9 temas, 51 preguntas) desde Ajustes → AYUDA y desde el
  menú de cuenta.

## Orden de lo que falta

Orden elegido por el usuario el 2026-10-30 y ajustado el 2026-11-03 (el vendedor entra al plan; solo
la monetización y la subida a Play Store quedan para después).

1. Vibración — diagnosticada: en el celular de prueba (Redmi Note 13, HyperOS 2, Android 15)
   la "respuesta háptica" del sistema está apagada (`haptic_feedback_enabled=0`) y la app,
   por diseño, la respeta.
2. Arreglos y orden de la casa — los detalles menores diferidos de cada tanda y el README con
   las once secciones de los lineamientos. Revisados el 2026-10-30: 36 de 74 ya estaban resueltos.
   - README con las once secciones — hecho.
   - Tanda A (inventario y pedidos) — hecha: confirmar antes de reemplazar lo escrito al recibir,
     no quedarse cargando si falla el pedido, errores claros al editar un pedido por llegar,
     precio de compra al agregar productos al pedido, número de la franja "por pedir" al día y
     vacío del pedido sugerido sin proveedor. Fuera de alcance: comparación de una entrada
     anulada con su pedido, `LineaInicial` y la venta en el mismo segundo de un conteo.
   - Tanda B (venta, escáner y voz) — hecha: linterna oculta sin cámara, cámara en pausa al
     escribir un código, código escrito con letras, aviso al dar Enter con un código que no
     existe, filtro de tipo que no se atasca, consejos marcados al cerrarlos, foco en Nombre si
     la consulta no lo trae, marcas vacías ignoradas, dictado que ignora "unos/unas", entiende
     mejor los plurales y no arranca dos veces, "Cantidad: N" para el lector de pantalla,
     "¿Quién compra?" una sola vez y fila quitada estable. Fuera de alcance: "1/2" en el dictado.
     Por verificar en el celular: pausa de la cámara y linterna.
   - Tanda C (huella, clientes, mensajes de error claros y orden interno) — hecha: botón de
     huella que no se traba y aviso de sensor ocupado, sin destello "Debe desde hoy", "Ver
     extracto" desde Clientes, "No se pudo cargar · Cierra la app y vuelve a abrirla" en lugar
     de errores técnicos (13 lugares, con una prueba que lo vigila), nombres de proveedor sin
     espacios dobles, cambio de sesión sin fundido y orden interno (ciclo de imports y
     comparador único). Fuera de alcance: `_yaMostrada` en la pantalla raíz.
   - Paso 2 completo el 2026-10-31.
3. Consultar precio por código de barras — hecho el 2026-10-31, junto con las preguntas
   frecuentes.
4. Preparar para uso real — hecho el 2026-11-03: llave de firma propia y claves de Supabase
   (respaldo en la nube).
   - Llave de firma — hecha el 2026-11-03: identificador `com.vecitienda.app` y APK release
     firmado con `android/vecitienda.jks` (fuera de git). Al pasar del APK viejo al nuevo en el
     celular, sacar respaldo antes, porque se instala como otra app.
   - Claves de Supabase — hechas el 2026-11-03: proyecto creado por el usuario, claves en
     `dart_defines.json` (fuera de git) y el ingreso al respaldo pasa de SMS a correo con código
     (gratis, sin proveedor de SMS). Correo enviado con SMTP propio (Gmail); las plantillas
     "Magic Link" y "Confirm signup" deben llevar `{{ .Token }}`, porque un correo ya
     confirmado recibe la de "Magic Link". Gmail tiene un tope diario de envíos: para muchos
     tenderos conviene un proveedor de correo (p. ej. Resend o Brevo).
5. El vendedor — decidido por el usuario el 2026-11-03; lo que queda pasa al paso 6:
   - Permisos de inventario — cerrado sin cambios: el vendedor es de confianza y maneja las
     finanzas, así que recibir mercancía, ajustar conteos y guardar pedidos siguen abiertos.
   - Huella y recorrido para el vendedor — pasan al paso 6, porque el vendedor usará su propio
     celular.
6. Tienda centralizada — necesita Supabase listo del paso 4: varios celulares en la misma tienda
   con un código único de tienda, alerta al admin cuando entra un celular nuevo, información
   actualizada al ingresar y avisos de "por pedir" en todos los celulares; requiere
   Diseño: `docs/superpowers/specs/2026-11-03-vecitienda-tienda-compartida-design.md`,
   en 4 entregas (E1 identificadores globales, E2 nube y sincronización del admin, E3 entrada
   y salida del vendedor, E4 huella, recorrido y avisos).
   - E1 — identificadores globales: hecho el 2026-11-03 (base v11, `id_global` en 15 tablas).
   sincronización y cumplir la Ley 1581 de 2012. Incluye lo que viene del paso 5:
   - Huella del vendedor — que la active él mismo desde su cuenta en su celular (hoy el
     interruptor solo está en Ajustes, que ve el administrador).
   - Recorrido del vendedor — al abrir la app por primera vez en su celular (hoy el recorrido de
     primer uso solo lo ve el administrador, así que el globo de "Consultar precio" no le llega).
7. Prueba en celular de lo que falta — compilar un APK y probar R3a, R3b, R4, las tandas 1 a 4
   de mejoras de tienda y lo nuevo de los pasos 2 a 6 (ver "Pendiente de verificar").

## Después

- Subida a Play Store — cuenta de desarrollador, política de privacidad (Ley 1581 de 2012),
  ficha de la tienda y paquete `.aab` firmado con la llave del paso 4.
- Monetización sin cobrarle al tendero (ideas presentadas el 2026-10-13): pedido digital al
  distribuidor (recomendado para empezar), promociones de marca, crédito y pagos con
  bancos/billeteras, recargas y pagos de servicios, datos agregados a escala; requiere
  sincronización con consentimiento y cumplir la Ley 1581 de 2012.

## Verificado en celular real

- 2026-11-03, por el usuario: respaldo en la nube con el proyecto real de Supabase (ingreso con
  código por correo, subir copia, borrar datos de la app y restaurar, entrar con el PIN).
- 2026-10-30, por el usuario: ingreso con huella, cobro por QR (2D), corregir y anular (3A),
  reportes (3B), detalle de tickets (3C), catálogo (4A), inventario (4B), pedido sugerido (4C),
  modo oscuro (R1), recorrido de primer uso (R2b), inicio de marca, venta por voz y orden de
  productos; después, proveedores y nombre de la tienda (4A), pulido tandas 1 y 2, renovación
  R2a, código de barras con productos reales y pedidos guardados con recepción como gasto.
- 2026-10-13, por el usuario: cámara del código de barras.

## Falla en celular real

- Vibración (R1): no se siente en el celular. La app usa `HapticFeedback` de Flutter, que
  respeta la "respuesta háptica" del sistema; en el celular de prueba está apagada
  (`haptic_feedback_enabled=0`, leído por adb el 2026-10-30).

## Pendiente de verificar

- E1 (identificadores globales): instalar el APK sobre la app actual y confirmar que ventas,
  fiado, inventario y reportes se ven igual y que el respaldo sigue subiendo.
- Renovación R3a (fiado y gastos), R3b (reportes, historial con filtros, corrección y cobro QR
  renovados) y R4 (administración).
- Mejoras de tienda, tanda 1 (clientes con apellido, pantalla Clientes, cliente habitual y
  reportes de clientes).
- Mejoras de tienda, tanda 2 (tamaño de letra en las tres opciones, editar producto desde venta,
  escáner, inventario y productos).
- Mejoras de tienda, tanda 3 (aviso por pedir al vender, Deshacer, indicador del Inicio y
  extracto de fiado).
- Mejoras de tienda, tanda 4 (botón "Escanear código", consejos de primera vez, ayuda en el
  escáner y "Crear/Vender escaneando" en el recorrido).
- Consultar precio (producto activo, inactivo y desconocido; agregar desde la consulta; globo del
  recorrido) y preguntas frecuentes (desde Ajustes y desde el menú de cuenta, con letra grande).
