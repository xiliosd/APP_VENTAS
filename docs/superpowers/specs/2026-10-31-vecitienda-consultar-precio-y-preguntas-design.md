# Consultar precio y preguntas frecuentes — diseño

Fecha: 2026-10-31. Paso 3 de `docs/hoja-de-ruta.md` → "Orden de lo que falta".

## Intención

Un vendedor nuevo no conoce los precios. Cuando un cliente pregunta "¿cuánto vale esto?", hoy la
única forma de saberlo es abrir "+ Venta" y escanear, y eso mete el producto al ticket aunque el
cliente no lo vaya a comprar. El usuario quiere que **consultar el precio sea una acción aparte de
la venta**, de fácil acceso desde el Inicio. Además pidió que la consulta aparezca en el recorrido
de primer uso y un botón de **preguntas frecuentes de toda la app** en Ajustes.

## Objetivos

1. Botón "Consultar precio" en el Inicio, siempre visible y con texto.
2. Escanear (o escribir) un código y ver nombre, precio, marca y tamaño sin tocar ninguna venta.
3. Si el código no está en los productos, decirlo y permitir agregar el producto.
4. Un globo del recorrido de primer uso que enseñe el botón.
5. Pantalla de preguntas frecuentes de toda la app, abierta desde Ajustes → AYUDA.

## No objetivos

- Pasar el producto consultado a una venta ("me lo llevo"): el usuario pidió que la consulta quede
  aparte; para vender se usa "+ Venta" como siempre.
- Consultar por nombre o buscar sin código (eso ya lo hace el buscador de la venta).
- Mostrar existencias, costo o margen en la consulta (el vendedor no debe ver el costo).
- Preguntas frecuentes en línea, con búsqueda, videos o contenido descargado.

## Anti-objetivos (sería un fracaso aunque funcione)

- Que consultar agregue algo a un ticket o cambie un borrador de venta abierto.
- Que el vendedor vea el precio de compra o la ganancia.
- Un botón que el vendedor nuevo no entienda (solo ícono, sin texto).
- Preguntas frecuentes que describan cosas que la app no hace o con pasos equivocados.

## Lo que decidió el usuario

- La consulta va aparte de la venta.
- Entrada en el Inicio, de fácil acceso: **opción B** del boceto, un botón con texto
  "Consultar precio" (con ícono de etiqueta) justo encima de la barra fija "+ Venta / micrófono / − Gasto",
  siempre visible sin desplazar.
- Código que no existe: decirle que **el código aún no está en el listado de productos** y
  **permitirle agregar el producto**.
- Aparece en el recorrido de primer uso.
- Botón de preguntas frecuentes en la configuración (Ajustes), sobre **toda la app**.
- Las preguntas y respuestas las redacta Claude a partir de lo que la app hace hoy; el usuario las
  revisa.

## Comportamiento

### Consultar precio

1. "Consultar precio" en el Inicio lo ven todos los usuarios (administrador y vendedor).
2. Al tocarlo se abre directamente el escáner existente (`EscanerScreen` vía `lectorCodigoProvider`),
   con un uso nuevo `UsoEscaner.consulta` cuya ayuda dice qué pasará:
   "Te muestro el precio; no se agrega a ninguna venta". "Escribir código" y la linterna funcionan
   como siempre.
3. Producto activo encontrado → hoja inferior con nombre, **precio grande** (formato COP), y marca y
   tamaño si los tiene. Botones: "Consultar otro" (vuelve a abrir el escáner) y "Listo" (vuelve al
   Inicio). El administrador ve además "Editar producto", igual que en la venta.
4. Código no encontrado → la hoja dice "Este código aún no está en tus productos" y ofrece
   "Agregar producto", que abre la hoja rápida existente (`mostrarHojaProductoRapido`, con
   autocompletado de Open Food Facts) con el texto de guardar "Guardar". Al guardar, la hoja de
   consulta muestra el producto recién creado con su precio. Cualquier usuario puede agregar, igual
   que hoy desde la venta.
5. Producto inactivo → la hoja dice "Este producto está inactivo" con su nombre, y que el
   administrador lo reactiva en Productos; no muestra precio para vender.
6. Cancelar el escáner sin leer nada vuelve al Inicio sin mensajes.
7. Nada de esto toca `ticketProvider` ni ninguna venta.

### Recorrido de primer uso

- En `globosInicio` se agrega un paso que señala el botón (objetivo con id propio, envuelto en
  `ObjetivoRecorrido`), después del de "+ Venta": "¿Te preguntan cuánto vale algo? Escanéalo aquí
  y ves el precio sin vender."

### Preguntas frecuentes

- Ajustes es solo del administrador, así que la pantalla nueva se abre desde dos lugares (decisión
  del usuario): Ajustes → AYUDA, con la opción "Preguntas frecuentes" debajo de "Ver el recorrido
  otra vez", y el menú de cuenta del Inicio (`menu_cuenta`, donde están "Apariencia" y "Cerrar
  sesión"), que ven todos los usuarios, también el vendedor.
- Las respuestas que solo aplican al administrador (Ajustes, inventario, usuarios, respaldo) lo
  dicen al empezar ("Solo el administrador: …").
- Contenido estático en la app (sin internet), agrupado por tema: Ventas, Fiado y clientes,
  Gastos, Inventario y pedidos, Reportes, Productos y escáner, Cuenta y seguridad (PIN, huella,
  usuarios), Respaldo, Apariencia (letra, modo oscuro). Cada pregunta se abre y cierra
  (expansible) y la respuesta es corta y en pasos, con los nombres de botones tal como aparecen
  en pantalla.
- Debe leerse bien con letra muy grande y en modo oscuro, y ser accesible con lector de pantalla.

## Restricciones

- Lineamientos del proyecto (`~/.claude/CLAUDE.md`), con las excepciones de proyecto personal
  (sin Docker, trabajo directo en `master`).
- Sin dependencias nuevas ni cambios de esquema de base de datos.
- Textos en español de Colombia, tuteo, sin tecnicismos; colores con `ColoresApp`.
- WCAG 2.1 AA: botón con texto, contraste, foco y semántica; letra 2,0× sin desbordes.
- La barra fija del Inicio y el nuevo botón no deben tapar contenido del tablero (el tablero
  reserva el espacio).

## Decisiones de Claude (revisables)

- Uso nuevo del escáner `UsoEscaner.consulta` con su propio texto de ayuda.
- Producto inactivo: se dice y no se muestra precio para vender.
- El administrador puede editar el producto desde la hoja de consulta, como en la venta.
- Un código con varios productos sigue la regla actual de `productoPorCodigo`: el activo primero.
- El tablero del Inicio reserva el alto del botón nuevo para que nada quede tapado.

## Lo que queda a criterio de quien construye

- Componentes exactos de la hoja de consulta y del botón (reutilizar `BotonPrincipal`,
  `mostrarHojaInferior`, `EstadoVacio`, `ObjetivoRecorrido`).
- Cómo se organiza el contenido de las preguntas en código (lista constante en un archivo propio
  es lo esperado).
- El número exacto de preguntas: cubrir las tareas diarias de cada tema sin llenar de relleno.
