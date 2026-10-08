# Pulido — Tanda 1: fallas y detalles visibles

**Fecha:** 2026-10-08
**Estado:** Implementado (falta el recorrido manual en un celular real)
**Base:** master con Fases 1–4C (esquema v7, 464 pruebas).

## Objetivo

Cerrar los detalles menores que se notan al usar la app, anotados en las revisiones de las
fases 3A–4C, más la validación de líneas al vender (para no ensuciar el inventario). El pulido
completo va en tres tandas, cada una con su rama: (1) esta, (2) letra grande y marca,
(3) mejoras internas.

## Alcance

No hay cambios de esquema (sigue v7) ni librerías nuevas.

### Corregir y anular (3A, 3C)

1. **Mensajes claros.** `HojaMovimiento` distingue los errores al guardar o anular:
   - `PermisoDenegado` → "Ya no puedes corregir este movimiento".
   - `CorreccionInvalida` → su `mensaje` (p. ej. "Este movimiento ya está anulado",
     "El abono no puede ser mayor que la deuda ($X)").
   - Cualquier otro → "No se pudo guardar, intenta de nuevo" (como hoy).
2. **Tope al corregir un abono.** `CorreccionRepository.corregirPago` rechaza con
   `CorreccionInvalida('El abono no puede ser mayor que la deuda (\$X)')` cuando el abono
   **sube** (`monto > monto original`) y `monto > saldo actual del cliente + monto original`,
   donde X es ese máximo. Bajar el monto o solo cambiar el medio de pago siempre se permite. El saldo se calcula
   dentro de la transacción con las mismas reglas de `FiadoRepository.saldoCliente`
   (ventas fiadas no anuladas − abonos no anulados).
3. **Nombre del cliente en Historial.** `HistorialRepository` trae `nombreCliente` en cada
   `MovimientoHistorial` (consulta a `clientes` en lote por los ids del día); la pantalla lo
   usa en vez del mapa de `listaClientesProvider`, que dejaba el nombre vacío mientras
   cargaba.
4. **Corrección sin cambios no se guarda.** `corregirVenta`, `corregirPago` y `corregirGasto`
   comparan lo nuevo con lo guardado (monto, fiado, cliente, medio, cantidades, descripción
   recortada); si todo es igual, no escriben ni registran corrección y terminan sin error. Caso
   típico: escribir a mano el nombre del mismo cliente.
5. **Línea en 0 recuperable.** En el editor de ticket, una línea con cantidad 0 sigue en la
   lista, tachada y en gris, con "−" deshabilitado y "+" activo para volver a 1 o más.

### Reportes (3B, 3C)

6. **Año en periodos de otros años.** `Periodo.titulo` recibe `hoy`; si el periodo termina en
   un año distinto al de `hoy`, se agrega el año: "Semana del 5 al 11 oct. 2025",
   "Octubre 2025". Los del año actual quedan igual. (Los meses ya muestran el año siempre;
   se mantiene.)
7. **Error amable.** En vez de `Error: $e`, Reportes muestra un `EstadoVacio` "No se pudo
   cargar el reporte" con botón **Reintentar** (`ref.invalidate` del provider).
8. **Pérdidas.** En la lista de productos del reporte, una ganancia negativa se muestra como
   "pierde $X" y esa línea va en rojo (`ColoresApp.sale`); "Ganancia en productos" negativa
   se muestra como "Pérdida en productos: $X" en rojo.

### Catálogo (4A)

9. **Editar precio de compra.** Tocar una fila de proveedor en Producto abre la misma hoja
   de "Agregar proveedor" en modo edición: proveedor fijo (sin chips ni campo nuevo), precio
   cargado, botón "Guardar". Se conserva `preferido`.
10. **Proveedor nuevo solo al guardar, sin duplicados.**
    - La hoja ya no llama a `ProveedorRepository.crear`: devuelve una fila con
      `proveedorId` null y el nombre nuevo. `_guardar` del producto crea esos proveedores
      justo antes de `guardarProducto` (si se cancela el producto, no se crea nada).
    - Si el nombre escrito coincide con uno existente (comparación sin mayúsculas y con
      espacios recortados/colapsados), la hoja usa ese proveedor; si está desactivado,
      avisa "<nombre> está desactivado: reactívalo en Proveedores" (un producto no puede
      vincular proveedores inactivos).
    - `ProveedorRepository.crear` y `actualizar` lanzan
      `ArgumentError('Ya existe un proveedor con ese nombre')` ante un nombre repetido (con la
      misma comparación); Proveedores muestra ese mensaje.
    - No se puede agregar dos veces el mismo nombre nuevo en un producto.

### Inventario y pedido (4B, 4C)

11. **Escribir la cantidad.** En Recibir mercancía y en Pedido sugerido, tocar el número
    abre un diálogo con campo numérico (precargado). Recibir acepta enteros ≥ 1; Pedido
    acepta ≥ 0. Los botones + y − siguen igual.
12. **Mensaje para el vendedor.** En Inventario sin productos controlados: el admin ve
    "Actívalo en Ajustes → Productos"; el vendedor ve "Pídele al administrador que lo
    active".
13. **Detalle de un producto que salió.** `DetalleInventarioScreen` distingue cargando de
    "no está": si `productosConControlProvider` ya tiene datos y el producto no aparece,
    muestra `EstadoVacio` "Este producto ya no controla existencias".
14. **Subtotal por fila** en Pedido sugerido: "3 × $2.000 = $6.000" (solo con precio;
    sin precio sigue "Sin precio").
15. **Cargando y vacío** en Pedido sugerido: indicador mientras carga; si no hay líneas,
    `EstadoVacio` "No hay nada por pedir a este proveedor"; con error, "No se pudo cargar el
    pedido".
16. **Mínimo y "Pedir hasta".** `InventarioRepository.cambiarMinimo` rechaza con
    `ArgumentError('El mínimo no puede ser mayor que "Pedir hasta"')` si el producto tiene
    `pedirHasta` y `minimo > pedirHasta`. Nuevo `cambiarLimites(productoId, minimo:,
    pedirHasta:)` guarda los dos en una sola escritura (valida `minimo ≥ 0` y
    `pedirHasta ≥ minimo`); Producto lo usa en vez de llamar a `cambiarMinimo` y
    `cambiarPedirHasta` por separado, así subir o bajar los dos a la vez nunca choca con el
    valor anterior.
17. **Apagar el control borra "Pedir hasta".** `desactivarControl` escribe
    `pedirHasta: null` junto con `controlaExistencias: false`.

### Validación al vender (3C)

18. `VentaRepository.registrarVenta` lanza `ArgumentError` si alguna línea tiene
    `cantidad <= 0` o `precioUnitario <= 0`, antes de abrir la transacción.

## Pruebas

Tests primero en cada punto: de repositorio (2, 3, 4, 6, 10, 16, 17, 18) y de pantalla
(1, 5, 7, 8, 9, 10, 11, 12, 13, 14, 15). Al terminar: suite completa verde, `flutter analyze`
sin problemas y el APK compila.

## Fuera de alcance

Letra grande, marca (tanda 2) y mejoras internas sin efecto visible (tanda 3).
