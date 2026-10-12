# Renovación de la interfaz — R4: administración

**Fecha:** 2026-10-12
**Estado:** Diseño aprobado en conversación; pendiente de revisar la spec escrita
**Base:** master con R1–R3b (d9154a9, 684 pruebas).

## Contexto

Última tanda de la renovación. Lleva el lenguaje visual de R1–R3 (tarjetas con jerarquía,
`EntradaEscalonada`, `BotonPrincipal`, `Monto`, modo oscuro y letra grande sin desbordes) a
las pantallas de administración: inventario, recibir mercancía, pedido sugerido, ajuste de
conteo, detalle de entrada, Ajustes, productos, ficha de producto, proveedores, usuarios,
respaldo (con verificación de teléfono) y configurar QR. El objetivo es mostrar y vender la
app.

Se hace en **una sola tanda** (decisión del usuario). Sin cambios de esquema, de
repositorios ni dependencias nuevas. Se conservan todas las claves existentes salvo donde se
indica. Se agregan mejoras pequeñas de pantalla: cabecera de Ajustes, resumen y niveles de
inventario, buscador de productos, barra de total fija y avatares con chip de rol.

## 1. Piezas compartidas (`lib/ui/`)

- **`nivel_existencias.dart`**:
  - `enum NivelExistencias { agotado, bajo, ok }`.
  - `NivelExistencias nivelExistencias(int existencias, int minimo)`: `agotado` si
    `existencias <= 0`; `bajo` si `existencias <= minimo`; `ok` en otro caso.
  - `double fraccionNivel(int existencias, int minimo, int? pedirHasta)`: existencias ÷ tope,
    con tope = `pedirHasta` si es > 0; si no, `2 × minimo` si es > 0; si no,
    `existencias` (barra llena). Resultado limitado a 0..1; 0 si existencias ≤ 0.
  - `EtiquetaNivel(nivel)`: `Pildora` con "Agotado" (`sale`), "Bajo" (`fiado`) u "OK"
    (`entra`).
  - `BarraNivel(fraccion, nivel)`: barra de 6 px de alto, redondeada, fondo
    `textoSecundario` al 15 % y relleno en el color del nivel.
- **`pildora.dart`** — `Pildora({required String texto, required Color color})`: fondo
  del color al 15 %, forma de estadio, punto de 8 px en el color y texto 12 px w700 en
  `c.texto` (así cumple 4,5:1 en ambos temas, como se decidió en R3a). La usan la etiqueta de
  nivel, el margen de productos, "Surte N" y el chip de rol.
- **`barra_accion_fija.dart`** — `BarraAccionFija({required Widget total, required Widget
  boton})`: franja inferior (para `Scaffold.bottomNavigationBar`) con fondo `superficie`,
  sombra superior suave, `SafeArea`, padding 16; el total arriba y el botón (ancho completo)
  debajo, para que con letra grande nada se desborde.
- **`titulo_seccion.dart`** — `TituloSeccion(texto)`: el `_Titulo` actual de Ajustes (12 px,
  w700, espaciado 0,5, `textoSecundario`) movido para reutilizarlo.
- **`icono_cuadrado.dart`** — `IconoCuadrado(icono, color)`: ícono de 20 px en un cuadrado
  de 36 px con radio 10 y fondo del color al 15 %.

## 2. Ajustes (`lib/screens/configuracion/ajustes_screen.dart`)

- **Cabecera** (`cabecera_ajustes`, conserva la clave `menu_nombre_tienda` en el área
  tocable): tarjeta `tarjetaPrincipal`, radio `radioTarjetaPrincipal`; `AvatarInicial`
  (radio 28, id 0) con la inicial de la tienda; nombre de la tienda (o "Sin nombre") en
  `sobreTarjetaPrincipal`, 20 px w800; debajo "{usuario} · {etiquetaRol}"; ícono de lápiz.
  Tocar abre `mostrarHojaNombreTienda` como hoy.
- **Grupos** con `TituloSeccion`:
  - TIENDA: Productos (`primario`), Proveedores (`fiado`), Usuarios (`marcaVerde`).
  - COBROS Y DATOS: Cobro por QR (`entra`), Respaldo (`primario`). En Respaldo, si
    `respaldoProvider.fase == activo`, la fila muestra a la derecha un punto `entra` de 8 px
    y "Activo" (`estado_respaldo_menu`).
  - AYUDA: Ver el recorrido otra vez.
  - CUENTA: Cerrar sesión (en `sale`).
- Cada fila con `IconoCuadrado` como `leading`. Se conservan `menu_productos`,
  `menu_proveedores`, `menu_usuarios`, `menu_cobro_qr`, `menu_respaldo`,
  `boton_repetir_recorrido` y `ajustes_cerrar_sesion`.
- Grupos con `EntradaEscalonada` (índices 0..4).

## 3. Inventario

### 3.1 Pestaña (`inventario_screen.dart`)

- **Resumen** (`resumen_inventario`), solo si hay productos controlados: tarjeta con tres
  cifras (24 px w800) y su rótulo: "Controlados" (`resumen_controlados`), "Por pedir"
  (`resumen_por_pedir`) y "Agotados" (`resumen_agotados`, en `sale` si > 0). Agotados = los
  controlados con `nivelExistencias == agotado`.
- "Recibir mercancía" (`boton_recibir_mercancia`) sigue arriba como `BotonPrincipal`.
- Estado vacío "Aún no controlas existencias": como hoy.
- **Vista Todos**: cada fila (`inventario_item_{id}`) con `AvatarInicial`, nombre, "mín. N",
  `BarraNivel` (`nivel_{id}`) bajo el nombre y, a la derecha, las existencias
  (`existencias_{id}`, color como hoy) y `EtiquetaNivel` (`etiqueta_nivel_{id}`).
- **Vista Por pedir**: encabezado del grupo con ícono `local_shipping_rounded`; "Ver pedido
  sugerido" (`ver_pedido_{id|sin}`) pasa a `FilledButton.tonal`. Cada fila
  (`por_pedir_{id}`) con `EtiquetaNivel`. Si no hay nada por pedir: `EstadoVacio` con ícono
  `check_circle_rounded` y título "Todo en orden"; la clave `texto_nada_por_pedir` va en el
  `EstadoVacio`.
- **Entradas recibidas**: `TituloSeccion`; cada fila (`entrada_{id}`) con ícono de camión
  en círculo (`entra` al 15 %), "{proveedor}" de título, "{fecha} · {usuario}" de subtítulo y
  `Monto` a la derecha (tachado si está anulada).
- Secciones con `EntradaEscalonada`.

### 3.2 Detalle (`detalle_inventario_screen.dart`)

- **Tarjeta héroe** (`tarjeta_existencias`): `existencias_detalle` en 40 px w800,
  `EtiquetaNivel`, "mín. N" y, si hay, "· pedir hasta M"; `BarraNivel`.
- "Ajustar conteo" (`boton_ajustar_conteo`) igual.
- **Historial** dentro de una tarjeta con `TituloSeccion`; cada movimiento
  (`movimiento_inventario_{i}`) con `IconoCuadrado`: entrada → `call_received_rounded` en
  `entra`; conteo inicial y ajuste → `edit_rounded` en `textoSecundario`. Texto actual y
  fecha.

### 3.3 Recibir mercancía y Pedido sugerido

- El total y el botón se mueven a `BarraAccionFija` como `bottomNavigationBar`; se
  conservan `total_recibir`/`boton_guardar_recibir` y `total_pedido`/
  `boton_recibir_pedido`. El total conserva su texto actual ("Total $X", "Total estimado
  $X"), ahora a 20 px w800.
- Cada línea de producto es una `Card` con nombre (w600), botones −/+ redondos de 40 px
  envueltos en `Aplastable`, cantidad y precio de compra. Se conservan todas las claves
  (`restar_*`, `sumar_*`, `cantidad_*`, `precio_*`, `quitar_recibir_*`).
- Los chips de proveedor (`opcion_proveedor_recibir_*`) se mantienen con el estilo del tema.
- Error, nota y "Agregar producto": como hoy.

### 3.4 Hoja de ajuste de conteo y detalle de entrada

- **Ajuste de conteo**: cabecera con el nombre del producto (18 px w700) y
  `texto_segun_app` debajo; campos con el radio del tema; `boton_guardar_conteo` sigue como
  `BotonPrincipal`.
- **Detalle de entrada**: tarjeta de cabecera (`cabecera_entrada`) con proveedor, fecha,
  usuario y `Monto` del total (tachado si anulada); líneas en tarjeta;
  `boton_anular_entrada` pasa a `BotonPrincipal` variante `peligro`; el diálogo de
  confirmación queda igual (`confirmar_anular_entrada`).

## 4. Configuración

### 4.1 Productos (`productos_screen.dart`)

- **Buscador** (`campo_buscar_productos`) arriba, con ícono de lupa y botón para borrar:
  filtra activos e inactivos comparando `claveNombre(nombre)` con `claveNombre(consulta)`
  (`contains`). Si la consulta no está vacía y nada coincide: texto "Ningún producto
  coincide" (`texto_sin_coincidencias`).
- Cada fila (`producto_item_{id}`) con `AvatarInicial`, nombre, `Monto` del precio (16 px)
  y píldora de margen (`margen_{id}`): "gana {m}" en `entra` si m ≥ 0, "pierde {−m}" en
  `sale` si m < 0, "sin costo" en `textoSecundario` si no hay costo. El botón de desactivar
  se conserva.
- Inactivos: `TituloSeccion` "INACTIVOS"; filas atenuadas con "Reactivar" como hoy.
- Filas con `EntradaEscalonada` (hasta 8).

### 4.2 Ficha de producto (`producto_screen.dart`)

- **Vista previa** (`vista_previa_producto`) arriba: `AvatarInicial`, nombre ("Sin nombre" si
  está vacío, para no repetir el título) y `Monto` del precio, que se actualizan al escribir.
- El formulario se agrupa en tres tarjetas con `TituloSeccion`: "DATOS" (nombre y precio),
  "PROVEEDORES Y COSTO" (filas de proveedor, "Agregar proveedor" y `texto_resumen_costo`) y
  "EXISTENCIAS" (interruptor y sus campos).
- El diálogo "¿Dejar de controlar existencias?" mantiene su clave de confirmación con el
  botón en variante `peligro`.
- Sin cambios de lógica, validaciones ni claves.

### 4.3 Proveedores (`proveedores_screen.dart`)

- Cada fila (`proveedor_item_{id}`) con `AvatarInicial`, nombre, teléfono con ícono
  `phone_rounded` si lo tiene (solo visual) y "Surte N productos" en una píldora
  (`texto_surte_{id}`). Desactivar y reactivar como hoy; inactivos como en Productos.

### 4.4 Usuarios (`usuarios_screen.dart`)

- Cada fila (`usuario_item_{id}`) con `AvatarInicial(id, nombre)`, nombre con " (tú)" si
  es el usuario de la sesión, y chip de rol (`rol_{id}`, `Pildora`): "Administrador" con
  `primario`, "Vendedor" con `marcaVerde`.
- La hoja de nuevo usuario y el diálogo de resetear PIN conservan flujo y claves; sus
  botones de acción son `BotonPrincipal`.

### 4.5 Respaldo (`respaldo_screen.dart`, `verificar_telefono_screen.dart`)

- **Tarjeta de estado** (`tarjeta_estado_respaldo`): ícono de nube de 28 px en un círculo de
  56 px (`entra` al 15 % si activo), "Respaldo activo", celular enmascarado y
  `texto_ultimo_respaldo`.
- "Respaldar ahora" igual. "Desconectar" (`boton_desconectar`) pasa a variante `contorno` y
  abre una confirmación "¿Desconectar el respaldo?" con "Cancelar" y "Desconectar"
  (`confirmar_desconectar`, `peligro`); solo al confirmar llama a `desconectar()`.
- Verificación del teléfono: solo estilo (campos con el radio del tema, `BotonPrincipal`
  para las acciones, texto explicativo en `textoSecundario`). Sin cambios de flujo ni claves.

### 4.6 Configurar QR (`configurar_qr_screen.dart`)

- El QR (`vista_qr`) dentro de una tarjeta blanca (`ColoresApp.blancoMarca`), radio 24,
  padding 16 y sombra suave, como en el cobro.
- Debajo, tres pasos numerados (`pasos_qr`): "1 Descarga tu QR de Nequi, Daviplata o tu
  banco", "2 Cárgalo aquí", "3 Cobra mostrándolo en la venta"; reemplazan el texto actual.
- "Cargar/Cambiar QR" igual; "Quitar QR" (`boton_quitar_qr`) pasa a `BotonPrincipal`
  variante `contorno`; la confirmación queda igual.

## Fuera de alcance

Llamar o abrir WhatsApp desde proveedores, exportar inventario, cambios en la lógica de
pedido sugerido o de respaldo, cambios de esquema.

## Pruebas

- **Unitarias**: `nivelExistencias` (−1 → agotado, 0 → agotado, igual al mínimo → bajo,
  mínimo + 1 → ok, mínimo 0 con 1 → ok); `fraccionNivel` (con pedir hasta, con 2 × mínimo,
  sin ninguno → 1, existencias ≤ 0 → 0, tope superado → 1).
- **Ajustes**: la cabecera muestra el nombre de la tienda y "usuario · rol"; tocarla abre la
  hoja; "Activo" en Respaldo solo cuando el respaldo está activo.
- **Inventario**: resumen con conteos correctos (incluye agotados); etiqueta y barra por
  producto; "Todo en orden" sin nada por pedir; entradas con monto tachado si anuladas.
- **Detalle**: tarjeta héroe con etiqueta; íconos por tipo de movimiento.
- **Recibir/Pedido**: con una lista larga, el total y el botón siguen visibles
  (`tester.getRect` dentro de la pantalla) sin desplazarse.
- **Productos**: el buscador filtra sin tildes ("cafe" encuentra "Café"); sin coincidencias
  muestra el texto; píldora de margen positiva, negativa y sin costo.
- **Usuarios**: chip de rol y "(tú)" solo para el usuario de la sesión.
- **Respaldo**: "Desconectar" pide confirmación; cancelar no desconecta.
- **Las pruebas actuales siguen pasando** (se ajustan solo las que tocan
  `boton_desconectar` o el texto reemplazado del QR).
- **Modo oscuro y letra 2,0× a 360 dp sin excepciones** en Inventario, detalle, Recibir,
  Pedido, hoja de ajuste, detalle de entrada, Ajustes, Productos, ficha de producto,
  Proveedores, Usuarios, Respaldo y Configurar QR.

## Entrega

Rama `renovacion-r4`; plan en `docs/superpowers/plans/`; APK al final; actualizar
`docs/hoja-de-ruta.md`.
