# Ingreso rápido con huella — Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Botón "Entrar con huella" en la pantalla del PIN para quien lo activa en Ajustes, con el PIN
siempre disponible.

**Architecture:** `local_auth` queda detrás de la interfaz `AutenticacionHuella` (con provider para
dobles de prueba). Los usuarios con huella activada viven en `SharedPreferences`
(`usuarios_con_huella`) mediante un Notifier. `SesionNotifier` gana un ingreso sin PIN que solo usa la
pantalla del PIN tras una huella aprobada.

**Tech Stack:** Flutter, Riverpod 2.6, SharedPreferences, `local_auth` 3.0.2, Android.

**Spec:** `docs/superpowers/specs/2026-10-16-vecitienda-ingreso-con-huella-design.md`

## Global Constraints

- Rama `feature/ingreso-con-huella` desde `master`; Conventional Commits con
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`; sin push ni merge sin autorización.
- Dependencias exactas (verificadas en pub.dev el 2026-10-16): `local_auth: 3.0.2`,
  `local_auth_android: 2.2.0`. Si hace falta `androidx.appcompat`, versión fija.
- Textos: "Entrar con huella"; motivo "Confirma que eres <nombre>"; aviso "Cualquier huella
  registrada en este celular podrá abrir tu usuario. Actívalo solo si el celular es tuyo."; bloqueo
  "Demasiados intentos con la huella: usa tu PIN"; sin huellas "Este celular ya no tiene huellas
  registradas: usa tu PIN".
- `biometricOnly: true`. Nada biométrico se guarda.
- `dart format` solo en archivos nuevos; `flutter analyze` limpio; suite completa en verde por tarea.

## Review Focus

1. Huella aprobada para un usuario cuyo id ya no existe (lista vieja) → no abre sesión y se limpia
   (Tarea 1 y 3).
2. Dos toques al botón de huella → un solo diálogo y una sola sesión (Tarea 3).
3. Activar la huella y cancelar el diálogo del sistema → queda desactivada (Tarea 3).
4. Restaurar un respaldo → la lista queda vacía aunque la restauración cierre la sesión (Tarea 3).
5. `local_auth` lanza un error no previsto → la pantalla no se cae, sigue el PIN (Tarea 1).

---

### Task 1: Servicio de huella y lista de usuarios con huella

**Files:**
- Modify: `pubspec.yaml` (dependencias exactas)
- Create: `lib/servicios/autenticacion_huella.dart`, `lib/providers/huella_provider.dart`
- Test: `test/servicios/autenticacion_huella_test.dart`, `test/providers/huella_provider_test.dart`

**Interfaces:**
- Produces:
  - `enum ResultadoHuella { aprobada, cancelada, bloqueada, sinHuellas }`
  - `abstract class AutenticacionHuella { Future<bool> disponible(); Future<ResultadoHuella> confirmar(String motivo); }`
  - `class AutenticacionHuellaLocal implements AutenticacionHuella` con constructor
    `AutenticacionHuellaLocal([LocalAuthentication? auth])`.
  - `final autenticacionHuellaProvider = Provider<AutenticacionHuella>((ref) => AutenticacionHuellaLocal());`
  - `const claveUsuariosConHuella = 'usuarios_con_huella';`
  - `final usuariosConHuellaProvider = NotifierProvider<UsuariosConHuella, Set<int>>(...)` con
    `Future<void> activar(int usuarioId)`, `Future<void> desactivar(int usuarioId)`,
    `Future<void> borrarTodas()`, `Future<void> conservarSolo(Iterable<int> existentes)`.

- [ ] **Step 1:** Pruebas del servicio con un `LocalAuthentication` falso (subclase que sobreescribe
  `isDeviceSupported`, `getAvailableBiometrics`, `authenticate`): `disponible` es false sin soporte,
  false con lista vacía, true con una biometría; `confirmar` pasa `biometricOnly: true` y el motivo;
  true → `aprobada`, false → `cancelada`; `LocalAuthException` de bloqueo temporal o permanente →
  `bloqueada`; sin hardware o sin huellas registradas → `sinHuellas`; cualquier otra excepción →
  `cancelada` (Review Focus 5). Pruebas del Notifier: arranca con lo guardado; activar/desactivar
  persisten como lista de textos; `borrarTodas` deja vacío; `conservarSolo([1])` quita el 2.
- [ ] **Step 2:** `flutter pub get`; correr las pruebas → FALLAN.
- [ ] **Step 3:** Implementar (los códigos exactos de `LocalAuthExceptionCode` se toman de la API de
  3.0.2).
- [ ] **Step 4:** → PASAN; `flutter analyze` limpio.
- [ ] **Step 5:** Commit `feat: add the fingerprint service and the per-device list of users with it`.

### Task 2: Android listo para la huella

**Files:**
- Modify: `android/app/src/main/kotlin/com/appventas/app_ventas/MainActivity.kt`,
  `android/app/src/main/AndroidManifest.xml`, los cuatro `styles.xml` (`values`, `values-night`,
  `values-v31`, `values-night-v31`), `android/app/build.gradle(.kts)` si hace falta appcompat
- Test: `test/marca/recursos_marca_test.dart`

- [ ] **Step 1:** Pruebas de recursos: `MainActivity` extiende `FlutterFragmentActivity`; el manifiesto
  tiene `android.permission.USE_BIOMETRIC`; los cuatro `LaunchTheme` heredan de `Theme.AppCompat…`
  (claro `Theme.AppCompat.Light.NoActionBar`, noche `Theme.AppCompat.NoActionBar`) y siguen teniendo
  `@drawable/launch_background` (y en v31 los atributos de la mejora 2).
- [ ] **Step 2:** → FALLAN.
- [ ] **Step 3:** Hacer los cambios.
- [ ] **Step 4:** Pruebas → PASAN; `flutter build apk --release` compila (prueba real de que los temas
  AppCompat resuelven).
- [ ] **Step 5:** Commit `feat: prepare Android for fingerprint login`.

### Task 3: Activar en Ajustes, entrar con huella y limpiar al restaurar

**Files:**
- Modify: `lib/providers/sesion_provider.dart`, `lib/screens/login/ingresar_pin_screen.dart`,
  `lib/screens/configuracion/ajustes_screen.dart`, `lib/respaldo/respaldo_provider.dart`
- Test: `test/screens/login/ingresar_pin_screen_test.dart`, `test/screens/configuracion/ajustes_screen_test.dart`,
  `test/respaldo/` (el archivo de pruebas de `restaurar`), `test/screens/administracion_oscuro_test.dart`
  o `modo_oscuro_test.dart`

**Interfaces:**
- Consumes: Tarea 1.
- Produces: `SesionNotifier.iniciarSesionConHuella(int usuarioId) → Future<bool>` (false si el usuario
  no existe o no tiene la huella activada; en ese caso lo quita de la lista).

- [ ] **Step 1:** Pruebas con un `AutenticacionHuella` falso:
  - PIN: sin activar o sin biometría no hay `boton_huella`; con ambos aparece "Entrar con huella" con
    `tooltip`; `aprobada` abre sesión y cierra la pantalla; `cancelada` no cambia nada;
    `bloqueada` y `sinHuellas` muestran sus textos; dos toques seguidos → `confirmar` se llama una vez;
    el PIN correcto sigue abriendo sesión con el botón visible.
  - Sesión: `iniciarSesionConHuella` con id inexistente → false y lo quita de la lista.
  - Ajustes: sin biometría no hay `interruptor_huella`; con biometría aparece en el grupo CUENTA;
    encenderlo muestra el aviso; "Cancelar" no activa; "Activar" + `aprobada` activa; "Activar" +
    `cancelada` no activa; apagarlo desactiva sin pedir nada.
  - Restaurar: tras `ResultadoRestauracion.restaurado` la lista queda vacía.
  - Modo oscuro con letra 2,0×: PIN con botón y Ajustes con la fila, sin desbordes.
- [ ] **Step 2:** → FALLAN.
- [ ] **Step 3:** Implementar. En la pantalla del PIN, `disponible()` se consulta una vez al abrir; el
  botón va bajo el teclado. En Ajustes la fila es un `SwitchListTile` en CUENTA, antes de "Cerrar
  sesión". `restaurar()` llama `borrarTodas()` en el caso `restaurado`.
- [ ] **Step 4:** `flutter test` completo y `flutter analyze` → limpios.
- [ ] **Step 5:** Hoja de ruta: mejora 3 a "Hecho" y al recorrido en celular; `flutter build apk --release`.
- [ ] **Step 6:** Commit `feat: let users turn on fingerprint login and use it on the PIN screen`.
