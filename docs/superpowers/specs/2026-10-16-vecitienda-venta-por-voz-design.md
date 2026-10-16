# VeciTienda — Vender y reconocer productos por voz

Fecha: 2026-10-16. Mejora 4 de las cuatro pedidas el 2026-10-16 (ver `docs/hoja-de-ruta.md`).
Rama: `feature/venta-por-voz`. Aplica los lineamientos UNIMINUTO v1.2. Reemplaza el ítem "Búsqueda por
voz en Nueva venta" de la hoja de ruta (diseño del 2026-10-13), que queda dentro de este.

## Intención

El tendero quiere dictar la venta: "VeciTienda, registra venta… dos coca colas y un pan". Lo hace
**tocando un botón de micrófono** (no una app que escucha siempre). La voz **solo llena el ticket**;
cobrar sigue igual. La venta puede ser **mixta**: tocar, escanear y dictar en la misma venta.

## Decisiones del usuario

- Botón de micrófono, no escucha permanente.
- La voz solo llena el ticket; "¿Cómo paga?" sigue como hoy.
- Venta mixta: lo dictado se suma a lo que ya tiene el ticket.
- **Reconocimiento solo en el celular** (2026-10-16): el audio nunca sale del teléfono; no se usa el
  servicio en línea de Google. Si el celular no tiene el paquete de español sin conexión, el dictado
  dice que no está disponible y cómo descargarlo.

## Metas

- Dictar uno o varios productos con cantidad y verlos en una hoja de confirmación antes de que entren
  al ticket.
- Reconocer cantidades en número o palabra y productos por nombre, marca o tamaño, tolerando el
  español hablado.
- Volver a lo manual sin fricción cuando la voz no entiende.

## No metas

- Escucha permanente o palabra de activación.
- Cobrar, elegir medio de pago o fiado por voz.
- Crear productos nuevos por voz (los no encontrados se buscan a mano o se quitan).
- Guardar audio o texto dictado.

## Anti-metas

- Que algo entre al ticket sin confirmarlo.
- Que una palabra mal oída agregue un producto equivocado en silencio.

## Cómo funciona

### Dónde está el micrófono

- **Nueva venta:** botón de micrófono junto al buscador fijo (`tooltip` "Dictar venta").
- **Inicio:** botón "Vender por voz" junto a "Nueva venta"; abre Nueva venta y empieza a escuchar de
  inmediato.
- Mientras escucha: una franja con el texto en vivo y un botón "Listo" para terminar antes. Escucha
  hasta 8 s o 3 s de silencio. Idioma `es-CO` (si no existe, el español que tenga el celular).

### Cómo se entiende la frase

1. Se quita el prefijo si está: "vecitienda", "registra/registrar venta", "vender", "venta".
2. Se separa en partes por "y", "," y "más", y también donde empieza una cantidad en palabra ("dos
   coca colas un pan" → "dos coca colas" | "un pan"), porque el reconocedor casi nunca escribe comas.
   Las cifras ("400", "2") no parten, para no romper tamaños y nombres con números. Una parte sin
   cantidad que no encuentre producto se vuelve a unir a la anterior y se reintenta ("litro y medio")
   (*decisión mía*).
3. En cada parte, la cantidad al inicio: número ("2", "12") o palabra ("un/una/uno" 1, "dos"…"doce",
   "quince", "veinte", "media docena" 6, "una docena" 12, "medio/media" no cuenta como cantidad si no va
   con "docena"). Sin cantidad = 1.
4. El resto es el producto: se normaliza (minúsculas, sin tildes, sin guiones) y se quitan palabras
   vacías ("de", "del", "la", "el", "los", "las", "con", "por favor"). Cada palabra dicha debe
   coincidir con el **inicio de una palabra** de nombre, marca o tamaño de un producto activo,
   tolerando el plural simple ("panes" ↔ "pan", "colas" ↔ "cola"). No se compara por subcadena
   ("pan" no halla "Empanada"). Los tamaños se comparan tal cual (sin traducir "litro" a "L")
   (*decisiones mías*).
5. Resultado por parte:
   - **Reconocido**: exactamente un producto coincide, o varios coinciden pero solo uno tiene el
     nombre completo igual a lo dicho ("pan" con "Pan" y "Pan tajado" → "Pan").
   - **Dudoso**: varios coinciden sin ese desempate → opciones (hasta 5) para elegir uno.
   - **No encontrado**: ninguno.
   La hoja de confirmación es la red de seguridad: nada entra sin que el tendero lo vea.

### Hoja de confirmación

- Título "¿Agrego esto?" y el texto oído en gris.
- Una fila por parte: cantidad (− / +), producto (o chips para elegir si es dudoso, o "No lo encontré:
  <texto>" con "Buscar" que pone ese texto en el buscador), precio y "Quitar".
- Botón "Agregar al ticket (N)" con el total de lo que se agregará; deshabilitado si queda algo dudoso
  sin elegir o no hay nada reconocido.
- Al confirmar, cada producto se suma al ticket con su cantidad (si ya estaba, se suma la cantidad).
- "Dictar otra vez" vuelve a escuchar y reemplaza la hoja.
- Si **nada** se reconoció ni hay dudosos, no se abre la hoja: el texto oído (sin prefijo ni
  cantidad) queda en el buscador para terminar a mano (lo que era la búsqueda por voz).

### Avisos

- Sin permiso de micrófono: "Para dictar, permite el micrófono en Ajustes del celular → Apps →
  VeciTienda → Permisos". Sin botón a los ajustes, para no sumar otro paquete (*decisión mía*).
- Reconocimiento no disponible (sin servicio de voz o sin el paquete de español sin conexión): "El
  dictado no está disponible. Descarga el español sin conexión en los ajustes de voz de Google del
  celular".
- No oyó nada: "No te escuché, intenta de nuevo".

### Accesibilidad

- `tooltip`/`Semantics` en los botones de micrófono, la franja de escucha anunciada como región en
  vivo, la hoja usable con letra 2,0× y en modo oscuro, contraste ≥ 4,5:1.

## Técnica

- Paquete verificado en pub.dev el 2026-10-16: `speech_to_text: 7.5.0` (csdcorp.com verificado,
  publicado hace 31 días, Dart ≥ 3.12). Versión fija.
- Android: permiso `android.permission.RECORD_AUDIO` y la consulta
  `android.speech.RecognitionService` en `<queries>` del manifiesto.
- Escucha con `onDevice: true` (solo en el celular, decisión del usuario).
- El reconocedor va detrás de una interfaz propia en `lib/servicios/` con provider (doble en
  pruebas), como `AutenticacionHuella`.
- La interpretación de frases es una función pura en `lib/util/` (texto + productos → partes), con
  pruebas unitarias amplias.
- El ticket gana "agregar producto con cantidad" (suma si ya existe).

## Pruebas

- Interpretación: prefijos, separadores, cantidades (número, palabra, media docena, docena), plurales,
  tildes, marca y tamaño, dudosos, no encontrados, frase vacía.
- Servicio: disponibilidad, permiso negado, texto final.
- Pantalla: botón con tooltip; dictado que abre la hoja con reconocido/dudoso/no encontrado; elegir
  dudoso; − / + y quitar; confirmar suma al ticket existente (venta mixta); nada reconocido → texto en
  el buscador; avisos; "Vender por voz" desde Inicio abre y escucha.
- Modo oscuro y letra 2,0× en la hoja y la franja.

## Queda al criterio de quien lo construya

- Diseño visual fino de la franja de escucha y la hoja (estilo R4).
- Lista exacta de números en palabra más allá de los citados, si se agregan.
