# Agregar un celular fácil (asistente + QR) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** El dueño agrega un celular con un asistente de 3 pasos y el vendedor se une escaneando
un QR y escribiendo solo su PIN; también cubre "Cambiar su celular" y "Soy yo, en otro celular".

**Architecture:** Un util puro arma y lee el texto del QR. Pantalla `AgregarCelularScreen` en
`lib/screens/agregar_celular/` con tres pasos (correo → quién → mostrar), reutilizando
`VerificarCorreoScreen`, `compartirTiendaConConfirmacion`, el formulario de usuario y
`responderSolicitudConAviso`. El celular del vendedor gana un modo de escáner QR en
`UnirseTiendaScreen`. Sin migración Supabase.

**Tech Stack:** Flutter, Riverpod, Drift, `mobile_scanner` 7.4.2 (ya está), `qr_flutter` 4.1.0
(nueva; verificada en pub.dev el 2026-11-20, última versión, sin descontinuar).

**Spec:** `docs/superpowers/specs/2026-11-20-agregar-celular-design.md`

## Global Constraints

- El PIN nunca va en el QR ni se muestra en la pantalla del dueño.
- Cada celular de vendedor sigue necesitando la aprobación del dueño.
- Nunca se reemplazan datos sin la confirmación que hoy existe (`TiendaCompartidaExistente`,
  respaldo existente).
- Etiquetas iguales en ambos celulares: `Código de la tienda`, `Número de vendedor`,
  `Tu PIN de 4 dígitos`.
- Formato QR: `vecitienda:unirse:1:<CODIGO>:<NUMERO>`; código de 6 caracteres del alfabeto
  `ABCDEFGHJKMNPQRSTUVWXYZ23456789`; número entero ≥ 1.
- Accesibilidad: el QR con `Semantics(label: 'Código QR para unir el celular de <nombre>')`;
  botones con texto; probar letra 2,0× en 360 dp sin desbordes en las pantallas nuevas.
- `dart format` solo en archivos tocados; `flutter analyze` limpio; `flutter test` verde;
  commits directo a `master` con `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. El dueño cierra el asistente en el paso 3 antes de aprobar: la solicitud no se pierde, el aviso
   global `AtenderSolicitudes` vuelve a funcionar → prueba en Task 4.
2. Sin internet en el paso 2 o 3: mensaje claro (`mensajeErrorTienda`), sin pantalla en blanco →
   prueba en Task 3 y Task 4.
3. Al cambiar de celular, solo se revoca el celular **anterior aprobado** del mismo vendedor,
   nunca el recién aprobado ni el de otro vendedor → prueba en Task 1 (`celularesAReemplazar`).
4. QR de otra app, de versión futura o con espacios/minúsculas → mensaje "Ese código no es de una
   tienda VeciTienda" y se puede volver a escanear → prueba en Task 1 y Task 2.
5. Llega la solicitud de **otro** vendedor mientras el paso 3 espera a uno: no se aprueba ahí;
   queda para el aviso global al salir → prueba en Task 4.

---

### Task 1: Texto del QR y celulares a reemplazar (lógica pura)

**Files:**
- Create: `lib/util/codigo_unirse.dart`
- Test: `test/util/codigo_unirse_test.dart`

**Interfaces:**
- Produces:
  - `typedef DatosUnirse = ({String codigo, int numero});`
  - `String textoCodigoUnirse({required String codigo, required int numero})`
  - `DatosUnirse? leerCodigoUnirse(String texto)` (null si no es válido; acepta espacios alrededor
    y código en minúsculas, que normaliza a mayúsculas)
  - `List<CelularTienda> celularesAReemplazar(List<CelularTienda> celulares, {required String idGlobal, required String usuarioAuthNuevo})`
    — los de `rol == 'vendedor'`, `estado == EstadoMiembro.aprobado`, `usuarioIdGlobal == idGlobal`
    y `usuarioAuth != usuarioAuthNuevo`.

- [ ] **Step 1: Write the failing tests** — ida y vuelta (`ABC234`, 3); `leerCodigoUnirse` da
  null para: `''`, `'https://x.com'`, `'vecitienda:unirse:2:ABC234:3'` (versión futura),
  `'vecitienda:unirse:1:ABC23:3'`, `'vecitienda:unirse:1:ABCI34:3'` (I no está en el alfabeto),
  `'vecitienda:unirse:1:ABC234:0'`, `'vecitienda:unirse:1:ABC234:x'`; acepta
  `'  vecitienda:unirse:1:abc234:12 '` → (`ABC234`, 12). `celularesAReemplazar`: con un aprobado
  del mismo vendedor, uno pendiente del mismo, uno aprobado de otro y el nuevo → solo el primero.
- [ ] **Step 2:** `flutter test test/util/codigo_unirse_test.dart` → FAIL (archivo no existe).
- [ ] **Step 3: Implement** las tres funciones.
- [ ] **Step 4:** → PASS.
- [ ] **Step 5: Commit** `feat: build and read the join QR text`

### Task 2: Celular del vendedor: escanear el QR y escribir solo el PIN

**Files:**
- Modify: `lib/servicios/uso_escaner.dart` (nuevo `UsoEscaner.unirse`, ayuda
  `'Apunta al código que te muestra el dueño en su celular'`),
  `lib/screens/escaner/escaner_screen.dart` (con `uso == UsoEscaner.unirse` los formatos son solo
  `BarcodeFormat.qrCode`), `lib/screens/vendedor/unirse_tienda_screen.dart`,
  `lib/screens/login/bienvenida_screen.dart` (texto del botón `boton_restaurar_tienda`:
  `Ya tengo una tienda (soy el dueño)`), `lib/screens/ayuda/preguntas_frecuentes.dart` (mismo
  texto donde lo cite)
- Test: `test/screens/vendedor/unirse_tienda_test.dart`, `test/screens/login/bienvenida_screen_test.dart`

**Interfaces:**
- Consumes: `leerCodigoUnirse` (Task 1); `lectorCodigoProvider` / `LectorCodigo.leer(context, uso:)`.

Comportamiento de `UnirseTiendaScreen`: arriba, `BotonPrincipal`
`Key('boton_escanear_dueno')` "Escanear el código del dueño". Lectura válida → tarjeta
`Key('tienda_encontrada')` con "Tienda encontrada · Eres el vendedor N.º X", se ocultan los
campos de código y número y queda solo el PIN (con foco). Lectura inválida → texto de error
`Ese código no es de una tienda VeciTienda` y el botón sigue disponible. `TextButton`
`Key('escribir_a_mano')` "Escribir los datos a mano" muestra los tres campos con etiquetas
`Código de la tienda` (hint `Ej.: K7M2QX`), `Número de vendedor` (hint `Ej.: 3`, letra 20 y
negrita) y `Tu PIN de 4 dígitos`. "Pedir entrada" envía igual que hoy.

- [ ] **Step 1: Write the failing tests** (con `LectorFalso` del soporte de pruebas):
  `escanear un QR válido deja solo el PIN` (finds `tienda_encontrada`, text `Eres el vendedor
  N.º 3`, findsNothing `campo_codigo_tienda`); `escanear y escribir el PIN pide entrada con el
  código y el número del QR` (SincronizacionFalsa registra `unirse(codigo: 'ABC234',
  numeroVendedor: 3, pin: '1234')` — agregar el registro a la falsa si no existe);
  `un QR que no es de VeciTienda lo dice y deja volver a escanear`; `escribir a mano muestra los
  tres campos con sus etiquetas`; bienvenida: `el botón del dueño dice Ya tengo una tienda (soy
  el dueño)`; `a letra 2,0× en 360 dp no desborda` (con tienda encontrada).
- [ ] **Step 2:** → FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4:** → PASS; `flutter test` completo.
- [ ] **Step 5: Commit** `feat: let a seller join by scanning the owner's QR`

### Task 3: Asistente del dueño, pasos 1 y 2

**Files:**
- Create: `lib/screens/agregar_celular/agregar_celular_screen.dart`,
  `lib/screens/agregar_celular/paso_quien.dart`, `lib/screens/agregar_celular/paso_soy_yo.dart`
- Modify: `lib/screens/respaldo/respaldo_screen.dart` (`compartirTiendaConConfirmacion` gana
  `{bool preguntar = true}`: con `false` no muestra el primer diálogo; las ramas de
  `TiendaCompartidaExistente` no cambian), `lib/screens/configuracion/usuarios_screen.dart`
  (`_FormularioUsuario` pasa a `FormularioUsuario` público en
  `lib/screens/configuracion/formulario_usuario.dart`, con `{bool soloVendedor = false}` que
  oculta el selector de rol, y cierra con el `int` id del usuario creado en vez de `true`)
- Test: `test/screens/agregar_celular/agregar_celular_screen_test.dart`, tests existentes de
  usuarios y respaldo

**Interfaces:**
- Consumes: `celularesAReemplazar` (Task 1) para la etiqueta "Cambiar su celular";
  `respaldoProvider` (`fase`, `correo`); `SincronizacionNotifier.esCompartida()`, `.celulares()`;
  `UsuarioRepository.listarActivos()`.
- Produces: `AgregarCelularScreen({Usuario? vendedor})` — con `vendedor` abre directo en el paso 3
  (lo usa Task 5); `class PasoMostrar` lo crea Task 4 y este task lo invoca con
  `PasoMostrar(vendedor: Usuario, cambiaCelular: bool)`.

Comportamiento:
- **Paso 1** (si `respaldoProvider.fase != activo` o la tienda no es compartida): título
  `Confirma tu correo`, texto `Para que los celulares compartan las ventas, la tienda se guarda en
  la nube con tu correo.` y botón `Key('boton_confirmar_correo')` que abre
  `VerificarCorreoScreen(modo: ModoVerificacion.activar)`; al volver con respaldo activo llama
  `compartirTiendaConConfirmacion(context, ref, preguntar: false)`; si queda compartida, pasa al 2.
  Si ya está todo listo, el asistente arranca en el paso 2.
- **Paso 2** `¿Quién va a usar el celular?`: una fila por vendedor activo
  (`Key('quien_<id>')`), con subtítulo `Cambiar su celular` si `celulares()` tiene un aprobado
  con su `idGlobal`; `Key('quien_otra_persona')` "Otra persona" abre `FormularioUsuario(
  soloVendedor: true)` y sigue al paso 3 con el creado (asegurando su número con
  `asegurarNumeroVendedor` y `sincronizarAhora()` como hace hoy `conectarCelularVendedor`);
  `Key('quien_soy_yo')` "Soy yo, en otro celular" abre `PasoSoyYo`.
- **PasoSoyYo**: lista numerada en letra grande: `1. Instala VeciTienda en el otro celular.`,
  `2. Toca "Ya tengo una tienda (soy el dueño)".`, `3. Escribe este correo:` + el correo de
  `respaldoProvider` en negrita (`Key('correo_dueno')`), `4. Escribe el código que te llega al
  correo.` y botón "Listo".
- Error al cargar celulares (sin internet): `mensajeErrorTienda(error)` en el lugar de la lista y
  botón "Reintentar".

- [ ] **Step 1: Write the failing tests** — `con respaldo inactivo empieza pidiendo el correo`;
  `con la tienda compartida empieza en Quién`; `un vendedor con celular aprobado dice Cambiar su
  celular`; `Otra persona crea un vendedor y pasa al paso 3` (finds `PasoMostrar` — en este task
  un stub mínimo de `PasoMostrar` en su archivo, Task 4 lo completa); `Soy yo muestra los pasos con
  el correo de la tienda` (`correo_dueno` muestra `tienda@correo.com`); `sin internet en Quién
  muestra el mensaje y Reintentar`; respaldo: `compartir sin preguntar no muestra el diálogo y
  comparte` (`compartidas == 1`, findsNothing `confirmar_compartir`); usuarios: tests existentes
  siguen verdes con el formulario movido.
- [ ] **Step 2:** → FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4:** → PASS; `flutter test` completo.
- [ ] **Step 5: Commit** `feat: guide the owner to add a phone, first steps`

### Task 4: Paso 3: QR, datos claros y aprobar ahí mismo

**Files:**
- Modify: `pubspec.yaml` (`qr_flutter: 4.1.0`), `lib/screens/agregar_celular/paso_mostrar.dart`
  (completa el stub), `lib/screens/configuracion/atender_solicitudes.dart`
- Test: `test/screens/agregar_celular/paso_mostrar_test.dart`,
  `test/screens/configuracion/atender_solicitudes_test.dart` (o el existente que la cubra)

**Interfaces:**
- Consumes: `textoCodigoUnirse`, `celularesAReemplazar` (Task 1);
  `SincronizacionNotifier.codigoTienda()`, `.sincronizarAhora()`, `.celulares()`,
  `.revocarCelular(String usuarioAuth)`; `sincronizacionProvider.solicitudes`.
  `responderSolicitudConAviso(context, ref, solicitud, aprobar:)` pasa a devolver
  `Future<bool>` (true si la nube respondió bien) para revocar el celular viejo solo si la
  aprobación salió; los llamadores actuales ignoran el valor.
- Produces: `final asistenteCelularAbiertoProvider = StateProvider<bool>((ref) => false);` en
  `paso_mostrar.dart`; `AtenderSolicitudes` no muestra su diálogo mientras sea `true` y, al volver
  a `false`, atiende lo que quedó (`ref.listen`).

Comportamiento de `PasoMostrar(vendedor, cambiaCelular)`:
- `QrImageView(data: textoCodigoUnirse(...), size: 240)` dentro de `Semantics`; debajo
  "¿No funciona la cámara?" con `Código de la tienda` (`Key('dato_codigo')`) y
  `Número de vendedor` (`Key('dato_numero')`) en letra 28 negrita, y
  `Su PIN es el que le diste (no se muestra aquí).`
- Marca `asistenteCelularAbiertoProvider` en `true` al entrar y `false` en `dispose`; mientras
  está abierto llama `sincronizarAhora()` cada 5 s (`Timer.periodic`, cancelado en `dispose`).
- Estado: `Esperando que <nombre> escanee…`; cuando en `solicitudes` aparece una con
  `usuarioIdGlobal == vendedor.idGlobal`, muestra `<nombre> pide entrar desde <nombreCelular>` y
  `BotonPrincipal` `Key('aprobar_aqui')` "Aprobar"; si `cambiaCelular`, antes del botón:
  `Su celular anterior dejará de tener los datos de la tienda.` Al aprobar: responder con
  `responderSolicitudConAviso`, luego `revocarCelular` para cada `celularesAReemplazar(...)`, y
  mostrar `¡Listo! <nombre> ya puede vender desde su celular` con botón "Terminar".
- Solicitudes de otros vendedores no se muestran aquí.

- [ ] **Step 1:** verificar `qr_flutter` en https://pub.dev/packages/qr_flutter (4.1.0, no
  descontinuado), agregarlo fijo y `flutter pub get`.
- [ ] **Step 2: Write the failing tests** — `muestra el QR, el código y el número, nunca el PIN`
  (finds `QrImageView`, `ABC234`, `3`; findsNothing del PIN `1234`); `cuando el vendedor pide
  entrar se aprueba aquí` (estado con solicitud de su `idGlobal` → tap `aprobar_aqui` →
  `respuestas == [(auth, true)]`, texto `¡Listo! Beto ya puede vender desde su celular`);
  `si la aprobación falla no revoca el celular anterior` (SincronizacionFalsa con error al
  responder → `revocaciones` vacío, mensaje de error visible);
  `al cambiar de celular revoca solo el anterior` (`revocaciones == ['auth-viejo']`);
  `la solicitud de otro vendedor no aparece aquí`; `mientras está abierto el aviso global no sale
  y al cerrar sí` (montar `AtenderSolicitudes` + `PasoMostrar`, solicitud pendiente, sin
  `AlertDialog`; pop → `AlertDialog` aparece); `sin internet al pedir el código muestra el
  mensaje`; `a letra 2,0× en 360 dp no desborda`.
- [ ] **Step 3:** → FAIL.
- [ ] **Step 4: Implement.**
- [ ] **Step 5:** → PASS; `flutter test` completo.
- [ ] **Step 6: Commit** `feat: show the join QR and approve the phone in place`

### Task 5: Entradas al asistente, Celulares sin compartir y ayuda

**Files:**
- Modify: `lib/screens/configuracion/ajustes_screen.dart` (opción `Key('menu_agregar_celular')`
  "Agregar un celular", subtítulo `Para un vendedor o para ti`, arriba de "Celulares de la
  tienda", visible siempre para el admin), `lib/screens/configuracion/celulares_tienda_screen.dart`
  (botón `Key('boton_agregar_celular')` "Agregar un celular" arriba; si la tienda no es compartida,
  en vez del error muestra `Aún no hay otros celulares.` y el mismo botón),
  `lib/screens/configuracion/usuarios_screen.dart` (`conectar_celular_<id>` abre
  `AgregarCelularScreen(vendedor: u)`), `lib/screens/ayuda/preguntas_frecuentes.dart`
- Delete: `lib/screens/configuracion/conectar_vendedor_sheet.dart` (sus pruebas pasan a probar
  que el botón abre el asistente)
- Test: `ajustes_screen_test.dart`, `celulares_tienda_screen_test.dart`,
  `usuarios_screen_test.dart`, `preguntas_frecuentes_test.dart`

**Interfaces:**
- Consumes: `AgregarCelularScreen({Usuario? vendedor})` (Task 3).

- [ ] **Step 1: Write the failing tests** — `Ajustes tiene Agregar un celular y lo abre`;
  `Celulares sin tienda compartida ofrece Agregar un celular en vez del error`;
  `el botón del celular de un vendedor abre el asistente en el paso 3` (finds `PasoMostrar`);
  FAQ: `¿Cómo entra un vendedor desde su celular?` contiene `"Agregar un celular"` y
  `escanea`; nueva pregunta `¿Cómo uso la tienda en otro celular mío?` contiene
  `Ya tengo una tienda (soy el dueño)`.
- [ ] **Step 2:** → FAIL.
- [ ] **Step 3: Implement**; borrar `conectar_vendedor_sheet.dart` y adaptar sus pruebas.
- [ ] **Step 4:** → PASS; `flutter test` completo; `flutter analyze`.
- [ ] **Step 5: Commit** `feat: open the add-phone guide from Ajustes, Celulares and Usuarios`
