# VeciTienda — aplicar la marca

**Fecha:** 2026-10-05
**Estado:** Borrador para revisión
**Fuentes:** `docs/marca/vecitienda-marca.md` (brief del usuario) y `docs/marca/logo-vecitienda.jpeg`
**Base:** sistema visual de la Fase 2E (`lib/ui/`), respaldo 2B+2C ya integrado.

## Objetivo

La app pasa a llamarse **VeciTienda** y a usar la identidad del brief: logo (toldo + casita +
flecha/check), paleta azul cobalto + verde esmeralda, títulos en una sans-serif redondeada y
header principal azul. Todo respetando la regla de contraste de la 2E (texto ≥ 4.5:1).

## Decisiones tomadas con el usuario

- **Contraste:** "soluciona con el contraste requerido". El verde de marca `#16A34A` se usa solo
  en gráficos y acentos (logo, íconos, bordes; requieren ≥ 3:1 y cumple); el texto verde y el
  botón verde con texto blanco usan `#15803D` (5.0:1).
- **Tipografía de títulos:** Nunito ExtraBold. Inter se mantiene para cuerpo y números.
- **Header azul:** solo en Inicio. Las demás pantallas conservan la barra blanca.

## Identidad

- Nombre visible: **VeciTienda** en `MaterialApp.title`, `android:label` y `MarcaApp`.
- Slogan: *"La tranquilidad de tu tienda, en tu bolsillo."* en la Bienvenida (bajo la marca).
- **Sin cambios:** `applicationId`/paquete Android `com.appventas.app_ventas` y el paquete Dart
  `app_ventas` (cambiarlos haría que Android trate la app como otra y se perderían los datos
  instalados).

## Logo e íconos

- Script reproducible `tool/generar_iconos.py` (Python + Pillow, no es dependencia de la app):
  1. Recorta el isotipo de `docs/marca/logo-vecitienda.jpeg` (región superior, sin el nombre ni
     el slogan) y vuelve transparente el fondo blanco.
  2. Genera `assets/marca/isotipo.png` (cuadrado, 512 px, transparente) para usar en la app.
  3. Genera los íconos del lanzador Android:
     - clásicos `android/app/src/main/res/mipmap-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/ic_launcher.png`
       (48/72/96/144/192 px) con el isotipo sobre fondo blanco redondeado;
     - adaptativo (API 26+): `mipmap-anydpi-v26/ic_launcher.xml` con fondo blanco
       (`@color/ic_launcher_background`) y primer plano
       `mipmap-{densidad}/ic_launcher_foreground.png` (108 dp, isotipo dentro de la zona segura
       de 66 dp).
- El JPEG original queda como fuente; si llega un SVG/PNG mejor, se reemplaza la fuente y se
  vuelve a correr el script.

## Colores (`ColoresApp`)

| Token | Antes | Ahora | Uso |
|---|---|---|---|
| `primario` | `#1E3A8A` | **`#1A539B`** | Barra de Inicio, tarjeta principal, títulos, navegación, enlaces |
| `marcaVerde` | — | **`#16A34A`** | Logo, íconos, bordes y acentos. **Nunca texto** |
| `entra` | `#15803D` | `#15803D` | Cifras verdes, botón "+ Venta" con texto blanco |
| `fondo` | `#F7F9FC` | **`#F8FAFC`** | Fondo general |
| `texto` | `#0F172A` | **`#1E293B`** | Texto principal, precios y cifras |
| `sale` | `#DC2626` | `#DC2626` | Gastos y alertas |
| `entraSuave` | — | **`#BBF7D0`** | Borde claro de la tarjeta de ingresos/ganancia |
| `saleSuave` | — | **`#FECACA`** | Borde claro de la tarjeta de gastos |

Los demás tokens (`superficie`, `borde`, `textoSecundario`, `fiado`, `fiadoSuave`) no cambian.
Prueba de contraste: todos los pares de texto ≥ 4.5:1 (incluidos blanco/`primario` nuevo y
`texto` nuevo sobre `fondo`); `marcaVerde` sobre blanco ≥ 3:1 (uso gráfico).

## Tipografía

- **Nunito** peso 800 empaquetada en `assets/fonts/` (licencia OFL), familia `Nunito`.
- Se usa en: títulos de `AppBar` (tema), `MarcaApp`, títulos de pantallas de entrada
  ("Bienvenido", "¿Quién eres?", "Configura tu tienda") y la etiqueta de la tarjeta principal.
- Inter sigue para todo lo demás (cuerpo, montos con dígitos tabulares).

## Formas

- Botones (`FilledButton`, `OutlinedButton`, `BotonPrincipal`): radio **16**.
- Tarjetas, campos, mosaicos: radio 12 (sin cambio).

## Pantallas

- **`MarcaApp`:** isotipo (`assets/marca/isotipo.png`, 48 px) + "VeciTienda" en Nunito 800,
  color `primario`. Variante con slogan (`MarcaApp(conSlogan: true)`) para la Bienvenida.
- **Inicio:** `AppBar` de la estructura principal en `primario` con texto blanco cuando la
  pestaña es Inicio: insignia blanca redondeada con el isotipo + "Hola, <nombre>". Las otras
  pestañas mantienen la barra blanca.
- **Tarjetas del Inicio:** "Gastos" fondo blanco, borde `saleSuave`, cifra `sale`; "Ganancia"
  fondo blanco, borde `entraSuave`, cifra `entra` (o `sale` si es negativa). "Ventas del día"
  sigue en `primario`. "+ Venta": verde `entra` con ícono "+".
- **Bienvenida / ¿Quién eres? / Crear tienda:** usan `MarcaApp` (la Bienvenida con slogan).

## Pruebas

- `tema_app_test`: pares de contraste con los colores nuevos; `marcaVerde`/blanco ≥ 3:1;
  `primario` del tema = `#1A539B`; título de AppBar en Nunito; Nunito declarada y empaquetada.
- Recursos: existen `assets/marca/isotipo.png` (cuadrado, con transparencia), los cinco
  `ic_launcher.png` con sus tamaños, los `ic_launcher_foreground.png` y el XML adaptativo.
- `AndroidManifest.xml` con `android:label="VeciTienda"`; `MaterialApp.title == 'VeciTienda'`.
- Widget: la Bienvenida muestra "VeciTienda" y el slogan; el Inicio tiene barra `primario` y la
  insignia del isotipo; las demás pestañas mantienen barra blanca; tarjetas de Gastos/Ganancia
  con sus bordes.
- Manual: capturas en el emulador (Bienvenida, ¿Quién eres?, Inicio, Nueva venta) y del ícono en
  el lanzador.

## Fuera de alcance

- Cambiar `applicationId`, nombre del paquete Dart o del repositorio.
- Publicación en Play Store, ícono para iOS (la app es Android), modo oscuro.
- Rediseño de pantallas más allá de colores, tipografía, header de Inicio y tarjetas.
