# App de ventas — Fase 2E (experiencia de usuario y diseño visual)

**Fecha:** 2026-10-05
**Estado:** Borrador para revisión
**Base:** Fase 2A implementada (`docs/superpowers/specs/2026-10-05-app-ventas-fase2a-design.md`)

## Contexto

La app funciona pero se ve como un prototipo de Material por defecto. El usuario pidió evaluar la
experiencia y todo el ambiente gráfico "ya que de momento no es para nada llamativo". Esta fase se
implementa **antes** de la 2B+2C (respaldo), para que las pantallas del respaldo nazcan con este
sistema de diseño.

## Auditoría de la versión actual (resumen)

Hecha sobre capturas del emulador `app_ventas_ligero` (720×1560) y el código.

**Críticos (dinero / uso diario)**
1. Un toque en un producto o monto rápido registra la venta al instante: sin total, sin
   confirmación, sin deshacer (y anular ventas está fuera de alcance) → ventas fantasma.
2. "Fiado" está al final, debajo de los montos: si se toca el monto antes, la venta queda de
   contado.
3. Ninguna acción confirma nada (la pantalla se cierra en silencio); un fiado sin cliente no hace
   nada y no explica por qué.

**Altos (claridad y jerarquía)**
4. El resumen son tres líneas de texto pequeño; no destaca lo importante ni muestra la ganancia.
5. Doble encabezado ("Hola, Ana" + título de pestaña); cerrar sesión es un ícono escondido.
6. Formularios de alta siempre visibles en la mitad inferior (Productos, Usuarios).
7. Listas vacías sin guía.

**Visual**
8. Sin identidad (teal por defecto, sin nombre); botones flotantes menta de bajo contraste.
9. Los montos no se distinguen tipográficamente.
10. Textos abreviados o ambiguos ("Config", "Desde 5/10", "admin").

**Ya bien:** teclado de PIN, áreas de toque de montos rápidos, errores junto al campo (2A).

## Decisiones tomadas con el usuario

- **Dirección visual:** "B · Claro y confiable" (azul marino + verde/rojo semánticos, fondo claro).
- **Nueva venta:** flujo de **ticket** con "A · Catálogo + barra de cobro"; tocar suma, "Cobrar"
  registra, aviso con **Deshacer** 5 s.
- **Datos del ticket:** cada cobro es **una venta con el total** (como hoy). El detalle por
  producto no se guarda. "Deshacer" elimina esa venta y solo existe durante el aviso.

## Sistema visual

### Colores (solo modo claro)

| Token | Valor | Uso |
|---|---|---|
| `primario` | `#1E3A8A` | Marca, navegación activa, selección, enlaces |
| `entra` | `#16A34A` | Ventas, ganancia, botón Cobrar, abonos |
| `sale` | `#DC2626` | Gastos, errores, acciones destructivas |
| `fiado` | `#B45309` | Fiado, por cobrar (fondo suave `#FEF3C7`) |
| `fondo` | `#F7F9FC` | Fondo de pantallas |
| `superficie` | `#FFFFFF` | Tarjetas, barras |
| `borde` | `#E5E7EB` | Bordes de tarjetas y separadores |
| `texto` | `#0F172A` | Texto principal |
| `textoSecundario` | `#64748B` | Etiquetas, ayudas |

Todo par texto/fondo usado cumple contraste ≥ 4.5:1 (texto grande ≥ 3:1).

### Tipografía

- **Inter** empaquetada en `assets/fonts/` (licencia OFL; sin descarga en tiempo de ejecución):
  pesos 400, 600, 700, 800.
- Montos con `FontFeature.tabularFigures()` y peso 800.
- Escala: monto principal 32; título de pantalla 20; monto de tarjeta 18; cuerpo 16 (mínimo);
  etiquetas 12–13.

### Forma, espaciado, toque

- Radio de esquinas 12 (tarjetas, botones, campos); paneles inferiores 20 arriba.
- Espaciado en múltiplos de 4 (8/12/16/24).
- Áreas de toque ≥ 48 dp.
- Íconos: Material rounded (`Icons.*_rounded`), sin emojis como íconos.

### Componentes (`lib/ui/`)

| Componente | Responsabilidad |
|---|---|
| `tema_app.dart` | `ThemeData` central: colores, Inter, formas, estilos de botones, campos, AppBar, NavigationBar, SnackBar |
| `colores_app.dart` | Tokens de color anteriores como constantes |
| `Monto` | Texto de cifra (`formatoMoneda`) con tamaño y color semántico (`entra`/`sale`/`fiado`/neutro) |
| `TarjetaMonto` | Tarjeta con etiqueta, `Monto`, detalle opcional y `onTap` opcional |
| `BotonPrincipal` | Botón grande de ancho completo (variantes: entra, primario, contorno, peligro) |
| `SelectorSegmentado<T>` | Selector de 2–4 opciones (Contado/Fiado, filtros) |
| `EstadoVacio` | Ícono + mensaje + acción opcional para listas vacías |
| `mostrarHojaInferior` | Abre formularios en un panel inferior con manejo del teclado |
| `TecladoMonto` | Teclado numérico (1–9, 000, 0, borrar) que edita un monto entero |
| `avisar(context, texto, {deshacer})` | SnackBar de confirmación, con acción "Deshacer" opcional (5 s) |

## Reglas generales

- Un solo encabezado por pantalla.
- Toda acción que guarda algo confirma con `avisar` ("Venta registrada", "Gasto registrado",
  "Abono registrado", "Producto guardado", "Usuario creado", "PIN actualizado").
- Formularios de alta en panel inferior abierto por un botón "Agregar".
- Toda lista vacía usa `EstadoVacio`.
- Textos completos: "Ajustes" (no "Config"), "Administrador"/"Vendedor", "Debe desde hace N días"
  ("desde hoy" / "desde ayer" para 0/1).

## Pantallas

### Entrada

- **¿Quién eres?:** tarjetas con inicial en círculo de color (color derivado del id), nombre y
  rol.
- **PIN:** mismo teclado con el estilo nuevo; nombre del usuario e inicial arriba.
- **Crear tienda:** mismos campos que hoy, estilo nuevo, botón `BotonPrincipal`.

### Inicio (antes "Resumen")

- Encabezado: "Hola, <nombre>", selector de día (`SelectorFecha` restilizado) y menú de la inicial
  del usuario con "Cerrar sesión".
- Tarjeta principal (fondo `primario`): "Ventas del día", monto 32, detalle
  "N ventas · M fiadas".
- Fila: `TarjetaMonto` "Gastos" (`sale`) y "Ganancia" (`entra`; = ventas − gastos del día; en
  rojo si es negativa).
- `TarjetaMonto` "Por cobrar" (`fiado`): deuda real (2A) y "K clientes"; tocarla abre la pestaña
  Fiado.
- Botones: "+ Venta" (`entra`) y "− Gasto" (contorno `sale`).
- "Por vendedor": filas con nombre y lo vendido.
- `ResumenDia` agrega `cantidadVentas`, `cantidadFiadas` y `clientesConDeuda`.

### Nueva venta (ticket)

- `SelectorSegmentado` **Contado | Fiado** arriba. En Fiado aparece un campo de cliente: buscar
  entre existentes o escribir un nombre nuevo.
- Mosaico de productos activos (nombre + precio, insignia con la cantidad en el ticket) y mosaico
  de montos rápidos ($1.000 … $50.000). Cada toque agrega una línea o suma 1 a su cantidad.
- "+ Otro monto" abre `TecladoMonto` en panel inferior y agrega una línea con ese monto.
- Barra fija inferior: "N artículos · Ver ticket" (panel con las líneas, − / + por línea y quitar),
  "Vaciar" y `BotonPrincipal` **"Cobrar $total"** (en fiado: **"Fiar $total a <cliente>"**).
- Reglas: con el ticket vacío el botón está deshabilitado ("Agrega algo para cobrar"); en fiado
  sin cliente el botón está deshabilitado y el campo muestra "Elige o escribe el cliente".
- Al cobrar: registra **una** venta con el total (`productoId` = id del producto solo si el ticket
  tiene una única línea de producto; si no, null), vuelve al Inicio y muestra
  "Venta registrada · $total" con **Deshacer** (5 s) que elimina esa venta.
- Estado del ticket en un `TicketNotifier` (Riverpod) probado por separado.

### Nuevo gasto

- `TecladoMonto` para el monto, campo de descripción opcional, `BotonPrincipal` "Registrar gasto"
  (`sale`), aviso "Gasto registrado". Monto 0 → botón deshabilitado.

### Fiado

- Lista: encabezado "Te deben $total"; tarjetas con nombre, "Debe desde hace N días" y monto en
  `fiado`. Vacío: `EstadoVacio` "Nadie te debe · Las ventas fiadas aparecerán aquí".
- Detalle del cliente: tarjeta de saldo grande; `BotonPrincipal` "Registrar abono" abre panel con
  `TecladoMonto` y conserva las reglas de la 2A (no mayor que la deuda, sin doble registro);
  movimientos con ícono y color (`fiado` venta fiada, `entra` abono).

### Historial

- `SelectorFecha` + chips de usuario ("Todos", cada usuario).
- Fila de totales del filtro: "Entró $X" (`entra`) · "Salió $Y" (`sale`).
- Filas con ícono y color según entra/sale; vacío: `EstadoVacio` "Sin movimientos este día".

### Ajustes (antes "Config")

- Secciones: **Tienda** (Productos, Usuarios; Respaldo se agrega en 2B+2C) y **Cuenta** (Cerrar
  sesión).
- **Productos / Usuarios:** listas en tarjetas + botón flotante "Agregar" que abre el formulario en
  panel inferior; diálogos de editar / resetear PIN / reactivar se conservan con el estilo nuevo.

### Navegación

- `NavigationBar` (Material 3) con 4 destinos: Inicio, Fiado, Historial, Ajustes (vendedor: sin
  Ajustes, como hoy).

## Cambios de datos

- `VentaRepository.eliminarVenta(int id)` (para Deshacer).
- `ResumenDia`: `cantidadVentas`, `cantidadFiadas`, `clientesConDeuda` (este último desde
  `FiadoRepository`, al cierre del día, coherente con `deudaTotalAl`).
- Sin cambios de esquema.

## Pruebas

- Las pruebas existentes se actualizan donde cambien textos o estructura; las claves de widget se
  conservan cuando el control sigue existiendo.
- Nuevas:
  - `TicketNotifier`: agregar, sumar cantidad, quitar, vaciar, total, una sola línea de producto.
  - Nueva venta: no cobra vacío; no fía sin cliente; cobrar registra una venta con el total y
    vuelve con aviso; Deshacer elimina la venta.
  - `TecladoMonto`: dígitos, "000", borrar, tope razonable (9 dígitos).
  - Inicio: ganancia (positiva y negativa), conteos, tocar "Por cobrar" abre Fiado.
  - Avisos de confirmación en gasto, abono, producto, usuario.
  - Estados vacíos en Fiado e Historial.
  - Tema: contraste de los pares de color definidos (prueba que calcula la relación de
    luminancia).
- Verificación manual: capturas "antes / después" de cada pantalla en el emulador.

## Fuera de alcance

- Modo oscuro, animaciones elaboradas.
- Logo y marca definitivos (nombre "App Ventas" + ícono simple).
- Guardar el detalle de productos por venta; anular ventas pasadas.
- Pantallas del respaldo (2B+2C) — usarán este sistema cuando se implementen.
