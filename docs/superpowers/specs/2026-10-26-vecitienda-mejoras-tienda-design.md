# VeciTienda — Mejoras de tienda (grupo local)

Fecha: 2026-10-26. Rama: `feature/mejoras-tienda` (sale de `feature/arreglo-dictado-idioma`,
que aún no está en `master`). Aplica los lineamientos UNIMINUTO v1.2.

## Contexto

El usuario pidió el 2026-10-26 siete mejoras. Se dividieron en dos proyectos:

- **Grupo local (este documento):** mejoras que viven en cada celular.
- **Tienda centralizada (después, diseño propio):** varios celulares de la misma tienda con
  la información compartida, ingreso con el código único de la tienda, alerta al admin cuando
  entra un celular nuevo y avisos de "por pedir" en todos los celulares. La tienda de ejemplo
  tiene dos trabajadores en turnos separados, cada uno con su celular, y la información debe
  actualizarse cada vez que alguien entra. El admin puede ser también vendedor. Se agrega a
  `docs/hoja-de-ruta.md` como siguiente proyecto.

Este grupo debe dejar los datos listos para sincronizar después (clientes identificables),
sin construir nada de nube.

## Metas

1. Clientes con nombre y apellido, con aviso de posibles duplicados por nombre o teléfono.
2. Tamaño de letra propio de la app (modo accesibilidad).
3. Cliente habitual o de paso en ventas de contado, con reportes de mezcla y de mejores clientes.
4. Aviso al vender cuando un producto queda en su mínimo o se agota.
5. Editar productos desde donde uno está (solo el admin).
6. Extracto de fiado por cliente, con consolidado después de cada abono, para mostrar en pantalla.
7. Escáner que se entiende sin conocer el ícono, y escáner dentro del recorrido inicial.

## No metas

- Sincronización, código de tienda, notificaciones entre celulares (proyecto siguiente).
- PDF, imagen o impresión del extracto (más adelante, decisión del usuario).
- Modo de alto contraste (sugerido para después).
- Promociones a mejores clientes: este grupo solo da el ranking; las promociones no se diseñan.
- Notificaciones del sistema Android con la app cerrada.

## Anti-metas (fallaría aunque "funcione")

- Que la venta en el mostrador se vuelva más lenta: marcar al cliente es **opcional** y la
  venta de contado se cierra con los mismos toques de hoy.
- Bloquear al vendedor ante un posible duplicado: la app **informa y el vendedor decide**.
- Perder o deformar clientes, ventas o fiados existentes en la migración.
- Mostrar al vendedor opciones de edición que no puede usar.
- Que el reporte haga pasar las ventas sin marcar por ventas a turistas sin decirlo.

## 1. Clientes con nombre y apellido

Decisiones del usuario: nombre y apellido obligatorios al crear; teléfono opcional; si ya
existe alguien igual, **informar para que el vendedor defina**.

- Base de datos: `Clientes` gana la columna `apellido` (texto, nullable para los clientes que
  ya existen). Migración a la versión 10 sin tocar los datos existentes; `nombre` sigue
  guardando el nombre. Nombre visible: "nombre apellido" (o solo nombre si no hay apellido).
- Crear cliente (desde `SelectorCliente` en fiado, en la venta de contado y desde Fiado) pide
  nombre y apellido por separado, ambos obligatorios, y teléfono opcional (10 dígitos de
  celular colombiano, validado).
- Comparación de duplicados: sin distinguir mayúsculas, tildes ni espacios repetidos o en los
  extremos, sobre el nombre completo. Teléfono: comparación por dígitos.
- Si coincide el nombre completo **o** el teléfono con otro cliente: hoja "Ya existe un cliente
  parecido" con sus datos (nombre, teléfono, deuda actual) y dos acciones: **Usar este
  cliente** o **Crear otro de todas formas**. Decisión mía: el teléfono repetido avisa y no
  bloquea, porque en una casa pueden compartir número.
- `ClienteRepository.obtenerOCrearCliente` (hoy reutiliza en silencio por nombre) deja de
  usarse para crear desde la interfaz; el flujo pasa siempre por la verificación. Sus llamadas
  actuales: cobro fiado en `registrar_venta_screen.dart` y `corregirVenta` con `clienteNuevo`
  en `correccion_repository.dart`; ambas pasan a nombre + apellido con verificación.
- Momento de creación (decisión mía): como hoy, el cliente nuevo se crea al cobrar, no al
  llenar el formulario; la verificación de duplicados ocurre al confirmar el nombre en el
  selector, antes de cobrar. Crear un cliente nuevo en fiado suma el campo de apellido; es
  inherente al pedido del usuario. Elegir un cliente existente sigue igual de rápido.
- **Pantalla "Clientes" nueva** (decisión del usuario, opción A): hoy no existe ningún lugar
  para crear o editar clientes, y los habituales de solo contado no aparecen en Fiado.
  - Lista de **todos** los clientes (habituales y de fiado), con buscador por nombre, apellido
    o teléfono, y orden A–Z.
  - Crear cliente (con la verificación de duplicados) y editar nombre, apellido, teléfono y
    notas. El detalle muestra lo que compró (contado y fiado, por fecha) y la deuda actual,
    con acceso al extracto (punto 6) si tiene fiado.
  - Entrada: desde el Inicio (junto a Fiado) y desde Ajustes. Sin eliminar ni fusionar
    clientes en esta tanda.
  - Permisos (decisión del usuario): admin y vendedor pueden crear y editar los datos de los
    clientes.
- Clientes existentes sin apellido: nada se bloquea; al editarlos en "Clientes" el apellido
  es obligatorio para guardar. La lista los marca con "Falta apellido".
- Datos personales (Ley 1581): nombre y teléfono no aparecen en logs.

## 2. Modo accesibilidad: tamaño de letra

Decisión del usuario: para cualquier tendero, joven o mayor, con limitaciones de vista.

- En la hoja de Apariencia (`hoja_apariencia.dart`, junto a claro/oscuro): "Tamaño de letra"
  con **Normal (1,0×)**, **Grande (1,3×)** y **Muy grande (1,6×)**. Se guarda por celular, como
  el tema.
- Se multiplica sobre la escala del sistema, con tope total de 2,0×. La app ya adapta varias
  pantallas a `MediaQuery.textScalerOf`; el tope evita romper el resto.
- Arreglar el desborde conocido del Inicio a 2,0× en 360 dp (`docs/hoja-de-ruta.md`, Después)
  y probar las pantallas principales (Inicio, Nueva venta, ¿Cómo paga?, Fiado, extracto) a
  2,0× en 360 dp sin desbordes.
- Accesible también desde el recorrido inicial no es necesario; basta Apariencia. Decisión mía.

## 3. Cliente habitual o de paso

Decisiones del usuario: sirve para saber quiénes son los mejores clientes y si se vende más a
turistas; marcarlo es **opcional**; si nadie elige, la venta es "de paso".

- En "¿Cómo paga?" (`hoja_como_paga.dart`), para Efectivo y Transferencia/QR: una línea
  opcional "¿Quién compra? De paso · Elegir cliente" que abre el mismo `SelectorCliente` (con
  la creación del punto 1). Sin tocarla, la venta se cierra igual que hoy. Decisión mía:
  aplica a todo medio de contado, no solo efectivo.
- Base de datos: se reutiliza `Ventas.clienteId`, que ya existe y es nullable. Venta de
  contado con `clienteId` = habitual; sin `clienteId` = de paso o sin marcar. No hace falta
  columna nueva.
- El ticket muestra el cliente elegido. Hoy `ticket_provider` borra el cliente al apagar el
  fiado y `corregirVenta` pone `clienteId` en null en toda venta de contado: ambos cambian para
  conservar el cliente habitual. La corrección (3A) permite cambiarlo o quitarlo, y su chequeo
  de "nada cambió" incluye el cliente. Fiado → contado conserva el cliente como habitual
  (decisión mía).
- Reportes (semana/mes): tarjeta "¿A quién le vendo?" con el porcentaje y monto vendido a
  **clientes habituales** vs **de paso o sin marcar** (texto literal, para no engañar), y
  "Mejores clientes": top 10 por monto comprado en el periodo, sumando contado y fiado, sin
  ventas anuladas. Solo admin, como el resto de Reportes.

## 4. Aviso de producto por pedir o agotado

Decisión del usuario: al momento de la venta. El aviso "en todos los celulares" queda para la
tienda centralizada.

- Solo productos con control de existencias. Al confirmar una venta, para cada producto que
  **cruzó** hacia su mínimo o por debajo (estaba por encima antes de la venta) o llegó a cero:
  aviso con texto "Quedan N <producto>: toca pedir" o "Se agotó <producto>", y botón "Ver por
  pedir" que abre Inventario en "Por pedir". Varios productos: un solo aviso con la lista. No
  se repite en ventas siguientes del mismo producto mientras siga bajo el mínimo.
- Dónde (decisión mía): hoy, al cobrar, sale un snackbar con "Deshacer" y se vuelve al Inicio.
  El aviso es una franja (`MaterialBanner` o equivalente del sistema de diseño) en el Inicio,
  no bloqueante, que queda hasta que se cierra o se toca "Ver por pedir". Si el vendedor toca
  "Deshacer", el aviso se recalcula y desaparece si ya no aplica. No agrega toques a la venta.
- Inicio: indicador "N por pedir" visible para todos los usuarios al entrar al turno; al
  tocarlo, abre "Por pedir". Se reutiliza el cálculo de `InventarioRepository.porPedir()` tal
  cual (cuenta los productos en o bajo el mínimo aunque ya estén pedidos, igual que la lista).
- Se oye/vibra como los demás avisos de la app (respetando "reducir movimiento").

## 5. Editar productos más fácil

Decisión del usuario: solo el admin edita.

Hoy la única entrada es Ajustes → Productos (Ajustes solo lo ve el admin), y el usuario no la
encontró. Para el admin, el editor existente (`ProductoScreen` con `producto`) se abre además
desde:

- Nueva venta: mantener presionado un mosaico de producto → menú con "Editar producto".
  Al volver, el ticket refleja el precio nuevo solo para productos aún no agregados (decisión
  mía: lo ya agregado al ticket conserva su precio).
- Detalle de producto en Inventario: botón "Editar".
- Escáner en Nueva venta, cuando el código ya existe: el producto se agrega como hoy y el
  snackbar de confirmación lleva la acción "Editar" (decisión mía, para no sumar toques).
- Ajustes → Productos: cada fila muestra un ícono de lápiz con `tooltip` "Editar".

Para el vendedor no aparece ninguna de estas opciones.

## 6. Extracto de fiado por cliente

Decisión del usuario: por ahora se muestra al cliente en la pantalla.

- En el detalle del cliente (Fiado): botón "Ver extracto" que abre una pantalla de lectura
  grande, pensada para girar el celular hacia el cliente (sin botones de corrección).
- Contenido, en orden cronológico:
  - Si hubo abonos: arriba, una línea de **consolidado** por el último abono: "Saldo al
    <fecha hora> después de abonar $X: $Y". Todo lo anterior a ese abono queda resumido en
    esa línea, plegado, con "Ver detalle anterior" que lo despliega (por si el cliente
    reclama), y dentro también con consolidados por cada abono anterior.
  - Después: cada fiado con **fecha y hora**, sus productos (descripción, cantidad, precio
    unitario, subtotal) desde `LineasVenta`, y total; y cada abono posterior con fecha, hora y
    monto, seguido de su línea de consolidado.
  - Al final: **saldo actual** destacado.
- Ventas y abonos anulados no aparecen; las corregidas aparecen con su valor vigente.
- Consolidado = saldo después del abono = suma de fiados vigentes hasta ese momento − abonos
  vigentes hasta ese momento (incluido ese abono). Se calcula al mostrar, no se guarda.

## 7. Escáner fácil de descubrir y en el recorrido

Problema del usuario: el ícono solo no dice qué hace; quien no lo conoce no sabe que existe.

- Nueva venta y Crear/editar producto: el `IconButton` de `qr_code_scanner` pasa a un botón
  visible con ícono y texto **"Escanear código"**.
- Primera vez en Nueva venta y en Crear producto: un globo, con el estilo de `globos_venta.dart`
  / `globos_inicio.dart`, "Apunta la cámara al código de barras del producto para venderlo más
  rápido" (o "...para crearlo sin escribir"). Se muestra una sola vez por celular.
- Dentro del escáner: texto fijo "Si el código no existe, te ofrezco crearlo; si existe, lo
  sumo a la venta" (según el contexto: en Crear producto, "lo lleno por ti").
- Recorrido inicial:
  - Paso "Primeros productos" (`paso_productos_screen.dart`): opción **"Crear escaneando"**
    junto a escribir a mano.
  - Venta de práctica (`paso_venta_screen.dart`): el paso guiado ofrece **"Vender
    escaneando"** con "Seguir sin cámara" siempre disponible. Hoy el escáner se oculta en la
    práctica (`registrar_venta_screen.dart`, `practica`); se habilita. Si el código no existe,
    se ofrece crearlo como producto real (como en "Primeros productos"); la venta sigue siendo
    de práctica (decisión mía). Si el celular no da permiso de
    cámara, se sigue sin escáner sin bloquear el recorrido.

## Orden de trabajo (tandas pequeñas y verificables)

1. Clientes (punto 1, con la pantalla "Clientes") y cliente habitual con reportes (punto 3):
   migración v10. Es la tanda más grande; puede partirse en 1a (clientes) y 1b (habitual y
   reportes).
2. Letra (punto 2) y edición de productos (punto 5).
3. Aviso por pedir (punto 4) y extracto de fiado (punto 6).
4. Escáner y recorrido (punto 7).

Cada tanda: pruebas escritas junto con el código (unitarias de repositorios y cálculos,
de widgets para hojas y pantallas nuevas, prueba de migración v9 → v10), `dart format` y
`flutter analyze` limpios, todas las pruebas en verde, y verificación WCAG 2.1 AA de las vistas
nuevas (`Semantics`/`tooltip`, contraste ≥ 4,5:1, objetivos táctiles de 48 dp). Cobertura
≥ 80 % en clientes (datos personales) y ≥ 60 % en el resto. Sin dependencias nuevas previstas;
si alguna hace falta, verificarla en pub.dev con versión fijada. Fusionar o subir solo con
autorización del usuario.

## Para el constructor

- Nombres concretos de clases, providers y textos secundarios.
- Diseño visual de la tarjeta "¿A quién le vendo?" y del extracto, siguiendo el sistema de
  diseño de la renovación (R1–R4).
- Si el indicador del Inicio va como chip, mosaico o fila, según el tablero actual.
