# Fase 4A — Catálogo, proveedores y nombre de la tienda

**Fecha:** 2026-10-07
**Estado:** Diseño aprobado, pendiente de plan
**Base:** master con Fases 1–3C (esquema v4, líneas de venta).

## Objetivo

El dueño registra a sus proveedores y, para cada producto, a quién se lo compra y a qué precio,
con un proveedor preferido. Con ese costo, la app guarda en cada venta cuánto costó lo vendido
y Reportes muestra cuánto dejan de ganancia los productos. Es la base de la 4B (existencias y
"Por pedir") y la 4C (pedidos por proveedor).

## Fase 4 dividida (acordado con el usuario)

1. **4A — Catálogo y proveedores** (esta especificación).
2. **4B — Existencias y "Por pedir":** existencias que bajan con cada venta, recibir mercancía,
   ajuste por conteo, mínimo y lista de lo que hay que pedir.
3. **4C — Pedidos por proveedor:** armar el pedido desde "Por pedir", enviarlo por WhatsApp y
   marcarlo recibido (suma existencias).

## Decisiones tomadas con el usuario

- **Varios proveedores por producto**, cada uno con su precio de compra.
- **Proveedor preferido:** uno por producto; su precio es el costo y es a quien se le pide por
  defecto (en la 4C se podrá cambiar en el pedido).
- **Ganancia en Reportes:** en el ranking ("gana $X" por fila), un total "Ganancia en productos"
  y un aviso de lo vendido sin costo registrado.
- **Enfoque (A):** tablas `proveedores` y `productos_proveedores`, y el costo guardado en cada
  línea de venta. Se descartaron columnas en el producto (B) y JSON (C).
- **Nombre de la tienda** (pedido del usuario al aprobar esta especificación, para dar sentido
  de pertenencia): la app sigue siendo de una sola tienda por celular; la tienda tiene un
  nombre, todos los usuarios pertenecen a ella y el nombre se ve dentro de la app. Se
  descartaron varias tiendas por celular y unirse a una tienda por la nube (serían fases
  aparte).

## Modelo de datos (esquema v4 → v5)

- Tabla nueva `Proveedores` (`@DataClassName('Proveedor')`): `id`, `nombre`, `telefono`
  (nullable), `notas` (nullable), `activo` (bool, default true).
- Tabla nueva `ProductosProveedores` (`@DataClassName('ProductoProveedor')`): `id`,
  `productoId` → `Productos`, `proveedorId` → `Proveedores`, `precioCompra` (entero > 0),
  `preferido` (bool, default false). Única por (`productoId`, `proveedorId`).
- `ConfiguracionTienda.nombreTienda`: texto nullable (null = aún sin nombre).
- `LineasVenta.costoUnitario`: entero nullable (null = sin costo: monto suelto, producto sin
  proveedores o venta anterior a la 4A).
- Migración `desde < 5`: `createTable` ×2, `addColumn(lineasVenta, costoUnitario)` y
  `addColumn(configuracionTienda, nombreTienda)`. Solo agrega.
  `CopiaBaseDatos.tablas` no cambia.

## Reglas

- **Proveedores:** no se borran, se desactivan (como los productos). Uno inactivo no se puede
  agregar a un producto; en los productos que ya lo tienen sigue contando (aparece en gris).
- **Producto–proveedor:** 0 o más por producto; sin repetir proveedor; precio de compra > 0.
  Si hay al menos uno, exactamente uno es preferido:
  - el primero que se agrega queda preferido;
  - marcar otro desmarca al anterior;
  - si se quita el preferido, pasa a ser preferido el siguiente que quede (el de menor `id`).
  - El repositorio lo garantiza al guardar (transacción) y rechaza listas inválidas.
- **Costo de un producto:** el `precioCompra` de su preferido; sin proveedores, null.
- **Precio de compra > precio de venta:** se permite; el formulario avisa "Este producto se vende
  con pérdida".
- **Al vender:** cada línea con producto guarda `costoUnitario` = costo del producto en ese
  momento; las líneas de monto suelto guardan null. Corregir cantidades no cambia el costo.
  Cambiar el costo después no altera ventas pasadas.
- **Ganancia en Reportes (sin anulados):**
  - por producto: Σ (precioUnitario − costoUnitario) × cantidad de sus líneas con costo; null
    si ninguna línea del producto en el periodo tuvo costo;
  - "Ganancia en productos" = la misma suma sobre todas las líneas con costo;
  - "vendidos sin costo registrado" = Σ precioUnitario × cantidad de las líneas sin costo
    (productos sin costo y montos sueltos).
  - La tarjeta "Ganancia" (ventas − gastos) no cambia.
- **Acceso:** Productos y Proveedores siguen en Ajustes (solo administrador).
- **Nombre de la tienda:** obligatorio al configurar la app por primera vez; de 1 a 40
  caracteres sin espacios sobrantes. Solo el administrador lo cambia. Viaja en el respaldo
  (vive en la base). Todos los usuarios que se crean pertenecen a esa tienda (no hay otra).

## Pantallas

### Nombre de la tienda

- **Primera configuración** (`CrearAdminInicialScreen`): campo nuevo "Nombre de la tienda"
  (`campo_nombre_tienda`) antes del nombre y PIN del administrador; error "Escribe el nombre de
  tu tienda".
- **Instalaciones existentes sin nombre:** al entrar un administrador a Inicio, una hoja "¿Cómo
  se llama tu tienda?" con el campo y "Guardar"; no se puede cerrar sin guardar. Un vendedor no
  la ve (la app sigue funcionando y muestra lo de hoy hasta que el administrador lo ponga).
- **Dónde se ve:**
  - Elegir usuario e ingresar PIN: el nombre de la tienda como título sobre la lista / el PIN.
  - Encabezado azul de Inicio: el nombre de la tienda en una línea pequeña bajo "Hola, Ana".
  - Ajustes: primera fila "Tienda" con el nombre; el administrador la toca y lo cambia en una
    hoja (aviso "Nombre guardado").

### Ajustes

- Entrada nueva "Proveedores" (`menu_proveedores`) junto a "Productos".

### Proveedores (`lib/screens/configuracion/proveedores_screen.dart`)

- Lista de activos: nombre, teléfono y "Surte N productos" (`plural`); abajo "Inactivos".
- Botón flotante "Agregar" y tocar un proveedor abren una hoja con Nombre (obligatorio),
  Teléfono y Notas; al editar, debajo, la lista de productos que surte con su precio (solo
  lectura). Avisos "Proveedor guardado".
- Desactivar (`visibility_off`) y "Reactivar", como en Productos.

### Productos

- Lista: subtítulo "$3.500 · gana $1.000" o "$3.500 · sin costo".
- Crear y editar abren la pantalla completa **Producto**
  (`lib/screens/configuracion/producto_screen.dart`), que reemplaza el formulario de creación y
  `EditarProductoDialog`:
  - Nombre y Precio de venta (validaciones de hoy: "Escribe un nombre", "Escribe un precio
    válido").
  - Sección "Proveedores": filas con nombre, precio de compra, estrella de preferido (tocarla lo
    marca) y quitar. Botón "Agregar proveedor": hoja con lista de proveedores activos que aún
    no están (o "Nuevo proveedor" con solo el nombre) y campo "Precio de compra".
  - Resumen: "Costo $2.500 · Ganas $1.000 por unidad (29 %)" (porcentaje = ganancia ÷ precio
    de venta, redondeado); con pérdida, en rojo "Este producto se vende con pérdida"; sin
    proveedores, "Sin costo: agrega un proveedor para ver la ganancia".
  - "Guardar" graba producto y proveedores en una transacción; aviso "Producto guardado".

### Reportes → Productos más vendidos

- Arriba: "Ganancia en productos: $X" (si hubo alguna línea con costo).
- Filas: "1. Arepa · 42 u · $147.000 · gana $40.000" (sin "· gana …" si su ganancia es null).
- Abajo: "$Y vendidos sin costo registrado" (si Y > 0), además de "Otros montos" como hoy.

## Código

- `lib/data/database.dart`: tablas y columna, `schemaVersion = 5`, migración.
- `lib/repositories/proveedor_repository.dart` (nuevo): `activos()`, `inactivos()`,
  `crear({nombre, telefono, notas})`, `actualizar(id, {...})`, `desactivar(id)`,
  `reactivar(id)`, `cantidadProductos()` (`Map<int, int>`), `productosDe(proveedorId)`.
- `ProductoRepository`: `proveedoresDe(productoId)`, `costoDe(productoId)`,
  `guardarProducto({int? id, nombre, precio, List<ProveedorDeProducto> proveedores})`
  (devuelve el id), donde `ProveedorDeProducto { proveedorId, precioCompra, preferido }`.
- `VentaRepository.registrarVenta`: busca el costo de cada línea con producto y lo guarda.
- `ReporteRepository`: `ProductoVendido.ganancia` (`int?`), `Reporte.gananciaProductos`,
  `Reporte.vendidoSinCosto`.
- Providers de proveedores con el patrón `tableUpdates()`.
- `ConfiguracionRepository`: `nombreTienda()` y `guardarNombreTienda(String)`;
  `nombreTiendaProvider` (stream o `tableUpdates()`); usado en login, Inicio y Ajustes.

## Pruebas (TDD)

- Migración v4 → v5 (las de versiones anteriores siguen); una base v4 abre sin nombre de tienda.
- Nombre de la tienda: guardar y leer; validación (vacío, solo espacios, más de 40); la primera
  configuración lo exige y lo guarda; la hoja aparece al administrador sin nombre y no al
  vendedor; se ve en elegir usuario, PIN, Inicio y Ajustes; el administrador lo cambia.
- Proveedores: crear, editar, desactivar/reactivar, conteo de productos, inactivo no
  agregable a un producto.
- `guardarProducto`: primero queda preferido; cambiar preferido desmarca al anterior; quitar el
  preferido pasa la marca al de menor id; rechaza precio 0, proveedor repetido y dos preferidos;
  si falla, nada cambia.
- Costo al vender: línea de producto guarda el costo del preferido; monto suelto null; cambiar
  el costo después no altera la línea guardada.
- Reportes: ganancia por producto, total, vendido sin costo, anulado no cuenta, producto sin
  costo sin "gana".
- Pantallas: crear producto con dos proveedores y cambiar el preferido; aviso de pérdida; lista
  con "gana $X" y "sin costo"; CRUD de proveedores; Reportes con "gana" y "sin costo
  registrado".

## Fuera de alcance

- Existencias, recibir mercancía, mínimos y "Por pedir" (4B).
- Pedidos y envío por WhatsApp (4C).
- Historial de precios de compra.
