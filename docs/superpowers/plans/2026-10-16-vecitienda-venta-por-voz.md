# Vender y reconocer productos por voz — Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Botón de micrófono que dicta la venta, muestra una hoja de confirmación y suma lo confirmado al
ticket de Nueva venta (venta mixta), con reconocimiento solo en el celular.

**Architecture:** Una función pura interpreta el texto dictado contra los productos activos. El
reconocedor (`speech_to_text`, `onDevice: true`) va detrás de la interfaz `Dictado` con provider. Nueva
venta orquesta: escuchar → interpretar → hoja de confirmación → `TicketNotifier.agregarProducto(p, cantidad:)`.

**Tech Stack:** Flutter, Riverpod 2.6, `speech_to_text` 7.5.0, Android.

**Spec:** `docs/superpowers/specs/2026-10-16-vecitienda-venta-por-voz-design.md`

## Global Constraints

- Rama `feature/venta-por-voz` desde `master`; Conventional Commits con
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`; sin push ni merge sin autorización.
- Dependencia exacta: `speech_to_text: 7.5.0` (verificada en pub.dev el 2026-10-16). Ninguna otra.
- Escucha con `onDevice: true`, hasta 8 s o 3 s de silencio, idioma `es-CO` o el español disponible.
- Textos: tooltip "Dictar venta"; botón Inicio "Vender por voz"; hoja "¿Agrego esto?"; botón
  "Agregar al ticket (N)"; "Dictar otra vez"; "No lo encontré: <texto>"; avisos "Para dictar, permite
  el micrófono en Ajustes del celular → Apps → VeciTienda → Permisos", "El dictado no está disponible.
  Descarga el español sin conexión en los ajustes de voz de Google del celular", "No te escuché,
  intenta de nuevo".
- No se guarda audio ni texto dictado. `dart format` solo en archivos nuevos; `flutter analyze` limpio.

## Review Focus

1. El usuario cierra Nueva venta mientras escucha → se detiene el reconocedor y no hay setState tras
   dispose (Tarea 3).
2. Dictar dos veces el mismo producto en una frase ("una coca y otra coca") → una sola línea con
   cantidad 2 en la hoja (Tarea 1).
3. Cantidad enorme mal oída ("doscientos panes") → la hoja la muestra editable; nada entra sin
   confirmar; cantidad máxima 99 (Tarea 1).
4. Producto desactivado → no se ofrece (solo activos) (Tarea 1).
5. Venta de práctica del recorrido → sin micrófono (Tarea 3).

---

### Task 1: Interpretar lo dictado

**Files:**
- Create: `lib/util/interpretar_dictado.dart`
- Test: `test/util/interpretar_dictado_test.dart`

**Interfaces:**
- Produces:
  - `enum TipoParteDictada { reconocida, dudosa, noEncontrada }`
  - `class ParteDictada { final String texto; final int cantidad; final TipoParteDictada tipo; final List<Producto> opciones; }`
    (`opciones`: 1 si reconocida, 2–5 si dudosa, vacía si no encontrada)
  - `List<ParteDictada> interpretarDictado(String dicho, List<Producto> activos)`

- [ ] **Step 1:** Pruebas (productos: Coca-Cola 400 ml, Coca-Cola 1,5 L, Pan, Pan tajado, Empanada,
  Leche Alpina, Huevos):
  - "vecitienda registra venta dos coca colas y un pan" → [2 dudosa (las dos Coca-Cola), 1 Pan
    reconocida];
  - "dos coca colas un pan" (sin "y") → mismas dos partes;
  - "media docena de huevos" → 6 Huevos; "una docena de huevos" → 12; "3 panes" → 3 Pan;
  - "pan" no ofrece Empanada; "pan" con Pan y Pan tajado → reconocida Pan (nombre igual);
  - "leche alpina por favor" → Leche Alpina; "coca cola de 400" → Coca-Cola 400 ml reconocida;
  - "litro y medio" sin producto no rompe la frase anterior ("coca cola de litro y medio" no queda
    partida en dos partes no encontradas);
  - "una coca cola 400 y otra coca cola 400" → una parte con cantidad 2;
  - "doscientos panes" → cantidad 99; "tornillos" → noEncontrada con texto "tornillos";
  - "" y solo prefijo → lista vacía.
- [ ] **Step 2:** → FALLA.
- [ ] **Step 3:** Implementar con `sinTildes`/`claveNombre` de `texto_util.dart`; números en palabra
  "un/una/uno … veinte", "treinta", "cuarenta", "cincuenta", "cien", "doscientos…"; plural simple al
  comparar (quitar "es"/"s" final).
- [ ] **Step 4:** → PASA. **Step 5:** Commit `feat: understand dictated sale phrases`.

### Task 2: Reconocedor y Android

**Files:**
- Modify: `pubspec.yaml`, `android/app/src/main/AndroidManifest.xml`
- Create: `lib/servicios/dictado.dart`
- Test: `test/servicios/dictado_test.dart`, `test/marca/recursos_marca_test.dart`

**Interfaces:**
- Produces:
  - `enum EstadoDictado { listo, sinPermiso, noDisponible }`
  - `abstract class Dictado { Future<EstadoDictado> preparar(); Future<String?> escuchar({required void Function(String parcial) alOir}); Future<void> detener(); }`
    (`escuchar` devuelve el texto final o null si no oyó nada)
  - `class DictadoDelCelular implements Dictado` sobre `SpeechToText` (inyectable para pruebas).
  - `final dictadoProvider = Provider<Dictado>((ref) => DictadoDelCelular());`

- [ ] **Step 1:** Pruebas con un `SpeechToText` falso: `preparar` → `sinPermiso` si `initialize` falla por
  permiso, `noDisponible` si no hay reconocedor o no hay locale español; `escuchar` usa `onDevice: true`,
  8 s / 3 s, locale `es_CO` si existe; parciales llegan a `alOir`; final vacío → null. Recursos:
  manifiesto con `RECORD_AUDIO` y `<queries>` con `android.speech.RecognitionService`.
- [ ] **Step 2:** → FALLAN. **Step 3:** Implementar (API exacta de 7.5.0 desde el caché de pub).
- [ ] **Step 4:** → PASAN; `flutter analyze` limpio.
- [ ] **Step 5:** Commit `feat: add on-device dictation`.

### Task 3: Dictar en Nueva venta

**Files:**
- Modify: `lib/providers/ticket_provider.dart`, `lib/screens/venta/registrar_venta_screen.dart`
- Create: `lib/screens/venta/hoja_dictado.dart`
- Test: `test/providers/ticket_provider_test.dart` (o el existente), `test/screens/venta/dictado_venta_test.dart`,
  `test/support/dictado_falso.dart`

**Interfaces:**
- Consumes: Tareas 1–2.
- Produces: `TicketNotifier.agregarProducto(Producto p, {int cantidad = 1})` (suma si ya está);
  `RegistrarVentaScreen({…, bool dictarAlAbrir = false})`.

- [ ] **Step 1:** Pruebas:
  - Ticket: `agregarProducto(p, cantidad: 3)` sobre una línea existente con 1 → 4.
  - Pantalla con `DictadoFalso`: botón `boton_dictar` con tooltip "Dictar venta" (no en práctica);
    franja `franja_dictado` con el texto parcial y "Listo"; frase con reconocida + dudosa + no encontrada
    abre la hoja "¿Agrego esto?"; el botón "Agregar al ticket" deshabilitado hasta elegir la dudosa;
    − / + y Quitar; "Buscar" de la no encontrada cierra la hoja y pone el texto en el buscador;
    confirmar suma al ticket que ya tenía un producto tocado (venta mixta); nada reconocido → sin hoja y
    el texto en el buscador; avisos de `sinPermiso`, `noDisponible` y `null`; cerrar la pantalla mientras
    escucha llama `detener()`; con `dictarAlAbrir` empieza a escuchar sola.
  - Modo oscuro y letra 2,0× de la hoja y la franja sin desbordes.
- [ ] **Step 2:** → FALLAN. **Step 3:** Implementar. **Step 4:** → PASAN.
- [ ] **Step 5:** Commit `feat: dictate a sale into the ticket`.

### Task 4: Vender por voz desde el Inicio y documentos

**Files:**
- Modify: `lib/screens/home/resumen_screen.dart`, `docs/hoja-de-ruta.md`
- Test: la prueba del Inicio que monta `ResumenScreen`/`HomeScreen`

- [ ] **Step 1:** Prueba: un botón de micrófono `boton_vender_por_voz` (tooltip "Vender por voz") en la
  barra de Inicio abre Nueva venta escuchando; con letra 2,0× la barra no desborda.
- [ ] **Step 2:** → FALLA. **Step 3:** Implementar como `IconButton.filledTonal` entre "+ Venta" y
  "− Gasto". **Step 4:** Suite completa y `flutter analyze` → limpios.
- [ ] **Step 5:** Hoja de ruta: quitar "Búsqueda por voz" y la mejora 4 de "Después", agregar a
  "Hecho" y al recorrido en celular; `flutter build apk --release` si hay memoria (si no, anotarlo).
- [ ] **Step 6:** Commit `feat: sell by voice from the home screen`.
