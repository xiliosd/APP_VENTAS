# Inicio de marca ("el toldo se abre") — Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Pantalla de entrada con el toldo de la marca: completa la primera vez, breve en cada arranque,
y pantalla de carga de Android del mismo color.

**Architecture:** `InicioMarcaScreen` es un widget con un solo `AnimationController` cuya duración es la
del inicio entero (así `pumpAndSettle` lo recorre en las pruebas); al completar llama `onTerminar`.
`RaizApp` lo muestra una vez por proceso (StateProvider) y decide completa/breve con una preferencia.

**Tech Stack:** Flutter, Riverpod 2.6, SharedPreferences, recursos XML de Android.

**Spec:** `docs/superpowers/specs/2026-10-16-vecitienda-inicio-de-marca-design.md`

## Global Constraints

- Rama `feature/inicio-de-marca` desde `master`; Conventional Commits con
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`; sin push ni merge sin autorización.
- Sin dependencias nuevas. `dart format` solo en archivos nuevos.
- Duraciones: completa 1500 ms, breve 500 ms, reducir movimiento 300 ms (sin animar).
- Colores del toldo fijos: `ColoresApp.verdeMarca = Color(0xFF16A34A)` y `ColoresApp.blancoMarca`.
- Fondo nativo: claro `#F8FAFC`, oscuro `#0B1220`.
- Preferencia `inicio_completo_visto` (bool), marcada al empezar la versión completa.
- Semantics: "VeciTienda, la tranquilidad de tu tienda, en tu bolsillo".

## Review Focus

1. Cierre de la app a mitad de la versión completa → al volver sale la breve (Tarea 2: la marca se
   guarda al empezar).
2. La consulta de usuarios tarda más que el inicio → el inicio queda quieto en su estado final, sin
   pantalla en blanco ni indicador doble (Tarea 2).
3. Tocar dos veces muy rápido → `onTerminar` se llama una sola vez (Tarea 1).
4. Letra 2,0× en un celular pequeño (360×640) → sin desbordes (Tarea 1).
5. Restaurar un respaldo o cerrar sesión → no vuelve a salir el inicio (Tarea 2).

---

### Task 1: `InicioMarcaScreen`

**Files:**
- Create: `lib/screens/inicio/inicio_marca_screen.dart`
- Modify: `lib/ui/colores_app.dart` (constante `verdeMarca`)
- Test: `test/screens/inicio/inicio_marca_screen_test.dart`

**Interfaces:**
- Produces: `InicioMarcaScreen({Key? key, required bool completa, required VoidCallback onTerminar})`;
  claves `toldo_marca`, `insignia_marca`; texto "VeciTienda" y `MarcaApp.slogan`.

- [ ] **Step 1:** Pruebas: con `completa: true` muestra toldo, insignia (isotipo con
  `semanticLabel`), "VeciTienda" y el eslogan, y llama `onTerminar` a los 1500 ms (no antes de 1400);
  con `completa: false` a los 500 ms; tocar llama `onTerminar` enseguida y un segundo toque no lo
  vuelve a llamar (contador = 1); con `MediaQuery(disableAnimations: true)` el toldo está a escala 1
  desde el primer cuadro y termina a los 300 ms; existe un `Semantics` con la etiqueta del spec;
  en oscuro con letra 2,0× en 360×640 no hay excepción.
- [ ] **Step 2:** `flutter test test/screens/inicio/inicio_marca_screen_test.dart` → FALLA.
- [ ] **Step 3:** Implementar. Toldo: 6 gajos (`Row` de `Expanded`, radio inferior grande, impares
  `verdeMarca`, pares `blancoMarca` con borde `verdeMarca`), alto 28 % de la pantalla, escala vertical
  desde arriba con `Movimiento.resorte` en el tramo 0–0,3 del controlador (en la breve, ya en 1).
  Insignia 96 dp radio 26 con sombra; insignia, nombre y eslogan entran escalonados en 0,23–0,57
  (completa) o la insignia salta en 0–0,6 (breve). Nombre: `estiloTitulo(tamano: 34)` con peso 900,
  color `primario`. Fondo `fondo` del tema. `GestureDetector` en toda la pantalla.
- [ ] **Step 4:** → PASA; `flutter analyze` limpio.
- [ ] **Step 5:** Commit `feat: add the brand opening screen with the shop awning`.

### Task 2: Mostrarlo al abrir la app

**Files:**
- Modify: `lib/screens/raiz_app.dart`
- Create: `lib/providers/inicio_marca_provider.dart`
- Test: `test/screens/raiz_app_test.dart` (nuevo), `test/widget_test.dart` (debe seguir pasando)

**Interfaces:**
- Consumes: `InicioMarcaScreen` (Tarea 1), `preferenciasProvider`.
- Produces: `final inicioMarcaPendienteProvider = StateProvider<bool>((ref) => true);` (true hasta
  que el inicio termina en este proceso); `const claveInicioCompletoVisto = 'inicio_completo_visto';`.

- [ ] **Step 1:** Pruebas (montando `AppVentas` como `test/widget_test.dart`): primer arranque muestra
  `toldo_marca`, marca la preferencia en true y tras `pumpAndSettle` muestra "Crear tienda nueva";
  con la preferencia ya en true y un usuario creado, la versión es breve (sale "¿Quién eres?" a los
  500 ms; a los 450 ms aún se ve `insignia_marca`); al poner `inicioMarcaPendienteProvider` en false
  e invalidar la sesión no aparece `toldo_marca`; si `haySesionUsuariosProvider` no ha respondido
  cuando termina el inicio, el inicio sigue visible (sin `CircularProgressIndicator`) y al responder
  pasa a la pantalla que toca.
- [ ] **Step 2:** → FALLA.
- [ ] **Step 3:** Implementar: mientras `inicioMarcaPendienteProvider` sea true o la consulta de usuarios
  esté cargando, `RaizApp` muestra `InicioMarcaScreen(completa: !visto, onTerminar: …)`; `visto` se
  lee una vez al construir y la preferencia se escribe en `initState` si era la primera vez (convertir
  `RaizApp` en `ConsumerStatefulWidget`). Cambio a la pantalla siguiente con `AnimatedSwitcher`
  (desvanecido, `Movimiento.media`).
- [ ] **Step 4:** `flutter test` completo → PASA (incluye `widget_test.dart` y
  `recursos_marca_test.dart`).
- [ ] **Step 5:** Commit `feat: show the brand opening once per app launch`.

### Task 3: Pantalla de carga de Android, accesibilidad y documentos

**Files:**
- Create: `android/app/src/main/res/values/colors.xml` (`fondo_inicio` `#F8FAFC`),
  `android/app/src/main/res/values-night/colors.xml` (`fondo_inicio` `#0B1220`),
  `android/app/src/main/res/drawable/icono_transparente.xml`,
  `android/app/src/main/res/values-v31/styles.xml`, `android/app/src/main/res/values-night-v31/styles.xml`
- Modify: `android/app/src/main/res/drawable/launch_background.xml` (y `drawable-v21` si existe el
  mismo archivo), `test/marca/recursos_marca_test.dart`, `test/screens/administracion_oscuro_test.dart`
  o `modo_oscuro_test.dart`, `docs/hoja-de-ruta.md`

- [ ] **Step 1:** Pruebas de recursos: `launch_background.xml` usa `@color/fondo_inicio` y no
  `@android:color/white`; los dos `colors.xml` tienen los valores del spec; los dos `styles.xml` v31
  tienen `windowSplashScreenBackground` = `@color/fondo_inicio` y
  `windowSplashScreenAnimatedIcon` = `@drawable/icono_transparente`. Prueba de oscuro: el inicio
  completo en oscuro con letra 2,0× no desborda.
- [ ] **Step 2:** → FALLAN.
- [ ] **Step 3:** Crear y editar los recursos (`LaunchTheme` de v31 hereda de
  `@android:style/Theme.Light.NoTitleBar` / `Theme.Black.NoTitleBar` como los actuales).
- [ ] **Step 4:** `flutter test` y `flutter analyze` limpios; `flutter build apk --release`.
- [ ] **Step 5:** Hoja de ruta: mejora 2 a "Hecho" y al recorrido manual en celular.
- [ ] **Step 6:** Commit `feat: match the Android launch screen to the brand opening`.
