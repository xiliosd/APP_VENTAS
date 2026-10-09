# Renovación de la interfaz — R1: base (modo oscuro y estilo Expressive)

**Fecha:** 2026-10-09
**Estado:** Diseño aprobado en conversación; pendiente revisión de esta especificación
**Base:** master con el pulido completo (df205ac, 530 pruebas).

## Contexto

El usuario quiere que VeciTienda se vea moderna para **mostrarla y venderla** a otros tenderos.
Pidió verificar las prácticas de UX actuales y renovar **toda la app**. Se investigaron (2026):
Material 3 Expressive (estilo de Android 16: formas, resorte, tipografía enfatizada),
microinteracciones y vibración, flujos centrados en la tarea (POS), contar con datos en el
tablero, modo oscuro, primera impresión (bienvenida, vacíos guiados) y respeto por la
accesibilidad (letra grande, reducir movimiento).

Enfoque elegido: **A · evolucionar el sistema de diseño propio** (`lib/ui/`) hacia Expressive,
sin paquetes nuevos, en 4 tandas:

| Tanda | Contenido |
|---|---|
| **R1 · Base** (esta) | Colores por tema + modo oscuro, formas, tipografía, movimiento, vibración, transiciones, componentes. |
| R2 · Demo | Bienvenida guiada, PIN, Inicio tipo tablero (mini gráfica, % vs. ayer), Nueva venta y cobro. |
| R3 · Dinero | Fiado y detalle, Reportes, Historial, Gasto, Corrección, Cobro QR. |
| R4 · Administración | Inventario, recibir, pedido sugerido, productos, proveedores, usuarios, ajustes, respaldo, configurar QR. |

Decisiones tomadas con maquetas en el navegador: modo oscuro **"Azul noche"** (opción A) y
nivel de animación **"Expresivo"** (opción B). El claro renovado se aceptó como referencia.

## Objetivo de R1

Que toda la app cambie de aspecto a la vez (formas, movimiento, vibración) y tenga modo oscuro,
**sin cambiar la distribución ni el contenido de ninguna pantalla**. Sin cambios de esquema de
base de datos ni dependencias nuevas.

## 1. Colores por tema

### Mecanismo

- `lib/ui/colores_app.dart`: `ColoresApp` pasa a ser un `ThemeExtension<ColoresApp>` con dos
  instancias constantes, `ColoresApp.claro` y `ColoresApp.oscuro`, y el acceso
  `ColoresApp.of(context)` (`Theme.of(context).extension<ColoresApp>()!`).
- Se migran los 154 usos de `ColoresApp.x` (40 archivos) a `ColoresApp.of(context).x` (o a una
  variable local `final c = ColoresApp.of(context);`), y los 25 colores sueltos
  (`Color(0x…)`, `Colors.white`, `Colors.black`) fuera de `colores_app.dart` a tokens.
- Funciones con color por defecto constante (p. ej. `estiloTitulo({Color color = ColoresApp.texto})`
  en `tipografia.dart`) pasan a `Color? color` y el llamador usa el token del tema; si el estilo se
  usa en el tema, el tema le pone el color.
- Se excluye el arte de marca (logo, isotipo, ícono, pantalla de arranque): no cambia por tema.

### Tokens

Los existentes se conservan con el mismo nombre; se agregan `tarjetaPrincipal`,
`sobreTarjetaPrincipal`, `sobrePrimario` y `sobreEntra` (color del texto encima del relleno).

| Token | Uso | Claro | Oscuro |
|---|---|---|---|
| `fondo` | Fondo de pantallas | `#F8FAFC` | `#0B1220` |
| `superficie` | Tarjetas, barras, hojas | `#FFFFFF` | `#131C2E` |
| `borde` | Separadores, bordes de campos | `#E5E7EB` | `#243049` |
| `texto` | Texto principal | `#1E293B` | `#E2E8F0` |
| `textoSecundario` | Etiquetas, ayudas | `#64748B` | `#94A3B8` |
| `primario` | Marca, selección, enlaces, relleno de botón primario | `#1A539B` | `#9CC0F0` |
| `sobrePrimario` | Texto sobre `primario` | `#FFFFFF` | `#0B1F3F` |
| `primarioSuave` | Fondos de selección e íconos, indicador de navegación | `#DDE5F0` | `#1E3A5F` |
| `tarjetaPrincipal` | Tarjeta del monto del día, encabezado azul del Inicio | `#1A539B` | `#1B3A66` |
| `sobreTarjetaPrincipal` | Texto sobre `tarjetaPrincipal` | `#FFFFFF` | `#F1F5F9` |
| `marcaVerde` | Acentos de marca (nunca texto en claro) | `#16A34A` | `#4ADE80` |
| `entra` | Ventas, ganancia, abonos (texto) y relleno de Cobrar en claro | `#15803D` | `#4ADE80` |
| `rellenoEntra` | Relleno del botón Cobrar / confirmar | `#15803D` | `#22C55E` |
| `sobreEntra` | Texto sobre `rellenoEntra` | `#FFFFFF` | `#052E16` |
| `entraSuave` | Borde/fondo suave de ingresos | `#BBF7D0` | `#14532D` |
| `sale` | Gastos, errores, destructivo | `#DC2626` | `#F87171` |
| `saleSuave` | Borde/fondo suave de gastos | `#FECACA` | `#7F1D1D` |
| `fiado` | Fiado, por cobrar (texto) | `#B45309` | `#FBBF24` |
| `fiadoSuave` | Fondo de fiado | `#FEF3C7` | `#2A2010` |
| `fondoAviso` | Fondo del aviso flotante | `#1E293B` | `#E2E8F0` |
| `textoAviso` / `accionAviso` | Texto y acción del aviso | `#FFFFFF` / `#93C5FD` | `#0B1220` / `#1A539B` |

Requisito: todo par texto/fondo usado cumple contraste **≥ 4,5:1** (texto ≥ 24 px o 19 px negrita:
≥ 3:1) en ambos modos. Si un valor de la tabla no lo cumple al probarlo, se ajusta su luminosidad
manteniendo el tono y se actualiza esta tabla.

### Elegir el tema

- `ThemeMode` por defecto: **sistema** (Automático).
- Menú de la cuenta (avatar, `_MenuCuenta` en `home_screen.dart`): nueva entrada
  **"Apariencia"** que abre una hoja con un selector de tres opciones *Automático / Claro /
  Oscuro*. Está disponible para todo usuario (Ajustes es solo de administradores).
- La elección se guarda por celular en `shared_preferences` (clave `apariencia`, valores
  `sistema|claro|oscuro`) mediante un provider de Riverpod (`aparienciaProvider`), y
  `MaterialApp` recibe `theme: temaClaro()`, `darkTheme: temaOscuro()` y `themeMode`.
- Si la lectura falla, se usa Automático.

## 2. Forma

| Elemento | Hoy | R1 |
|---|---|---|
| Tarjeta principal | 12 | **24** |
| Tarjetas | 12, con borde | **18**; sin borde en claro (contraste por color de superficie sobre fondo); en oscuro, superficie más clara que el fondo |
| Campos de texto | 12 | 14 |
| Botones principales (`FilledButton`, `BotonPrincipal`) | 16 | **píldora** (`StadiumBorder`) |
| Hojas inferiores | 20 arriba | 28 arriba |
| Diálogos | 20 | 28 |
| Aviso flotante | 12 | píldora |
| Indicador de la barra de navegación | píldora (Material) | píldora; se desliza entre pestañas |

Botón presionado ("aplastar"): escala a **0,94** y radio a 18; al soltar vuelve con curva de
resorte. Áreas de toque siguen ≥ 48 dp.

## 3. Tipografía

- Se mantienen **Inter** (cuerpo y montos) y **Nunito** (títulos de marca).
- Monto principal: 32 → **36**, peso 800, `letterSpacing` −0,5, cifras tabulares.
- Título de pantalla: 20 → **22**.
- El resto de la escala no cambia. Todo sigue escalando con el ajuste de letra del celular
  (comportamiento de la tanda 2 de pulido intacto).

## 4. Movimiento

Nuevo `lib/ui/movimiento.dart` con todas las duraciones y curvas (ningún archivo define las
suyas):

- `Movimiento.resorte` — curva con rebote (equivalente a `cubic-bezier(.34, 1.6, .5, 1)`), para
  presionar, aparecer y el aviso.
- `Movimiento.enfatizada` — `Curves.easeInOutCubicEmphasized`, para entrar/salir.
- Duraciones: `corta` 150 ms, `media` 300 ms, `larga` 500 ms, `conteo` 700 ms.
- `Movimiento.reducido(context)` → `true` si `MediaQuery.disableAnimationsOf(context)`; en ese
  caso todas las animaciones de la app duran 0 y los conteos muestran el valor final.

Usos en R1:

- **`MontoAnimado`** (nuevo, `lib/ui/monto_animado.dart`): cuando el valor cambia, cuenta desde
  el anterior hasta el nuevo en `conteo` con desaceleración; la primera vez muestra el valor sin
  animar. Mismo formato que `Monto`. Se usa en `TarjetaMonto` y en `Monto` cuando se pide
  `animado: true`.
- **Entrada escalonada** (`lib/ui/entrada_escalonada.dart`): envoltorio para los primeros
  elementos de una lista (hasta 8): suben 24 px y aparecen con `resorte`, 60 ms de diferencia
  entre uno y otro, **solo la primera vez** que se construye la pantalla, no al desplazarse ni
  al recargar datos. En R1 se aplica a las tarjetas del Inicio; las demás pantallas lo adoptan
  en R2–R4.
- **Transiciones entre pantallas**: `pageTransitionsTheme` con
  `FadeForwardsPageTransitionsBuilder` (Android) en el tema.
- **Aviso** (`avisos.dart`): entra desde abajo con `resorte`.
- **Barra de navegación**: el indicador se desliza con `enfatizada`.

## 5. Vibración

Nuevo `lib/ui/vibracion.dart`, con `HapticFeedback` de Flutter (sin paquete):

| Función | Cuándo | Llamada |
|---|---|---|
| `Vibracion.toque()` | Tocar producto o monto rápido, tecla del PIN o teclado, cambiar de pestaña | `selectionClick` |
| `Vibracion.exito()` | Cobrar, guardar, abonar, aviso de éxito | `mediumImpact` |
| `Vibracion.error()` | PIN incorrecto, dato faltante, aviso de error | `heavyImpact` |

Sin interruptor propio: el sistema operativo respeta la configuración de vibración del usuario.
En R1 se conectan los componentes (`BotonPrincipal`, teclados, `MontoRapidoGrid`, navegación,
`avisos.dart`); las pantallas que llamen directamente a avisos de éxito/error vibran a través de
estos.

## 6. Componentes afectados

`lib/ui/`:
- `tema_app.dart` — `temaClaro()` y `temaOscuro()` desde un constructor común que recibe
  `ColoresApp`; formas, tipografía y transiciones de las secciones 2–4; registra la extensión.
- `colores_app.dart` — sección 1.
- `boton_principal.dart` — píldora, aplastar con resorte, `Vibracion.exito()` al confirmar.
- `tarjeta_monto.dart`, `monto.dart` — radios, `MontoAnimado`.
- `avisos.dart` — píldora, rebote, vibración por tipo.
- `hoja_inferior.dart`, `dialogo_cantidad.dart`, `selector_segmentado.dart`,
  `teclado_monto.dart`, `mosaico.dart`, `estado_vacio.dart`, `avatar_inicial.dart`,
  `etiqueta_qr.dart`, `marca_app.dart`, `tipografia.dart` — colores del tema, formas,
  vibración de toque donde haya teclas o selección.
- Nuevos: `movimiento.dart`, `monto_animado.dart`, `entrada_escalonada.dart`, `vibracion.dart`.

`lib/widgets/` (5): `teclado_numerico.dart`, `monto_rapido_grid.dart`, `selector_cliente.dart`,
`selector_fecha.dart`, `nombre_tienda.dart` — colores del tema y vibración de toque.

`lib/screens/`: solo migración de colores, entrada "Apariencia" en el menú de la cuenta y
entrada escalonada en el Inicio. `main.dart`: `theme`, `darkTheme`, `themeMode`.

## Fuera de alcance (R2–R4)

Cambios de distribución o contenido de pantallas, mini gráficas, "% vs. ayer", bienvenida
guiada, ilustraciones de estados vacíos, rediseño de Reportes, y adopción de la entrada
escalonada fuera del Inicio.

## Pruebas

- Las 530 pruebas existentes siguen en verde (las que comprueban colores se actualizan a los
  tokens del tema).
- **Contraste:** prueba que recorre la lista de pares texto/fondo usados y verifica ≥ 4,5:1
  (o ≥ 3:1 en texto grande) en `ColoresApp.claro` y `ColoresApp.oscuro`.
- **Sin colores sueltos:** prueba que lee `lib/**/*.dart` y falla si encuentra `Color(0x`,
  `Colors.white` o `Colors.black` fuera de `colores_app.dart` y del arte de marca permitido
  explícitamente.
- **Apariencia:** elegir Oscuro guarda `oscuro` y la app usa `temaOscuro`; al reiniciar se
  conserva; valor ilegible → Automático.
- **`MontoAnimado`:** tras el conteo muestra el valor nuevo; con `disableAnimations` muestra el
  valor nuevo en el primer cuadro.
- **Entrada escalonada:** con `disableAnimations` no hay animación; no se repite al reconstruir.
- **Vibración:** `BotonPrincipal`, teclado del PIN y avisos emiten la llamada esperada
  (interceptando el canal `SystemChannels.platform`).
- **Modo oscuro:** Inicio, Nueva venta, Fiado, Inventario, Historial, Ajustes y PIN se
  construyen en `temaOscuro` sin excepciones ni desbordes (vista de 800 dp, fuente Ahem).

## Entrega

- Rama `renovacion-r1`; commits por tarea; plan en `docs/superpowers/plans/`.
- APK de prueba al final para revisar en el celular en claro y oscuro.
- Al terminar, actualizar `docs/hoja-de-ruta.md` (R1 hecho; R2–R4 siguiente).
