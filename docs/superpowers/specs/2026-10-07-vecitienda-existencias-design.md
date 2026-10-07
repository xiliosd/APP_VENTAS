# Fase 4B — Existencias y "Por pedir"

**Fecha:** 2026-10-07
**Estado:** Implementado (falta el recorrido manual en un celular real)
**Base:** master con Fases 1–4A (esquema v5: líneas de venta con costo, proveedores, nombre de la
tienda).

## Objetivo

El tendero sabe cuántas unidades le quedan de los productos que decide controlar, registra la
mercancía que le llega (actualizando precios de compra), corrige el conteo cuando no cuadra y ve
qué productos debe pedir y a qué proveedor. Es la base de la 4C (pedidos por proveedor).

## Decisiones tomadas con el usuario

- **Control opcional por producto:** solo los productos con "Controlar existencias" activo llevan
  conteo; los demás se venden como hoy.
- **Sin existencias se vende igual:** la venta nunca se bloquea; las existencias pueden quedar en
  negativo y se avisan.
- **Permisos:** cualquier usuario recibe mercancía, ajusta conteos y anula entradas; siempre queda
  quién lo hizo. Activar el control y el mínimo se manejan en Ajustes → Producto (administrador).
- **Recibir por proveedor con precio:** cada entrada es de un proveedor, con productos, cantidad y
  precio de compra; actualiza los precios del proveedor en cada producto.
- **Enfoque (B):** existencias **calculadas** desde el último conteo, más lo recibido después,
  menos lo vendido después. Se descartaron un contador con libro de movimientos (A, exige
  engancharse en ventas, corrección, anulación y Deshacer) y un contador sin rastro (C).
- **Unidades enteras** (sin decimales ni pesos).

## Modelo de datos (esquema v5 → v6)

- `Productos.controlaExistencias`: bool, default false.
- `Productos.minimo`: entero ≥ 0, default 0.
- Tabla nueva `ConteosInventario` (`@DataClassName('ConteoInventario')`): `id`, `productoId` →
  `Productos`, `cantidad` (≥ 0), `anterior` (entero nullable: existencias según la app al
  contar; null en el inicial), `tipo` (`textEnum<TipoConteo>`: `inicial | ajuste`), `nota`
  (nullable), `usuarioId` → `Usuarios`, `fecha`.
- Tabla nueva `EntradasMercancia` (`@DataClassName('EntradaMercancia')`): `id`, `proveedorId` →
  `Proveedores`, `usuarioId` → `Usuarios`, `fecha`, `total` (Σ cantidad × precio), `nota`
  (nullable), `anulada` (bool, default false).
- Tabla nueva `LineasEntrada` (`@DataClassName('LineaEntrada')`): `id`, `entradaId` →
  `EntradasMercancia`, `productoId` → `Productos`, `cantidad` (> 0), `precioCompra` (> 0).
- Migración `desde < 6`: `createTable` ×3 y, si `productos` ya existía (siempre: viene de v1),
  `addColumn(productos, controlaExistencias)` y `addColumn(productos, minimo)`. Solo agrega.
  `CopiaBaseDatos.tablas` no cambia.

## Reglas

- **Existencias** de un producto con control =
  `último conteo.cantidad`
  `+ Σ lineas_entrada.cantidad` de entradas no anuladas con `fecha > conteo.fecha`
  `− Σ lineas_venta.cantidad` de ventas no anuladas con `fecha > conteo.fecha`.
  Producto sin control (o sin conteo): no tiene existencias (null). Ventas, correcciones de
  cantidades, anulaciones y Deshacer se reflejan solas.
- **Activar el control:** pide "Hay ahora" (≥ 0) y "Mínimo" (≥ 0); crea un conteo `inicial` y
  pone `controlaExistencias = true` en una transacción. **Desactivar:** `controlaExistencias =
  false` (el historial queda). **Reactivar:** pide un conteo nuevo (otro `inicial`).
- **Ajuste por conteo:** cantidad ≥ 0 y nota opcional; guarda `anterior` = existencias en ese
  momento. Desde ese conteo, lo anterior ya no cuenta.
- **Mínimo:** solo el administrador lo cambia (en Producto).
- **Recibir mercancía:** proveedor activo; al menos una línea; cantidad > 0 y precio > 0; un
  producto no se repite en la misma entrada. En una transacción: guarda la entrada (con total) y
  sus líneas, y por cada línea:
  - si el producto ya tenía a ese proveedor y el precio cambió, actualiza su `precioCompra`;
  - si no lo tenía, agrega el vínculo (preferido si el producto no tenía ninguno).
  Un producto sin control también se puede recibir (entrada y precio sí; existencias no).
- **Anular una entrada:** `anulada = true` (deja de sumar existencias). Los precios que actualizó
  no se revierten; la confirmación lo avisa. No se anula dos veces.
- **Por pedir:** productos activos con control y existencias ≤ mínimo, agrupados por su proveedor
  preferido (grupo "Sin proveedor" al final, grupos por nombre). Dentro de cada grupo: primero
  los negativos, luego por (existencias − mínimo) ascendente, luego por nombre.

## Pantallas

### Pestaña "Inventario" (todos los usuarios)

Nueva pestaña en `HomeScreen`, entre Fiado e Historial (`Icons.inventory_2_outlined`).

- Botón principal "Recibir mercancía" (`boton_recibir_mercancia`).
- `SelectorSegmentado` "Por pedir (N)" | "Todos" (abre en "Por pedir" si N > 0, si no en "Todos").
- **Todos:** productos activos con control, por nombre: nombre, existencias "12 u" (en rojo si
  ≤ mínimo; negativas "−2 u") y "mín. 5". Tocar abre el detalle.
- **Por pedir:** grupos "Postobón · 3 productos" con filas "Coca 400 · quedan 2 · mín. 6"; sin
  productos: "Nada por pedir".
- **Entradas recibidas:** al final, las 20 más recientes: "Postobón · 07/10 15:30 · $48.000 · Ana"
  (tachada si anulada). Tocar abre su detalle con líneas ("24 × Coca 400 · $900") y "Anular
  entrada" (confirmación "¿Anular esta entrada? Las existencias se descuentan; los precios
  actualizados no cambian.").
- Sin productos con control: `EstadoVacio` "Aún no controlas existencias" / "Actívalo en
  Ajustes → Productos".

### Detalle de producto (inventario)

Existencias, mínimo, botón "Ajustar conteo" e historial reciente (conteos "Ana · 12 → 9 (−3)",
iniciales "Ana · conteo inicial 20", entradas "Postobón · +24"), del más reciente al más viejo.

### Ajustar conteo (hoja)

"Según la app hay 12. ¿Cuántas hay?" + campo cantidad + "Nota" (opcional) → "Guardar"; aviso
"Conteo guardado". Cantidad vacía o negativa: "Escribe cuántas hay".

### Recibir mercancía (pantalla)

1. Proveedor: chips de proveedores activos (obligatorio).
2. "Agregar producto": buscador de productos activos que no estén ya en la entrada.
3. Líneas: nombre, cantidad con − / + (mínimo 1), campo "Precio de compra" (sugerido: precio de
   ese proveedor para el producto; si no, el costo del producto; si no, vacío), subtotal; quitar.
4. Total y "Nota" opcional. "Guardar" habilitado con proveedor, ≥ 1 línea y precios válidos;
   aviso "Mercancía recibida · $X".

### Ajustes → Producto (administrador)

Sección "Existencias": interruptor "Controlar existencias". Al activarlo en un producto que no lo
tenía: campos "Hay ahora" y "Mínimo" (obligatorios al guardar). Si ya está activo: "Hay 12 u",
campo "Mínimo" editable y botón "Ajustar conteo". Desactivar pide confirmación. Todo se guarda
con "Guardar" del producto.

## Código

- `lib/data/database.dart`: columnas, tablas, `enum TipoConteo { inicial, ajuste }` (exportado),
  `schemaVersion = 6`, migración.
- `lib/repositories/inventario_repository.dart` (nuevo): `existencias(int)`,
  `existenciasDe(Iterable<int>)` (`Map<int, int>`), `activarControl`, `desactivarControl`,
  `cambiarMinimo`, `ajustarConteo`, `recibirMercancia`, `anularEntrada`, `entradas({limite})`,
  `lineasDeEntrada`, `porPedir()`, `historial(int)`.
- Providers con el patrón `tableUpdates()`.
- Pantallas: `lib/screens/inventario/` (pestaña, detalle, hoja de ajuste, recibir, detalle de
  entrada); `ProductoScreen` (sección Existencias); `HomeScreen` (pestaña).

## Pruebas (TDD)

- Migración v5 → v6 y desde v1–v4.
- Existencias: inicial − ventas; venta anulada no cuenta; corrección de cantidades y Deshacer se
  reflejan; entradas suman y anuladas no; ventas anteriores a un ajuste no cuentan; negativo;
  sin control → null; desactivar y reactivar con nuevo conteo.
- Recibir: actualiza precio (y costo si es preferido); agrega proveedor nuevo (preferido si no
  había); producto sin control registra entrada; rechaza cantidad 0, precio 0, proveedor
  inactivo, sin líneas y producto repetido; transacción.
- Por pedir: agrupación, orden, "Sin proveedor", con suficiente no aparece, inactivo no aparece.
- Pantallas: pestaña (lista, colores, Por pedir, vacío); recibir completo; ajuste; anular
  entrada; activar control y mínimo en Producto; la pestaña la ve también el vendedor.

## Fuera de alcance

- Pedidos y envío por WhatsApp (4C).
- Unidades por peso o decimales; presentaciones (caja/unidad).
- Revertir precios al anular una entrada.
- Valor del inventario (existencias × costo) en Reportes.
