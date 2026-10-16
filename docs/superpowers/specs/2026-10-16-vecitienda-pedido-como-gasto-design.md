# VeciTienda — Pedidos guardados y pedido recibido como gasto

Fecha: 2026-10-16. Mejora 1 de las cuatro pedidas el 2026-10-16 (ver `docs/hoja-de-ruta.md`).
Rama: `feature/pedido-como-gasto`. Aplica los lineamientos UNIMINUTO v1.2.

## Intención

El tendero arma el pedido en "Pedido sugerido", se lo pasa al distribuidor y la mercancía
llega **días después**. Al llegar la **paga de contado, en efectivo, de la caja**. Hoy la app
no guarda el pedido: el botón "Recibir" pasa los productos a "Recibir mercancía" en el mismo
momento, y el pago no queda registrado como gasto, así que la caja y la ganancia del día no
reflejan lo que salió para mercancía.

Lo que quiere el usuario:

1. Guardar el pedido sugerido como pedido **por llegar**.
2. Al llegar, **validar** lo que llegó contra lo pedido: cantidades, productos que no llegaron,
   productos extra y precios cambiados.
3. Que lo recibido entre **como gasto** de la caja.

## Decisiones del usuario

- El pedido original es el que se arma en "Pedido sugerido".
- La mercancía llega días después: el pedido se guarda mientras tanto.
- Se paga de contado en efectivo. El interruptor "Lo pagué de la caja" viene **siempre
  encendido** por defecto; se puede apagar para un caso puntual.
- Al recibir, el pedido **se cierra** con lo que llegó. Lo que faltó o no llegó es definitivo
  para ese pedido y debe salir en el **siguiente** pedido sugerido.
- Puede haber **varios pedidos por llegar**, incluso del mismo proveedor. La sugerencia debe
  descontar lo que ya está pedido y por llegar.
- El pedido guardado se puede editar o anular mientras no llega (propuesto y aceptado con
  "continúa así").

## Metas

- Pedidos guardados con estado: por llegar → recibido, o anulado.
- Recepción contra un pedido que muestra, por producto: completo, faltan N, no llegó, extra
  (no se pidió) y precio cambiado, con un resumen antes de guardar.
- Gasto automático "Mercancía · <proveedor>" por el total **recibido**, enlazado a la entrada.
- Pedido sugerido y "Por pedir" que tienen en cuenta lo que está por llegar.

## No metas

- Enviar el pedido al distribuidor (WhatsApp, PDF, etc.). Sigue fuera, como en la Fase 4C.
- Pedidos abiertos con pendientes ("backorder"): nunca queda nada esperando de un pedido
  recibido.
- Pagos a crédito al proveedor o cuentas por pagar. Si no se pagó de la caja, se apaga el
  interruptor y no hay gasto; no se lleva deuda con el proveedor.
- Corregir una entrada ya guardada. Igual que hoy, solo se anula (y se vuelve a recibir).

## Anti-metas (fallaría aunque "funcione")

- Que el gasto se cuente dos veces: el gasto enlazado no debe poder corregirse ni anularse
  suelto, y anular la entrada debe anular su gasto en la misma transacción.
- Que la sugerencia vuelva a pedir lo que ya viene en camino.
- Que lo que no llegó desaparezca de las sugerencias: debe volver a salir en cuanto el producto
  esté en el mínimo o por debajo.
- Perder datos existentes en la migración de la base de datos.

## Cómo funciona

### 1. Guardar el pedido

- En "Pedido sugerido", el botón principal pasa de "Recibir" a **"Guardar pedido"**. Guarda
  proveedor, fecha, usuario y, por producto, la cantidad y el precio esperado (el de ese
  proveedor si lo hay). Tras guardar se vuelve a Inventario con un aviso "Pedido guardado".
- Un pedido necesita proveedor. Si el grupo es "Sin proveedor", se pide elegir uno antes de
  guardar (*decisión mía*: así funciona hoy recibir mercancía, que exige proveedor activo).
- Productos con cantidad 0 no se guardan; un pedido sin productos no se puede guardar.

### 2. Pedidos por llegar en Inventario

- Inventario muestra una sección **"Por llegar"** (solo si hay alguno) con una tarjeta por
  pedido: proveedor, fecha del pedido ("pedido el lunes 12"), número de productos, total
  estimado y botón **"Llegó este pedido"**.
- Tocar la tarjeta abre el pedido: se pueden cambiar cantidades, quitar o agregar productos y
  **anularlo** (con confirmación). Un pedido anulado deja de contar como por llegar.
- "Recibir mercancía" sin pedido sigue existiendo, como hoy. Si al elegir el proveedor hay
  pedidos por llegar de él, se pregunta "¿Llegó alguno de estos pedidos?" con la lista y la
  opción "No, es otra mercancía" (*decisión mía*: evita que un pedido quede por llegar para
  siempre y siga descontándose de la sugerencia).
- Permisos (*decisión mía*): cualquier usuario guarda pedidos y recibe; editar o anular un
  pedido por llegar lo puede hacer quien lo hizo o el administrador.

### 3. Recibir un pedido

- "Llegó este pedido" abre "Recibir mercancía" con el proveedor y las líneas del pedido;
  cada línea arranca con **llegó = lo pedido** y el precio esperado, para que el caso normal
  sea confirmar sin escribir.
- Cada línea muestra "pedido N · llegó M" y una etiqueta:
  - **Completo** (llegó = pedido), **Faltan N** (0 < llegó < pedido), **No llegó** (llegó 0),
    **Llegaron N de más** (llegó > pedido), **Extra** (producto que no estaba en el pedido)
    y, aparte, **precio cambiado** ($ antes → $ ahora) cuando el precio difiere del esperado.
- Se puede poner la cantidad en 0 (no llegó) sin quitar la línea, y agregar productos extra
  con el selector actual.
- Antes de guardar, un **resumen**: total pedido, total que llegó y el conteo de diferencias
  (completos, incompletos, no llegaron, extra, precios cambiados).
- Interruptor **"Lo pagué de la caja (efectivo)"**, encendido por defecto, con el texto
  "Se registra gasto Mercancía · <proveedor> por $ X".
- Al guardar, en **una sola transacción**: la entrada (solo con las líneas que llegaron,
  cantidad > 0), los precios del proveedor como hoy, el pedido pasa a **recibido** y enlazado
  a la entrada, y el gasto si el interruptor está encendido.
- Si todo quedó en 0, no se puede guardar; se ofrece anular el pedido.

### 4. El gasto

- Monto: total de la entrada (lo que llegó). Descripción: `aplicarCategoria(proveedor,
  'Mercancía')` → "Mercancía · Postobón". Fecha y usuario: los de la recepción.
- El gasto guarda el id de la entrada. Recibir mercancía **sin pedido** también crea el gasto
  con el mismo interruptor.
- En Historial y en la corrección de gastos, un gasto enlazado no ofrece corregir ni anular;
  muestra "Viene de la mercancía recibida; para cambiarlo anula la entrada".
- Anular la entrada anula su gasto en la misma transacción (y lo registra en el historial de
  correcciones como hoy se registran las anulaciones de gastos).
- Permisos (*decisión mía*): anular una entrada **que tiene gasto** sigue la misma regla que
  anular un gasto (`puedeCorregir`: el administrador siempre; el vendedor solo lo suyo y del
  mismo día), en el repositorio y en la pantalla. Las entradas sin gasto siguen como hoy.
- Reportes y resumen del día ya restan los gastos, así que no cambian: la ganancia queda en
  vista de caja (ventas − gastos).
- La primera vez que se recibe con el interruptor encendido se muestra una vez: "Ya no
  registres la mercancía como gasto a mano; se anota sola" (*decisión mía*, para evitar el
  doble conteo).

### 5. Sugerencia con pedidos por llegar

- **Por llegar** de un producto = suma de cantidades en pedidos por llegar (no recibidos ni
  anulados).
- Cantidad sugerida = `(pedirHasta ?? 2 × mínimo) − existencias − porLlegar`.
- Si la cantidad sugerida es ≤ 0, el producto sigue en "Por pedir" con la etiqueta
  **"Ya pedido · llegan N"** pero no entra al pedido sugerido. Si es > 0, entra con esa
  cantidad y la línea muestra "llegan N" como nota.
- Al recibir, el pedido deja de contar como por llegar: lo que faltó vuelve solo a la
  siguiente sugerencia, porque las existencias no subieron.
- Decidido por el usuario (2026-10-16): lo que faltó **no** se guarda aparte. Si con lo que sí
  llegó el producto queda por encima del mínimo, no se sugiere hasta que vuelva a bajar al
  mínimo, como cualquier otro producto.

### 6. Después de recibir

- Anular una entrada que vino de un pedido devuelve el pedido a **por llegar** y le quita el
  enlace a la entrada (*decisión mía*): así se vuelve a recibir contra él con la comparación.
  Estados posibles: por llegar → recibido → (anular entrada) → por llegar; por llegar →
  anulado.

- El detalle de la entrada muestra, si vino de un pedido, la comparación pedido vs llegó con
  las mismas etiquetas, y el gasto que generó.

## Datos (BD v8 → v9)

- Tabla nueva `Pedidos`: id, proveedorId, usuarioId, fecha, estado (por llegar / recibido /
  anulado), entradaId (nullable, al recibir).
- Tabla nueva `LineasPedido`: id, pedidoId, productoId, cantidad, precioEsperado (nullable).
- `Gastos`: columna nueva `entradaId` (nullable).
- Migración `from < 9` que crea las tablas y agrega la columna sin tocar datos; prueba de
  migración 8 → 9 como las anteriores.
- El respaldo copia la base completa, así que no necesita cambios; verificar que restaurar un
  respaldo v8 migra bien.

## Pruebas

- Repositorio: guardar, editar y anular pedidos; recibir contra pedido (completo, parcial, no
  llegó, extra, de más, precio cambiado); transacción con gasto encendido y apagado; anular
  entrada anula gasto; gasto enlazado no se corrige ni anula suelto; sugerencia con uno y
  varios pedidos por llegar; faltantes vuelven a la sugerencia; migración 8 → 9.
- Pantallas: Guardar pedido, sección Por llegar, recepción con etiquetas y resumen,
  interruptor, aviso de una vez, detalle de entrada, etiqueta "Ya pedido".
- Modo oscuro y letra 2,0× en las pantallas nuevas (como en las tandas anteriores);
  `Semantics` en etiquetas e interruptor; contraste ≥ 4,5:1.
- Cobertura ≥ 60 % en lo nuevo (la recepción y el gasto tocan dinero: apuntar al 80 %).

## Queda al criterio de quien lo construya

- Disposición exacta de la tarjeta "Por llegar" y del resumen, siguiendo el estilo R4.
- Nombres de clases, providers y métodos, siguiendo los del repositorio.
- Si "Llegaron N de más" y "Extra" comparten color.
