# Fase 4C — Pedido sugerido por proveedor

**Fecha:** 2026-10-07
**Estado:** Implementado (falta el recorrido manual en un celular real)
**Base:** master con Fases 1–4B (esquema v6: existencias, "Por pedir", recibir mercancía).

## Objetivo

Para cada proveedor de "Por pedir", el tendero ve cuánto le conviene pedir de cada producto y
cuánto le costaría, y cuando llega la mercancía la registra desde esa misma lista.

## Decisiones tomadas con el usuario

- **No se envía nada al proveedor:** la app solo muestra la sugerencia (sin WhatsApp ni
  librerías nuevas).
- **No se guardan pedidos:** la sugerencia se consulta; las cantidades editadas en pantalla no
  se guardan. Un botón "Recibir este pedido" abre Recibir mercancía ya llena.
- **Cantidad sugerida con "Pedir hasta":** campo opcional por producto.
- **Enfoque (A):** la regla vive en `InventarioRepository.sugerenciaPedido`; la pantalla solo
  muestra y edita.

## Modelo de datos (esquema v6 → v7)

- `Productos.pedirHasta`: entero nullable. Migración `desde < 7`:
  `addColumn(productos, pedirHasta)`. `CopiaBaseDatos.tablas` no cambia.

## Reglas

- **Pedir hasta:** opcional, ≥ 0 y ≥ mínimo; se edita en Producto → Existencias (solo si el
  producto controla existencias). Error: "Debe ser mayor o igual que el mínimo".
- **Sugerido** de un producto en "Por pedir":
  - con `pedirHasta`: `pedirHasta − existencias`;
  - sin `pedirHasta`: `2 × mínimo − existencias`;
  - siempre al menos 1.
  Ejemplo: existencias −2, mínimo 5, pedir hasta 24 → 26.
- **Precio** de cada línea: el `precioCompra` del producto con **ese** proveedor; si no lo
  tiene (grupo "Sin proveedor"), null.
- **Productos de la sugerencia:** los del grupo de "Por pedir" de ese proveedor preferido
  (`proveedorId` null = "Sin proveedor"), en el mismo orden.
- **Total estimado:** Σ cantidad × precio de las líneas con precio y cantidad > 0.

## Pantallas

### Inventario → Por pedir

Cada grupo gana un botón "Ver pedido sugerido" (`ver_pedido_<proveedorId|sin>`).

### Pedido sugerido (`lib/screens/inventario/pedido_sugerido_screen.dart`)

- Título "Pedido sugerido · Postobón" (o "· Sin proveedor").
- Fila por producto: nombre; "quedan 2 · mín. 6" (y " · hasta 24" si tiene pedir hasta);
  cantidad con − / + (mínimo 0; 0 = no se pide); precio "$900 c/u" (o "Sin precio") y subtotal.
- Abajo: "Total estimado $X" (solo líneas con precio y cantidad > 0).
- Botón "Recibir este pedido": abre Recibir mercancía con el proveedor elegido (si hay) y una
  línea por producto con cantidad > 0, con su cantidad y su precio (vacío si no hay). Deshabilitado
  si todas las cantidades son 0. Al guardar en Recibir, vuelve a Inventario con el aviso de
  siempre.
- Las cantidades editadas no se guardan.

### Recibir mercancía

`RecibirMercanciaScreen({Proveedor? proveedorInicial, List<LineaInicial> lineasIniciales})`
con `LineaInicial(producto, cantidad, precio?)`: arranca con ese proveedor y esas líneas (las
líneas iniciales cuentan como "editadas": cambiar de proveedor no reemplaza sus precios).

### Ajustes → Producto

En "Existencias", con el control activo: campo "Pedir hasta" (opcional) bajo "Mínimo".

## Código

- `lib/data/database.dart`: columna, `schemaVersion = 7`, migración.
- `InventarioRepository.sugerenciaPedido(int? proveedorId)` → `List<LineaSugerida>` con
  `producto`, `existencias`, `sugerido`, `precio` (`int?`); `cambiarPedirHasta(int, int?)`.
- `PedidoSugeridoScreen`; botón en `InventarioScreen`; `RecibirMercanciaScreen` con datos
  iniciales; campo en `ProductoScreen`.

## Pruebas (TDD)

- Migración v6 → v7.
- Sugerido: con y sin pedir hasta; existencias negativas; mínimo 1; orden igual a "Por pedir";
  precio con ese proveedor; "Sin proveedor" sin precio.
- `cambiarPedirHasta`: guarda, borra (null), rechaza negativo.
- Pantalla: muestra sugeridos y total; editar cantidades cambia el total; 0 saca del total;
  "Recibir este pedido" abre Recibir lleno y al guardar suma existencias; sin cantidades,
  botón deshabilitado; grupo "Sin proveedor".
- Producto: guardar "Pedir hasta"; menor que el mínimo muestra el error.

## Fuera de alcance

- Enviar pedidos (WhatsApp u otro) y guardar o historiar pedidos.
- Pedidos con productos fuera de "Por pedir".
