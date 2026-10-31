# Arreglos tanda C (huella, clientes, errores y orden interno) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Cerrar los detalles menores vigentes que quedan del triage: ingreso con huella que no se
traba, clientes sin destello y con extracto a un toque, errores entendibles en lugar de
`Error: …` técnico, y orden interno (ciclos de imports, comparador duplicado, nombres con espacios
dobles, fundido de sesión).

**Architecture:** Cambios pequeños en `lib/screens/login/`, `lib/servicios/autenticacion_huella.dart`,
`lib/screens/clientes/`, `lib/screens/fiado/`, un componente nuevo `lib/ui/error_carga.dart`
usado en 11 lugares, y ajustes internos en providers y repositorios. No hay cambios de esquema ni
dependencias nuevas.

**Tech Stack:** Flutter, Riverpod 2, Drift, local_auth 3.0.2 (local_auth_platform_interface 1.1.0);
pruebas con `flutter_test`.

**Spec:** no hay spec aparte. La fuente es el triage del 2026-10-30 (ítems #31, #52, #54, #55, #56, #57,
#58, #67, #68, #70 y #71, más el hallazgo nuevo de errores crudos en pantalla), resumido en
`docs/hoja-de-ruta.md` → paso 2, "Tanda C".

## Global Constraints

- Trabajo directo en `master` (proyecto personal): un commit por tarea, Conventional Commits en
  inglés y trailer `Co-Authored-By: Claude <modelo> <noreply@anthropic.com>` con el modelo real.
- `dart format` solo sobre los archivos tocados; `flutter analyze` limpio; suite completa en verde.
- Textos al usuario en español de Colombia, tuteo, sin tecnicismos. Nunca se muestra al usuario el
  texto de una excepción.
- Colores siempre con `ColoresApp.of(context)` o las constantes de `ColoresApp`.

## Fuera de alcance (decidido)

- #53 `_yaMostrada` se asigna en `build` de `raiz_app.dart`: es estado local sin `setState`, no
  provoca reconstrucciones, y moverlo cambia el momento en que deja de mostrarse el inicio de marca.

## Review Focus

- La huella falla por una excepción de la base al iniciar sesión: el botón vuelve a quedar
  disponible y hay un mensaje (tarea 1).
- El sensor está ocupado o no responde un momento: el mensaje lo dice y sugiere el PIN (tarea 1).
- Abrir "Ver fiado" desde Clientes con la deuda cargando: nunca se lee "Debe desde hoy" de paso
  (tarea 2).
- Una pantalla con error de carga y letra muy grande: el mensaje cabe y se lee (tarea 3).
- Entrar o salir de sesión: el cambio de pantalla es inmediato; solo la salida del inicio de marca
  se funde (tarea 4).

---

### Task 1: Ingreso con huella que no se traba (#55, #56, #58)

**Files:**
- Modify: `lib/servicios/autenticacion_huella.dart` (`enum ResultadoHuella`, `confirmar`),
  `lib/screens/login/ingresar_pin_screen.dart` (`_entrarConHuella`, botón ~150-165)
- Test: las pruebas existentes de la huella (`test/servicios/autenticacion_huella_test.dart` y la de la
  pantalla del PIN que usa `boton_huella`)

**Interfaces:**
- Produces: `enum ResultadoHuella { aprobada, cancelada, bloqueada, sinHuellas, noDisponible }`.

- [ ] **Step 1: Write the failing tests**

```dart
test('sensor ocupado o sin responder da noDisponible', ...);
// LocalAuthException con code biometricHardwareTemporarilyUnavailable → ResultadoHuella.noDisponible.
testWidgets('con el sensor sin responder lo dice y sugiere el PIN', ...);
// Huella falsa que devuelve noDisponible → texto 'El sensor de huella no responde ahora: usa tu PIN'.
testWidgets('si falla iniciar sesión, el botón vuelve a quedar disponible', ...);
// Huella aprobada y sesión cuyo iniciarSesionConHuella lanza → texto
// 'No se pudo entrar con la huella: usa tu PIN' y el TextButton de 'boton_huella' tiene onPressed != null.
testWidgets('el botón de huella no repite su texto como ayuda', ...);
// find.byType(Tooltip) no tiene descendiente con 'boton_huella' (no hay Tooltip con 'Entrar con huella').
```

- [ ] **Step 2: Run tests to verify they fail**

- [ ] **Step 3: Implement**

- `confirmar` mapea `LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable` a `noDisponible`.
- En `_entrarConHuella`, la llamada a `iniciarSesionConHuella` va en `try/catch`. Ante un fallo,
  `ok = false` y se muestra el error de la prueba. `_usandoHuella` siempre vuelve a `false`, en `finally`
  o en el `setState` final, si la pantalla sigue montada.
- Se quita el `Tooltip` que envuelve el botón: su etiqueta ya dice lo mismo.

- [ ] **Step 4: Run tests to verify they pass**

- [ ] **Step 5: Commit** — `fix: recover the fingerprint button on failure and explain a busy sensor`

### Task 2: Clientes sin destello y con extracto a un toque (#68, #71, #67)

**Files:**
- Modify: `lib/screens/fiado/detalle_cliente_screen.dart:~62-100`,
  `lib/screens/clientes/detalle_cliente_general_screen.dart:~43-60`
- Test: `test/screens/clientes/detalle_cliente_general_test.dart`, `test/widgets/formulario_cliente_test.dart`,
  la prueba existente de `DetalleClienteScreen` (buscar `tarjeta_saldo_cliente` en `test/`)

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('sin fecha de deuda conocida no dice "Debe desde hoy" mientras carga', ...);
// DetalleClienteScreen con ClienteConSaldo(saldo: 5000, fechaDeudaMasAntigua: null) y los
// movimientos aún sin cargar (primer pump) → find.textContaining('Debe desde') findsNothing;
// tras pumpAndSettle con una venta fiada de hace 3 días → aparece el texto que da textoDebeDesde.
testWidgets('desde Clientes se abre el extracto con un toque', ...);
// Cliente con fiado → botón Key('boton_ver_extracto_cliente') con texto 'Ver extracto';
// al tocarlo se ve ExtractoFiadoScreen.
testWidgets('detalle de cliente a letra 2,0× no desborda', ...);
testWidgets('formulario de cliente a letra 2,0× no desborda', ...);
// MediaQuery con textScaler: TextScaler.linear(2.0) en 360×690; tester.takeException() == null.
```

- [ ] **Step 2: Run tests to verify they fail**

- [ ] **Step 3: Implement**

- `fechaDeuda` pasa a ser `DateTime?`: las ventas vigentes, si no `clienteConSaldo.fechaDeudaMasAntigua`,
  y si no `null`, sin caer en `DateTime.now()`. Con `null` no se muestra la línea "Debe desde".
- En el detalle general, junto a "Ver fiado" y con la misma condición `tieneFiado`, va un
  `OutlinedButton` 'Ver extracto' con la key de la prueba, que abre `ExtractoFiadoScreen(cliente: cliente)`.
  Con letra grande, los dos botones se apilan en un `Wrap` o en una columna.

- [ ] **Step 4: Run tests to verify they pass**

- [ ] **Step 5: Commit** — `fix: avoid the debt-date flash and open the statement from Clients`

### Task 3: Errores de carga entendibles (hallazgo nuevo: 11 lugares)

**Files:**
- Create: `lib/ui/error_carga.dart`
- Modify: `lib/screens/configuracion/productos_screen.dart:~269`, `proveedores_screen.dart:~151`,
  `usuarios_screen.dart:~96`, `lib/screens/fiado/detalle_cliente_screen.dart:~146`,
  `lista_fiado_screen.dart:~218`, `lib/screens/historial/historial_screen.dart:~224`,
  `lib/screens/home/resumen_screen.dart:~84 y ~128`, `lib/screens/login/seleccionar_usuario_screen.dart:~48`,
  `lib/screens/raiz_app.dart:~74`, `lib/screens/venta/registrar_venta_screen.dart:~684`
- Test: crear `test/ui/error_carga_test.dart`

**Interfaces:**
- Produces: `class ErrorCarga extends StatelessWidget { const ErrorCarga({super.key, this.compacto = false}); }`.
  - Normal: `EstadoVacio(icono: Icons.error_outline_rounded, titulo: 'No se pudo cargar', mensaje: 'Cierra esta pantalla y vuelve a abrirla')`.
  - `compacto: true`: un solo `Text('No se pudo cargar')` con el color `textoSecundario`, para los
    lugares que hoy ponen el error dentro de una fila o tarjeta.

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('muestra el texto amable', ...);        // normal y compacto
testWidgets('a letra 2,0× en 360 dp no desborda', ...);
test('ninguna pantalla muestra el texto de una excepción', ...);
// Recorre los .dart de lib/ y falla si alguno contiene el patrón RegExp(r"Text\(\s*'Error: \$") ;
// mismo estilo que test/ui/colores_sueltos_test.dart.
```

- [ ] **Step 2: Run tests to verify they fail**

- [ ] **Step 3: Implement** — `ErrorCarga()` reemplaza los errores de pantalla completa o de
  `Center`, y `ErrorCarga(compacto: true)` los que van dentro de una fila o tarjeta (`resumen_screen`,
  `detalle_cliente_screen`, `registrar_venta_screen`). En `raiz_app.dart` va dentro del `Scaffold`
  que ya existe. Los parámetros `(e, st)` se vuelven `(_, _)`.

- [ ] **Step 4: Run tests to verify they pass** (y las pruebas de las pantallas tocadas)

- [ ] **Step 5: Commit** — `fix: show a friendly message instead of raw load errors`

### Task 4: Orden interno (#31, #52, #54, #57, #70)

**Files:**
- Create: `lib/providers/preferencias_provider.dart` (mover ahí `preferenciasProvider` tal cual)
- Modify: `lib/respaldo/respaldo_provider.dart` (quitar la definición y reexportar con
  `export '../providers/preferencias_provider.dart';` para no romper importadores),
  `lib/providers/huella_provider.dart` (importar `preferencias_provider.dart` en vez de `respaldo_provider.dart`),
  `lib/util/saldos_fiado.dart`, `lib/util/extracto_fiado.dart`, `lib/repositories/proveedor_repository.dart`
  (`_nombreValido`), `lib/screens/raiz_app.dart` (`initState`, `AnimatedSwitcher`)
- Test: `test/util/saldos_fiado_test.dart` o `extracto_fiado_test.dart` existentes,
  `test/repositories/proveedor_repository_test.dart`, la prueba existente del inicio de marca / raíz
  (buscar `inicio_marca` en `test/`)

**Interfaces:**
- Produces: `int compararMovimientosFiado(MovimientoFiado a, MovimientoFiado b)` en `saldos_fiado.dart`
  (por fecha; con la misma fecha, venta antes que abono). `saldosAcumulados` y `armarExtracto` lo usan.

- [ ] **Step 1: Write the failing tests**

```dart
test('compararMovimientosFiado: fecha y luego venta antes que abono', ...);
test('crear o renombrar un proveedor colapsa espacios dobles', ...);
// crear('  Postobón   S.A. ') → nombre 'Postobón S.A.'; editar igual.
testWidgets('entrar a la sesión no funde las pantallas', ...);
// Desde SeleccionarUsuario/PIN, iniciar sesión y hacer un solo pump(Duration.zero) más un frame:
// ya no está la pantalla anterior (sin FadeTransition a medio camino). La salida del inicio de
// marca sigue fundiéndose (la prueba existente no cambia).
```

- [ ] **Step 2: Run tests to verify they fail**

- [ ] **Step 3: Implement**

- `_nombreValido` colapsa los espacios internos con `replaceAll(RegExp(r'\s+'), ' ')` después del `trim`.
- `AnimatedSwitcher` usa la duración de `Movimiento` solo cuando la pantalla que sale es el inicio de
  marca: un `bool _desdeInicio` en el estado, puesto en `true` mientras se muestra `InicioMarcaScreen`
  y consumido al primer cambio. En los demás cambios la duración es `Duration.zero`.
- En `initState`, `preferencias.setBool(...)` va con `unawaited(...)` de `dart:async`: el valor en
  memoria cambia de inmediato y no hace falta esperar a que se escriba en disco.
- Se rompe el ciclo huella ↔ respaldo con el archivo nuevo, y el comparador queda en un solo lugar.

- [ ] **Step 4: Run tests to verify they pass**

- [ ] **Step 5: Commit** — `refactor: break the backup import cycle, share the fiado order and tidy names`

### Task 5: Cierre

- [ ] `flutter analyze` sin hallazgos y `flutter test` completo en verde.
- [ ] En `docs/hoja-de-ruta.md`, paso 2: tanda C hecha, con #53 fuera de alcance, y el paso 2
  completo. Commit `docs: record repair batch C` y `git push origin master`.
