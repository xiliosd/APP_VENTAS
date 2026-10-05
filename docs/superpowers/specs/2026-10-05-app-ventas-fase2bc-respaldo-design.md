# App de ventas — Fase 2B+2C (respaldo en la nube e identidad de la tienda)

**Fecha:** 2026-10-05
**Estado:** Borrador para revisión
**Base:** `docs/superpowers/specs/2026-10-05-app-ventas-fase2a-design.md`

## Contexto y alcance

Toda la información de la tienda vive en un archivo SQLite en el celular. Si el celular se pierde,
se daña o se formatea, los datos se pierden (riesgo principal documentado en `README.md`). Este
subproyecto agrega **respaldo y restauración** en Supabase, con la tienda identificada por su
número de celular (OTP).

Decisiones tomadas con el usuario:

- **Objetivo:** respaldo y restauración. Un solo celular por tienda sigue siendo la fuente de
  verdad; no hay sincronización entre varios dispositivos.
- **Canal OTP:** se diseña para SMS, pero esta fase arranca con los **números de prueba** de
  Supabase Auth (código fijo, sin enviar SMS). Conectar un proveedor real (Twilio u otro) es un
  cambio de configuración posterior, fuera de este spec.
- **Enfoque técnico:** copia completa del archivo SQLite en Supabase Storage (no replicación por
  tablas).
- **Proyecto Supabase:** no existe aún; el plan incluye crearlo.
- **Orden:** este spec se escribe ahora, pero se **implementa después de la Fase 2E** (experiencia
  de usuario y diseño visual), para que sus pantallas nazcan con el sistema de diseño nuevo. Las
  pantallas descritas aquí definen contenido y comportamiento, no estilo.

## Objetivo

1. Un admin puede activar el respaldo verificando el celular de la tienda con un código.
2. Con el respaldo activo, la base se sube sola a la nube tras los cambios, sin intervención.
3. En un celular nuevo (o tras borrar la app) se puede restaurar todo verificando el mismo
   número.
4. La app sigue funcionando 100% sin internet y sin registro; el respaldo es opcional.
5. Nunca se pierde por accidente un respaldo bueno ni los datos locales por un respaldo dañado.

## Comportamiento

### Primera pantalla (sin usuarios locales)

`BienvenidaScreen` reemplaza la entrada directa a "Configura tu tienda" y ofrece:

- **"Crear tienda nueva"** → flujo actual de creación del admin inicial.
- **"Ya tengo una tienda: restaurar respaldo"** → `VerificarTelefonoScreen` (modo restaurar).
  Solo visible si la app tiene configuración de Supabase.

Restaurar: tras verificar el código, si existe respaldo para ese número se descarga, se valida y
se reemplaza la base local; la app abre en "¿Quién eres?" con los usuarios restaurados, y cada
uno entra con su PIN de siempre. Si no existe respaldo: mensaje "No encontramos un respaldo para
este número" y se vuelve a la bienvenida (la sesión queda iniciada para activar el respaldo
luego de crear la tienda).

### Config → Respaldo (solo admin)

Nueva entrada en el menú de Configuración. Estados:

- **No configurado** (app compilada sin claves de Supabase): texto explicativo, sin acciones.
- **Desactivado:** botón **"Activar respaldo"** → `VerificarTelefonoScreen` (modo activar).
- **Activo:** muestra el número (`+57 300 *** 4567`), **"Último respaldo: hoy 14:32"** (o "Aún
  no hay respaldo"), botón **"Respaldar ahora"** y **"Desconectar"** (cierra la sesión; no borra
  el respaldo de la nube ni los datos locales).
- **Requiere reconexión** (sesión expirada o revocada): aviso "Reconecta el respaldo" con botón
  que lleva a verificar el número de nuevo.

Al activar, si el número **ya tiene un respaldo** en la nube, se pregunta antes de subir nada:
"Ya hay un respaldo de esta tienda del dd/mm/aaaa hh:mm. ¿Qué quieres hacer?"
- **"Restaurarlo en este celular"** (reemplaza los datos locales, con confirmación adicional
  "Se reemplazarán los datos de este celular").
- **"Reemplazarlo con los datos de este celular"** (sube la copia local).
- **"Cancelar"** (cierra la sesión; nada cambia).

### VerificarTelefonoScreen

- Campo de celular: prefijo **+57** fijo; el usuario escribe 10 dígitos (validación: `^3\d{9}$`,
  celulares colombianos). Botón "Enviarme el código".
- Campo de código de 6 dígitos y botón "Verificar". Opción "Reenviar código" tras 60 s.
- Errores visibles: número inválido, código incorrecto o vencido, sin internet.

### Respaldo automático

- Se ejecuta si hay sesión activa: al abrir la app y **30 s después del último cambio** en la base
  (varios cambios seguidos producen un solo respaldo).
- Un solo respaldo en curso a la vez; si llega un cambio durante un respaldo, se programa otro al
  terminar.
- Sin internet o con error: no se muestra nada intrusivo; se reintenta en el próximo cambio o al
  abrir la app. El estado visible en Config refleja el último éxito.
- Se guarda **solo la copia más reciente** por tienda.

## Arquitectura

Nueva carpeta `lib/respaldo/`. Mismas capas que el resto de la app (UI → providers → servicios).

### Dependencia y configuración

- Nueva dependencia: `supabase_flutter` (Auth por teléfono con OTP, Storage, persistencia de
  sesión).
- Claves por compilación: `--dart-define=SUPABASE_URL=...` y `--dart-define=SUPABASE_ANON_KEY=...`.
  Nada se guarda en el repositorio. Sin claves, el respaldo queda "No configurado" y
  `Supabase.initialize` no se llama.

### Unidades

- **`NubeRespaldo`** (interfaz) + **`SupabaseNubeRespaldo`** (implementación):
  - `Future<void> enviarCodigo(String telefonoE164)`
  - `Future<void> verificarCodigo(String telefonoE164, String codigo)`
  - `Future<void> cerrarSesion()`
  - `String? telefonoConectado` / `bool haySesion`
  - `Future<DateTime?> fechaUltimoRespaldo()` (fecha de actualización del objeto en Storage, o null)
  - `Future<void> subir(File copia)` (upsert)
  - `Future<void> descargar(File destino)`
  - Una `NubeRespaldoFalsa` en memoria para pruebas.
- **`CopiaBaseDatos`**:
  - `Future<File> crearCopia(AppDatabase db, Directory temporal)` — `VACUUM INTO` a un archivo
    temporal (copia consistente con la base abierta).
  - `Future<bool> esCopiaValida(File archivo)` — abre con `sqlite3` en solo lectura y verifica que
    existan las tablas `usuarios`, `productos`, `clientes`, `ventas`, `pagos_fiado`, `gastos` y que
    `user_version` no sea mayor que el `schemaVersion` de la app.
  - `Future<void> reemplazarBase(File copiaValida)` — copia sobre el archivo de la base local.
- **`ProgramadorRespaldo`**: escucha `tableUpdates()`, aplica el retardo de 30 s, garantiza un solo
  respaldo a la vez y expone el estado (`desactivado | activo | respaldando | requiereReconexion`
  + `ultimoRespaldo`) vía un provider.
- **Ruta de la base:** se extrae a una función `rutaBaseDatos()` reutilizada por
  `AppDatabase._openConnection` y por `reemplazarBase`.

### Restaurar con la app abierta

1. Descargar a un archivo temporal.
2. `esCopiaValida`; si falla → "El respaldo no se pudo leer; tus datos actuales no se tocaron" y
   fin.
3. Detener el programador, cerrar la `AppDatabase` actual, `reemplazarBase`, e
   `ref.invalidate(databaseProvider)` para que toda la app se reconstruya con la base restaurada;
   limpiar la sesión local de usuario (vuelve a "¿Quién eres?").

### Supabase (configuración del proyecto)

- Proyecto en el plan gratuito.
- Auth: proveedor **Phone** habilitado, con números de prueba configurados (p. ej.
  `+573000000001` → `123456`). Sin proveedor de SMS real en esta fase.
- Storage: bucket privado **`respaldos`**; un objeto por tienda en
  `<auth.uid>/app_ventas.sqlite`.
- Políticas RLS sobre `storage.objects` (cada cuenta solo accede a su carpeta):

```sql
create policy "respaldo propio: leer" on storage.objects for select to authenticated
  using (bucket_id = 'respaldos' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "respaldo propio: crear" on storage.objects for insert to authenticated
  with check (bucket_id = 'respaldos' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "respaldo propio: actualizar" on storage.objects for update to authenticated
  using (bucket_id = 'respaldos' and (storage.foldername(name))[1] = auth.uid()::text);
```

## Seguridad

- El respaldo solo es accesible con la sesión del número de la tienda (RLS); Supabase cifra el
  almacenamiento en reposo.
- **Riesgo conocido:** los PIN se guardan como SHA-256 sin sal; con 4 dígitos, quien obtenga el
  archivo puede deducirlos al instante. Mitigado por el control de acceso anterior; reforzar el
  hash de PIN (sal + KDF) queda fuera de este spec.
- La anon key es pública por diseño; la seguridad depende de RLS.

## Manejo de errores

| Situación | Comportamiento |
|---|---|
| Sin internet al respaldar | Silencioso; reintento en el próximo cambio o al abrir |
| Sesión expirada/revocada | Estado "Requiere reconexión" en Config |
| Código OTP incorrecto/vencido | Error bajo el campo; permite reenviar tras 60 s |
| Respaldo descargado dañado o de versión más nueva | No se toca nada local; mensaje claro |
| Restaurar sin respaldo existente | "No encontramos un respaldo para este número" |

## Pruebas

- **Unitarias (archivos SQLite reales en carpeta temporal):** `crearCopia` produce un archivo
  válido con los mismos datos; `esCopiaValida` rechaza un archivo basura, uno sin tablas y uno con
  `user_version` mayor; `reemplazarBase` deja la base restaurada legible.
- **ProgramadorRespaldo** (con `NubeRespaldoFalsa` y tiempo controlado con `tester.pump`): respalda
  30 s después del último cambio; varios cambios seguidos → un solo respaldo; sin sesión no
  respalda; error de la nube → estado sin cambiar y reintento en el siguiente cambio; un cambio
  durante un respaldo programa otro.
- **Widget:** bienvenida (con y sin configuración), verificar teléfono (validaciones, errores),
  Config → Respaldo en cada estado, diálogo "ya hay un respaldo" con sus tres salidas, restaurar
  con respaldo dañado.
- **Manual** contra el proyecto real con número de prueba en el emulador `app_ventas_ligero`:
  activar → registrar ventas → ver respaldo → borrar datos de la app → restaurar → entrar con PIN.

## Fuera de alcance

- Sincronización entre varios celulares o consulta remota del dueño.
- Historial de versiones del respaldo (solo la copia más reciente).
- Proveedor real de SMS/WhatsApp (solo números de prueba).
- Cifrado adicional del archivo y refuerzo del hash de PIN.
- Estilo visual de las pantallas nuevas (lo define la Fase 2E).
