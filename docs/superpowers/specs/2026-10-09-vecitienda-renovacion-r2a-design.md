# Renovación de la interfaz — R2a: pantallas de demo renovadas

**Fecha:** 2026-10-09
**Estado:** Implementado (falta el recorrido manual en un celular real)
**Base:** master con R1 (669e62a, 563 pruebas). Sistema visual de R1: `ColoresApp.of(context)`,
`Movimiento`, `Vibracion`, `MontoAnimado`, `EntradaEscalonada`, radios de `tema_app.dart`.

## Contexto

La renovación busca que VeciTienda impresione al **mostrarla y venderla** a otros tenderos. La
R2 original se dividió:

- **R2a (esta):** Inicio tipo tablero, Nueva venta y cobro, "¿Quién eres?" y PIN.
- **R2b (siguiente):** recorrido de primer uso sobre la app real, en el que el tendero conoce
  la app mientras diligencia su información (tienda y dueño → primeros productos → primera
  venta guiada con globos → llegada al Inicio con globos). Va después porque sus globos señalan
  elementos de las pantallas que rediseña la R2a.

Descartado por el usuario: tienda de ejemplo / datos de demostración y carrusel de bienvenida.

Decisiones tomadas con maquetas: Inicio **A · Tarjeta héroe**; Nueva venta **A · Primero el
ticket, al final cómo paga**.

Sin cambios de esquema de base de datos ni dependencias nuevas. Lo que se guarda de cada venta
no cambia.

## 1. Inicio tipo tablero

Archivo principal: `lib/screens/home/resumen_screen.dart` (y `home_screen.dart` para los
botones fijos).

### Distribución (de arriba abajo)

1. Encabezado azul de `HomeScreen` (insignia, "Hola, …", nombre de la tienda): sin cambios.
2. `SelectorFecha` en forma de píldora (`radioCampo` → `StadiumBorder`, fondo `superficie`),
   mismo comportamiento.
3. **Tarjeta del día** (`tarjeta_ventas`, `tarjetaPrincipal`, radio `radioTarjetaPrincipal`):
   - Título: "Ventas de hoy" si el día elegido es hoy; si no, "Ventas del 7 oct".
   - `Monto(…, tamano: 36, tono: claro, animado: true)`.
   - **Etiqueta de comparación** con el día anterior al elegido (`comparacion_ventas`):
     | Caso | Texto | Color |
     |---|---|---|
     | anterior = 0 y día = 0 | (no se muestra) | — |
     | anterior = 0 y día > 0 | "Ayer no hubo ventas" | `sobreTarjetaPrincipal` 75 % |
     | día > anterior | "▲ N % vs. ayer" | píldora con fondo `entra` al 22 % sobre la tarjeta |
     | día < anterior | "▼ N % vs. ayer" | píldora con fondo `sale` al 22 % sobre la tarjeta |
     | día = anterior | "Igual que ayer" | `sobreTarjetaPrincipal` 75 % |
     | distintos pero N redondea a 0 | "Casi igual que ayer" | `sobreTarjetaPrincipal` 75 % |
     N = `((dia − anterior) / anterior × 100).round().abs()`. El texto de las píldoras va
     siempre en `sobreTarjetaPrincipal` (contraste ≥ 7:1 en ambos modos; con texto verde/rojo
     el modo oscuro no llega a 4,5:1). Cuando el día elegido no es hoy, "ayer" se reemplaza por
     "el día anterior".
   - Detalle: "N ventas · M fiadas" y "Efectivo $ … · Transf. $ …" (contenido actual).
   - **Mini gráfica** (`MiniGraficaSemana`, nuevo en `lib/screens/home/mini_grafica_semana.dart`):
     7 barras de los 7 días que terminan en el día elegido, alto proporcional al máximo de la
     semana (todas en cero → barras mínimas de 4 px), barras en `sobreTarjetaPrincipal` 30 % y
     la del día elegido en `marcaVerde`; debajo, la inicial del día (L M M J V S D). Las barras
     crecen desde abajo con `Movimiento.resorte` la primera vez (respeta reducir movimiento).
     Semántica accesible: "Ventas de los últimos 7 días" + lista de valores. Tocar la gráfica
     abre Reportes (mismo destino que "Ver reportes").
4. **Mosaicos** (`TarjetaMonto`): Ganancia y Gastos lado a lado; **Por cobrar** a todo el ancho
   con fondo `fiadoSuave` y `onTap` → pestaña Fiado (como hoy).
5. **Por vendedor** en una tarjeta con título y enlace "Ver reportes ›" a la derecha. Misma
   visibilidad que hoy: la tarjeta la ven todos; el enlace, solo el administrador.
6. Se quitan de la lista los botones "+ Venta", "− Gasto" y "Ver reportes" (pasan a 7 y al
   enlace de 5).
7. **Botones fijos abajo** (solo en la pestaña Inicio): barra sobre la `NavigationBar` con
   "+ Venta" (`BotonPrincipal` variante `entra`, flex 1) y "− Gasto" (variante `peligro`,
   flex 0,6), con fondo `fondo` y sombra suave arriba. Mismas acciones y claves de hoy
   (`boton_nueva_venta`, `boton_nuevo_gasto`); el enlace del punto 5 conserva
   `boton_ver_reportes`. La lista deja un
   espacio final para que el contenido no quede tapado.

### Datos

- `ResumenRepository.ventasDiarias(DateTime hasta, {int dias = 7})` → `Future<List<int>>`:
  total vendido (contado + fiado, sin anuladas, mismo criterio que `resumenDelDia`) de cada uno
  de los `dias` días que terminan en `hasta` (incluido), del más antiguo al más reciente. Una
  sola consulta agrupada por día.
- `ventasDiariasProvider` (`FutureProvider.autoDispose.family<List<int>, DateTime>`, clave
  normalizada con `inicioDelDia`) que observa los mismos cambios que `resumenDelDiaProvider`.
- La comparación usa los dos últimos valores de esa lista.
- Ambos `when` del Inicio usan `skipLoadingOnReload: true` (lección de R1).

## 2. Nueva venta

Archivo: `lib/screens/venta/registrar_venta_screen.dart`.

### Pantalla

- Se quitan los selectores Contado/Fiado y Efectivo/Transferencia y el `SelectorCliente` de
  arriba.
- **Buscador** (`buscador_productos`): campo con ícono de lupa, "Buscar producto…". Filtra la
  grilla por nombre, sin distinguir mayúsculas ni tildes (`á→a`, `é→e`, `í→i`, `ó→o`, `ú→u`,
  `ü→u`, `ñ` se conserva), coincidencia en cualquier parte del nombre. Con texto y sin
  resultados: "Sin resultados" y el mosaico "+ Otro monto" sigue visible. El texto se limpia al
  vaciar el ticket. El buscador solo se muestra si hay más de 6 productos activos.
- Grilla de productos y montos rápidos: igual que hoy (mosaicos de R1). La insignia de
  cantidad hace un pequeño rebote (escala 1,25 → 1 con `resorte`) cuando cambia.
- **Barra de cobro**: flotante, radio 24 arriba, "N artículos · Ver ticket · Vaciar" y botón
  píldora "Cobrar $ X" (`boton_cobrar`), deshabilitado con el ticket vacío.

### Hoja "¿Cómo paga?"

Al tocar Cobrar se abre una hoja inferior (`hoja_como_paga`) con título "Cobrar $ X" y
"N artículos · ¿Cómo paga?", y tres opciones en tarjetas de toque completo:

| Opción | Clave | Acción |
|---|---|---|
| Efectivo | `pago_efectivo` | `cambiarFiado(false)`, `cambiarMedioPago(efectivo)`, cierra la hoja y registra (flujo `_cobrar` actual). |
| Transferencia (mostrar QR) | `pago_transferencia` | `cambiarFiado(false)`, `cambiarMedioPago(transferencia)`, cierra la hoja y sigue el flujo actual con `abrirCobroQr` (con "Recibido" registra como transferencia; sin QR, igual que hoy). |
| Fiado | `pago_fiado` | Oculta Efectivo y Transferencia y expande dentro de la hoja el `SelectorCliente` existente (`exigir: true`) y un botón "Fiar $ X a {cliente}" (`boton_fiar`), deshabilitado sin cliente. Al tocarlo: `cambiarFiado(true)` + cliente, cierra la hoja y registra. |

Cerrar la hoja sin elegir no cambia el ticket. El aviso con "Deshacer" y el regreso al Inicio
son los de hoy. `TicketNotifier` conserva su API; `esFiado`/`medioPago` se fijan desde la hoja
justo antes de cobrar.

## 3. "¿Quién eres?"

Archivo: `lib/screens/login/seleccionar_usuario_screen.dart`.

- Arriba `MarcaApp` (logo con insignia) y nombre de la tienda; título "¿Quién eres?" y
  "Toca tu nombre para entrar".
- Usuarios en **grilla de 2 columnas** de tarjetas (`usuario_{id}`, se conserva la clave):
  `AvatarInicial` radio 36, nombre (18, w700) y rol; radio `radioTarjeta`, superficie.
  Con un solo usuario, una tarjeta a todo el ancho. Con letra grande la grilla pasa a 1 columna
  si el nombre no cabe (alto flexible, sin desbordes).
- Tocar: se aplasta (mismo efecto que `BotonPrincipal`; se extrae el `_Aplastable` de
  `boton_principal.dart` a `lib/ui/aplastable.dart` como `Aplastable` público), vibra
  (`Vibracion.toque`) y navega al PIN.
- El avatar va en un `Hero(tag: 'avatar_{id}')` que coincide con el del PIN.
- Las tarjetas entran con `EntradaEscalonada`.

## 4. PIN

Archivo: `lib/screens/login/ingresar_pin_screen.dart` y `lib/widgets/teclado_numerico.dart`.

- `AvatarInicial` radio 44 dentro de `Hero(tag: 'avatar_{id}')`; "Hola, {nombre}" (Nunito) y
  el nombre de la tienda.
- **Indicadores** (`IndicadoresPin`, nuevo en `lib/widgets/indicadores_pin.dart`): 4 círculos
  de 16 px; lleno = `primario`, vacío = aro `textoSecundario` (con `borde` el contraste era 1,2:1). Al llenarse uno, rebote (escala
  1,3 → 1, `resorte`, `Movimiento.media`).
- **PIN incorrecto:** los indicadores se sacuden horizontalmente (desplazamientos ±12, ±8, ±4,
  0 px en ~400 ms), se pintan de `sale` durante la sacudida y vuelven a vacío; vibra
  `Vibracion.error()` (ya existe) y aparece "PIN incorrecto" en `sale`. Con reducir movimiento:
  sin sacudida ni rebote; color y texto sí.
- **Teclado:** teclas circulares de 76 px (antes 72) con el efecto `Aplastable`; "borrar" con
  `Icons.backspace_outlined`. Se conservan las claves `tecla_{n}` y `tecla_⌫`.

## Fuera de alcance

Recorrido de primer uso y globos (R2b); Fiado, Reportes, Historial, Gasto, Corrección y
Cobro QR (R3); administración (R4). La pantalla de cobro QR solo se reutiliza.

## Pruebas

- **`ventasDiarias`:** 7 valores en orden; días sin ventas en 0; excluye anuladas; incluye
  fiado; respeta el límite del día (venta a las 23:59 y a las 00:00).
- **Comparación:** cada fila de la tabla de la sección 1 (incluido "Casi igual" y "el día
  anterior" cuando no es hoy).
- **Mini gráfica:** 7 barras, la del día elegido resaltada, todas en cero sin error, tocarla
  abre Reportes.
- **Inicio:** botones fijos visibles en la pestaña Inicio y ausentes en las demás; "Por
  cobrar" lleva a Fiado; contenido no tapado (el último elemento es visible al desplazar).
- **Buscador:** filtra con tildes/mayúsculas, "Sin resultados", oculto con ≤ 6 productos,
  se limpia al vaciar.
- **Hoja ¿Cómo paga?:** efectivo registra con medio efectivo; transferencia abre el cobro QR y
  registra como transferencia con "Recibido"; fiado sin cliente no deja fiar, con cliente
  registra fiado con ese cliente; cerrar la hoja no registra nada.
- **"¿Quién eres?":** grilla de 2 columnas, un usuario a todo el ancho, letra grande sin
  desbordes, tocar abre el PIN.
- **PIN:** sacudida + color `sale` + texto con PIN incorrecto; con reducir movimiento sin
  sacudida; rebote del indicador; las pruebas actuales de inicio de sesión siguen pasando.
- **Modo oscuro:** las pantallas tocadas se dibujan en oscuro sin excepciones (ampliar
  `test/screens/modo_oscuro_test.dart`).
- Se actualizan las pruebas existentes que dependan de los selectores quitados de Nueva venta
  o de los botones movidos del Inicio, sin perder lo que verificaban.

## Entrega

Rama `renovacion-r2a`; plan en `docs/superpowers/plans/`; APK de prueba al final; actualizar
`docs/hoja-de-ruta.md`.
