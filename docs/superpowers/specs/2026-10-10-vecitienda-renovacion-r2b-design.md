# Renovación de la interfaz — R2b: recorrido de primer uso

**Fecha:** 2026-10-10
**Estado:** Implementado (falta el recorrido manual en un celular real)
**Base:** master con R1 y R2a (4f2abbe, 598 pruebas).

## Contexto

La renovación busca que VeciTienda impresione al **mostrarla y venderla**. El usuario pidió un
**recorrido sobre la app real** en el que el tendero va conociendo la app **mientras diligencia
su propia información**, en vez de una tienda de ejemplo o un carrusel (ambos descartados).

Decisiones tomadas con el usuario:

- Productos del recorrido: **carga rápida** (solo nombre y precio de venta).
- **Cada paso se puede omitir** salvo "Tu tienda"; existe "Saltar recorrido" y, en Ajustes,
  "Ver el recorrido otra vez".
- La primera venta guiada es **de práctica**: no queda en las cuentas.
- Globos con **sistema propio** (sin paquetes), enfoque A.

Sin cambios de esquema de base de datos ni dependencias nuevas.

## 1. Flujo

El recorrido arranca al tocar **"Crear tienda nueva"** en la Bienvenida. Restaurar un respaldo
no lo activa. Las pantallas de pasos muestran `IndicadorPasos` ("Paso N de 4" + barra).

| Paso | Pantalla | Obligatorio | Al terminar |
|---|---|---|---|
| 1 · Tu tienda | `PasoTiendaScreen` | Sí | crea tienda y admin, inicia sesión, guarda paso `productos` y abre el paso 2 |
| 2 · Tus primeros productos | `PasoProductosScreen` | No ("Omitir") | guarda paso `venta` y abre el paso 3 |
| 3 · Tu primera venta (práctica) | `PasoVentaScreen` → `RegistrarVentaScreen(practica: true)` | No | guarda paso `inicio` y vuelve al Inicio |
| 4 · Conoce tu Inicio | globos sobre `HomeScreen` | No | guarda paso `hecho` y muestra "¡Listo! Tu tienda está lista" |

### Paso 1 · Tu tienda

`PasoTiendaScreen` reemplaza a `CrearAdminInicialScreen` (mismo contenido y validaciones:
nombre de la tienda con `errorNombreTienda`, "Escribe tu nombre", PIN de 4 dígitos) con el
`IndicadorPasos` arriba y el botón "Continuar". Tras crear e iniciar sesión, en vez de volver
al Inicio, reemplaza la ruta por el paso 2 (`pushReplacement`); al terminar o omitir los pasos
2 y 3, la navegación vuelve al Inicio (que ya está debajo, porque `RaizApp` muestra
`HomeScreen` al haber sesión).

### Paso 2 · Tus primeros productos

- Título "Tus primeros productos" y "Escribe lo que más vendes. El costo, el proveedor y las
  existencias los completas después en Productos."
- Lista de filas `nombre` + `precio de venta` (teclado numérico, formato de pesos); empieza con
  **3 filas vacías**; "+ Agregar otro" agrega una fila (máximo 20).
- "Guardar y continuar":
  - Filas totalmente vacías se ignoran.
  - Fila con nombre sin precio (o precio sin nombre, o precio 0): se marca en rojo con
    "Falta el precio" / "Falta el nombre" y no avanza.
  - Nombres repetidos entre filas (comparados con `claveNombre`) o iguales a un producto ya
    existente: se marcan "Ya está en la lista" y no avanza.
  - Si todo es válido, crea cada producto con `ProductoRepository.crearProducto` y avanza.
  - Sin filas completas, "Guardar y continuar" se comporta como "Omitir".
- "Omitir" avanza sin guardar.

### Paso 3 · Tu primera venta (práctica)

- `PasoVentaScreen`: ilustración (ícono grande `Icons.point_of_sale_rounded`), "Hagamos una
  venta de práctica", "Así aprendes a cobrar. No quedará en tus cuentas.", botones
  "Empezar" y "Omitir".
- "Empezar" abre `RegistrarVentaScreen(practica: true)` con los globos de acción:
  1. `primer_producto` (alternativa: `monto_rapido_1000`): "Toca un producto para sumarlo al
     ticket." — avanza al agregar algo al ticket.
  2. `boton_cobrar`: "Aquí ves el total. Toca Cobrar." — avanza al abrirse la hoja.
  3. `pago_efectivo`: "Elige cómo paga. Toca Efectivo." — avanza al elegir.
- Al terminar (o "Omitir" en un globo) se guarda el paso `inicio` y se vuelve al Inicio.

### Paso 4 · Conoce tu Inicio

Globos informativos, en orden:

1. `tarjeta_ventas`: "Aquí ves cuánto vendiste hoy y cómo vas frente a ayer."
2. `boton_nueva_venta`: "Registra cada venta aquí."
3. `pestana_fiado`: "Aquí está lo que te deben tus clientes."
4. `menu_cuenta`: "Tu cuenta: cerrar sesión y cambiar la apariencia."

Al terminar: hoja "¡Listo! Tu tienda está lista" con botón "Empezar a vender"; paso `hecho`.

### Omitir y repetir

- Cada globo tiene "Saltar recorrido" (paso `hecho` y cierra la capa).
- Ajustes (solo admin): fila "Ver el recorrido otra vez" (`boton_repetir_recorrido`) que pone el
  paso en `venta` y abre `PasoVentaScreen` (repite práctica + globos del Inicio; no recrea la
  tienda).

### Estado y reanudación

- `recorridoProvider` (`NotifierProvider<RecorridoNotifier, PasoRecorrido>`) con
  `enum PasoRecorrido { ninguno, productos, venta, inicio, hecho }`, guardado en
  `shared_preferences` (clave `recorrido_paso`). Valor ausente o ilegible → `ninguno`
  (instalaciones previas y restauraciones no ven el recorrido).
- Métodos: `iniciar()` → `productos`; `irA(PasoRecorrido)`; `saltar()` → `hecho`.
- `HomeScreen`, al construirse con sesión de **administrador**:
  - `productos` → abre `PasoProductosScreen`; `venta` → abre `PasoVentaScreen`;
  - `inicio` → lanza los globos del paso 4 tras el primer cuadro.
  - Lo hace una sola vez por montaje (bandera como `_pidioNombre`).
- Los vendedores nunca ven el recorrido.

## 2. Sistema de globos (`lib/ui/recorrido/`)

- `ObjetivoRecorrido({required String id, required Widget child})`: registra un `GlobalKey`
  para `id` en un registro global (`RegistroObjetivos`, mapa `id → GlobalKey`; se quita al
  desmontarse). Se agrega a: `tarjeta_ventas`, `boton_nueva_venta` (Inicio), destino Fiado de la
  `NavigationBar` (`pestana_fiado`), `menu_cuenta`, primer mosaico de producto
  (`primer_producto`), `monto_rapido_1000`, `boton_cobrar`, `pago_efectivo`.
- `PasoGlobo({required List<String> objetivos, required String texto, bool deAccion = false})`:
  `objetivos` en orden de preferencia (se usa el primero que exista).
- `CapaGlobos` (en el `Overlay` del `Navigator`):
  - Velo `ColoresApp.velo` con hueco `RRect` (margen 8, radio 18) sobre el rectángulo del
    objetivo (calculado del `RenderBox`, recalculado en cada cuadro por si hay scroll o
    teclado).
  - Burbuja (superficie, radio 18, sombra) con flecha hacia el objetivo, encima si hay más
    espacio arriba, si no debajo; ancho máx. 320; entra con `Movimiento.resorte`
    (`Movimiento.duracion`).
  - Informativo: botones "Saltar recorrido" (texto) y "Siguiente" / "Terminar" (píldora).
    De acción: solo "Saltar recorrido"; el toque dentro del hueco llega al objetivo.
  - Toques fuera del hueco y de la burbuja se absorben.
  - Antes de mostrar un paso: `Scrollable.ensureVisible` del objetivo. Si ningún objetivo del
    paso existe, se salta ese paso.
  - Accesibilidad: `Semantics(liveRegion: true)` con el texto del globo; botones ≥ 48 dp;
    la burbuja escala con la letra (se ajusta dentro de la pantalla).
- `ControladorGlobos` (devuelto por `mostrarGlobos(context, pasos, {onTerminar, onSaltar})`):
  `avanzar()` (lo llaman las pantallas para los globos de acción), `cerrar()`.
- Token nuevo `velo` en `ColoresApp`: claro `#B30F172A` (negro azulado 70 %), oscuro
  `#CC000000` (negro 80 %); se agrega a `lerp`.

## 3. Modo práctica en Nueva venta

`RegistrarVentaScreen({bool practica = false, ControladorGlobos? globos})`:

- Franja superior `franja_practica`: "MODO PRÁCTICA · no se guarda" (fondo `fiadoSuave`, texto
  `fiado`, w700).
- Al elegir forma de pago en la hoja: **no** llama a `VentaRepository`, `ClienteRepository` ni
  `abrirCobroQr`; no hay aviso con "Deshacer". Muestra la hoja `hoja_asi_de_facil`:
  "¡Así de fácil!", el total y artículos del ticket, "Esta venta fue de práctica, no quedó en
  tus cuentas." y "Continuar" (`boton_continuar_practica`), que vacía el ticket y cierra la
  pantalla devolviendo `true`.
- Notifica al `ControladorGlobos` (si hay): al agregar el primer artículo, al abrirse la hoja
  "¿Cómo paga?" y al elegir forma de pago.

## Fuera de alcance

Carrusel, tienda de ejemplo, recorrido para vendedores, globos en otras pantallas (Fiado,
Reportes, Inventario), y las tandas R3 y R4.

## Pruebas

- **Estado:** `recorrido_paso` se guarda y se lee; ilegible → `ninguno`; `saltar()` → `hecho`;
  `HomeScreen` reabre el paso pendiente para admin y no para vendedor; restaurar respaldo deja
  `ninguno`.
- **Paso 1:** validaciones actuales (migrar `crear_admin_inicial_screen_test.dart`); al
  continuar crea admin y tienda y abre el paso 2.
- **Paso 2:** guarda solo filas completas; fila a medias marcada y sin avanzar; repetido en la
  lista o existente marcado; "Omitir" no guarda; máximo 20 filas.
- **Práctica:** tras cobrar con Efectivo, Transferencia y Fiado (cliente escrito): 0 ventas,
  0 clientes nuevos, 0 movimientos de inventario; con Transferencia no se abre el QR; franja
  visible; hoja "¡Así de fácil!"; "Continuar" vuelve con el ticket vacío.
- **Globos:** el hueco coincide con el objetivo; toque dentro llega al objetivo (de acción) y
  fuera no hace nada; "Siguiente" avanza; "Saltar recorrido" cierra y guarda `hecho`; usa la
  alternativa si falta el objetivo; sin excepciones en modo oscuro y con letra 1,6×.
- **Recorrido completo:** Bienvenida → paso 1 → 2 → 3 (práctica guiada) → 4 → "¡Listo!", con
  `recorrido_paso = hecho` y sin ventas en la base.
- **Ajustes:** "Ver el recorrido otra vez" abre el paso 3 y no recrea nada.

## Entrega

Rama `renovacion-r2b`; plan en `docs/superpowers/plans/`; APK al final; actualizar
`docs/hoja-de-ruta.md`.
