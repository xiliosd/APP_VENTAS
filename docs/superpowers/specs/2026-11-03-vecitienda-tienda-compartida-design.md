# VeciTienda — Tienda compartida (paso 6) — diseño

Fecha: 2026-11-03. Conversación de diseño con el usuario (dueño del producto) el mismo día.
Hoja de ruta: `docs/hoja-de-ruta.md`, paso 6 (incluye lo que venía del paso 5).

## 1. Intención

Hoy cada tienda vive en **un solo celular** (base Drift/SQLite local) con un respaldo opcional
en Supabase (archivo `.sqlite` completo en el bucket `respaldos`). El tendero quiere que su
**vendedor de confianza trabaje desde su propio celular** con los mismos datos de la tienda.

Uso real descrito por el usuario:

- Una tienda tiene **un administrador**, o **un administrador y un vendedor**. Lo normal es
  trabajar **por turnos** (admin en la mañana, vendedor en la tarde), pero a veces el vendedor
  está todo el día y **los dos venden a la vez**.
- El vendedor es **de confianza**: maneja las finanzas. No se le recortan permisos.
- El internet de la tienda **se cae**: la app debe seguir funcionando sin conexión y, cuando
  vuelve, **subir sola** lo pendiente.

Éxito para el usuario: al llegar en la mañana abre la app y ve los reportes, el fiado y
"Por pedir" **como si todo hubiera pasado en un solo celular**.

## 2. Metas

1. Varios celulares en la misma tienda (diseñar para N vendedores; lo normal es 1).
2. Funciona sin internet igual que hoy; sincroniza en ambos sentidos al recuperar conexión.
3. El vendedor entra con **código de la tienda + identificador de vendedor + su PIN**, y el
   **admin aprueba** ese celular desde el suyo.
4. El admin puede **desactivar** al vendedor: su PIN se bloquea, su app se cierra y se borran
   los datos de la tienda en su celular.
5. Reportes, fiado, historial y "Por pedir" suman todos los celulares.
6. Avisos **dentro de la app abierta**: "por pedir" causado por ventas de otro celular y
   "Un celular nuevo quiere entrar como [nombre]".
7. Del paso 5: el vendedor activa **su huella** desde su cuenta en su celular, y ve un
   **recorrido corto** la primera vez que entra en su celular.

## 3. No metas

- Notificaciones con la app cerrada (push). Decisión del usuario: solo con la app abierta.
- Separar reportes por vendedor. El historial ya muestra quién hizo cada movimiento; se
  conserva, nada más.
- Recortar permisos del vendedor (permisos de inventario: cerrado sin cambios en el paso 5).
- Resolver choques de abonos simultáneos del mismo cliente: el usuario dice que no ocurre.
- Corregir ventas hechas con un precio viejo: si se vendió así, así queda.
- Más de un administrador por tienda (sí puede haber varios celulares del mismo admin).
- Tiendas de un solo celular obligadas a la nube: siguen como hoy.

## 4. Anti-metas (fallaría aunque "funcione")

- **Perder o duplicar** una venta, fiado, abono, gasto, entrada o conteo al sincronizar.
- Que un celular **desconocido** reciba datos de clientes sin aprobación del admin
  (Ley 1581 de 2012: nombres, teléfonos y deudas de clientes).
- Que la app **deje de vender sin internet** o se bloquee esperando la red.
- Romper las tiendas actuales: la actualización debe conservar todos sus datos.
- Que un vendedor desactivado siga bajando datos o registrando movimientos nuevos (solo
  puede entregar lo que hizo antes de la desactivación; ver llamada 9).

## 5. Decisiones del usuario

- **Entrada del vendedor:** el admin crea el usuario vendedor en Ajustes → Usuarios (como
  hoy). El vendedor instala la app, elige **"Unirme a una tienda"**, escribe el **código de la
  tienda**, su **identificador de vendedor** y su **PIN**. Al admin le llega (con la app
  abierta) **"Un celular nuevo quiere entrar como [nombre]"** y lo **aprueba o rechaza**. Solo
  con la aprobación el celular recibe los datos.
- **Salida del vendedor:** al desactivarlo desde el celular del admin, en el del vendedor se
  bloquea el PIN, la app se cierra (vuelve a la bienvenida) y **se borran los datos de la
  tienda** de ese celular (lo último fue propuesta aceptada por omisión; el usuario no lo
  objetó). Ocurre en cuanto ese celular tenga internet; desde la desactivación el servidor ya
  no le entrega nada (lo que hizo antes sí se recibe: llamada 9).
- **Sin conexión:** se sigue trabajando; al volver la conexión se sube y se baja lo pendiente.
- **Choques:** una venta con precio viejo se queda como se registró; abonos simultáneos no se
  consideran.
- **Reportes:** un solo resumen general, como si fuera un solo celular.
- **Avisos:** solo con la app abierta.
- **Tienda de un celular vs. compartida:** una tienda de un solo celular sigue como hoy con su
  respaldo por archivo. Cuando el admin **agrega el primer celular de un vendedor**, la tienda
  **pasa a ser compartida**: sube todos sus datos una vez y desde ahí la sincronización
  **reemplaza** al respaldo por archivo. Si el admin cambia de celular, entra con su correo
  (código OTP, como el respaldo de hoy) y recupera la tienda.
- **Huella del vendedor:** la activa él mismo desde su cuenta, en su celular.
- **Recorrido del vendedor:** la primera vez que abre la app en su celular.
- **Escala:** en noviembre de 2026 se usa con **una sola tienda**; desde **enero de 2027** la
  app sube a Google Play y serían **muchas tiendas**. El diseño debe ser multi-tienda desde el
  primer día (todo dato en la nube lleva `tienda_id`, RLS por tienda) y no depender de nada que
  solo funcione a escala de una tienda.

## 6. Restricciones y hechos del código actual

- Flutter + Riverpod + Drift (esquema v10, `lib/data/database.dart`), 16 tablas. Supabase ya
  integrado (`supabase_flutter` 2.18.0; auth por código de correo; bucket `respaldos` con RLS
  por `auth.uid()`). Claves en `dart_defines.json` (fuera de git).
- **Todas las tablas usan id entero autoincremental** y se referencian entre sí por esos ids.
  Con dos celulares chocarían ("venta 15" en ambos). Hay que pasar a **identificadores
  globales** (p. ej. UUID) o a un esquema equivalente, migrando las tiendas existentes **sin
  perder datos** ni romper referencias (incluida `correcciones.movimiento_id`, que apunta a
  tres tablas sin llave foránea).
- **Las existencias no se guardan**: se calculan desde movimientos (conteos, entradas, líneas
  de venta). Los conteos son absolutos ("había 12"), así que el cálculo debe ordenar por
  `fecha` del movimiento, no por orden de llegada al celular.
- Hay **borrados físicos** que la sincronización debe propagar (o reemplazar por marcas):
  `VentaRepository.eliminarVenta` ("Deshacer" justo después de cobrar),
  `CorreccionRepository` (borra líneas al corregir), `PedidoRepository` (reemplaza líneas),
  `ProductoRepository` (reemplaza proveedores del producto).
- Filas **mutables**: anular/corregir ventas, abonos y gastos; editar productos, clientes,
  proveedores, usuarios, configuración de la tienda (incluida la imagen QR en blob).
- PIN: `sha256` sin sal de 4 dígitos (`lib/util/pin_hash.dart`). Si los hashes viajan a la
  nube, son triviales de revertir; al compartir la tienda el PIN debe guardarse de forma que
  no se pueda sacar con fuerza bruta barata (sal + derivación lenta, o validación en el
  servidor con límite de intentos).
- Huella: lista `usuarios_con_huella` en SharedPreferences (por celular y por usuario). El
  interruptor vive en Ajustes (solo admin) — `ajustes_screen.dart` `_FilaHuella`.
- Recorrido: `recorrido_paso` en SharedPreferences, un solo valor por celular; `HomeScreen`
  solo lo atiende si `esAdmin`. Consejos de primera vez: `consejo_visto_<nombre>`, por
  celular.
- Proyecto personal: commit y push directo a `master`; sin Docker. Lineamientos UNIMINUTO
  (pruebas ≥ 80 % en módulos críticos — sincronización y autenticación cuentan como
  críticos —, `dart format`, `flutter analyze`, Conventional Commits, dependencias nuevas
  verificadas en pub.dev con versión fijada, nada de datos personales en logs).
- Supabase plan gratuito; región us-east-1. Correo OTP con SMTP propio (Gmail).

## 7. Llamadas mías (el usuario no las decidió; revisar)

1. **Entregas por separado**, cada una usable y probada en celular antes de seguir:
   - **E1 — Identificadores globales.** Migración local v10 → v11 a ids globales, sin cambio
     visible. Las tiendas de un celular siguen igual (respaldo por archivo incluido).
   - **E2 — Nube y sincronización del admin.** Esquema en Supabase, "convertir en tienda
     compartida" (subida inicial), sincronización en ambos sentidos, admin que cambia de
     celular recupera desde la sincronización. Aún sin vendedor.
   - **E3 — Entrada y salida del vendedor.** Código de tienda, identificador de vendedor,
     solicitud y aprobación, desactivación con borrado remoto.
   - **E4 — Del paso 5 y avisos.** Huella del vendedor desde su cuenta, recorrido corto del
     vendedor, avisos de "por pedir" y de celular nuevo con la app abierta.
2. **Choques en filas editables: gana el último cambio** (por fila, con marca de tiempo
   asignada por el servidor o reloj híbrido; no confiar solo en la hora del celular).
   Movimientos (ventas, abonos, gastos, entradas, conteos) son registros propios: nunca se
   pisan entre celulares; anular/corregir es editar ese registro.
3. **Sincronización propia sobre Drift + Supabase (Postgres con RLS)**, sin servicios de
   terceros de pago. Patrón sugerido: cada tabla en la nube con `tienda_id`, id global,
   `actualizado_en` y marca de borrado; el celular guarda qué falta subir y un cursor de lo
   último bajado. Disparadores: al abrir la app, tras cada cambio (con espera corta, como el
   respaldo de hoy), al recuperar red y, con la app abierta, por eventos de Supabase Realtime
   o sondeo. El constructor puede proponer otra forma si cumple metas y anti-metas.
4. **Identidad del celular del vendedor:** sesión de Supabase propia del celular (p. ej.
   inicio anónimo) asociada a una fila de "celular de la tienda" con estado
   `pendiente | aprobado | rechazado | revocado`. RLS da acceso a los datos de la tienda solo a
   celulares `aprobado` (y al admin por su correo). La validación del PIN del vendedor al
   unirse ocurre en el servidor (RPC o Edge Function) con límite de intentos.
5. **Código de la tienda:** corto, legible y aleatorio (p. ej. 6 caracteres sin letras que se
   confundan), visible para el admin en Ajustes. **Identificador de vendedor:** número corto
   por tienda (p. ej. 1, 2…) mostrado en Ajustes → Usuarios junto al nombre.
6. **Desactivar vendedor** = marca en el usuario (nuevo campo `activo`) + revocar sus celulares.
   El celular revocado, al enterarse, borra base local y preferencias de la tienda (incluida
   huella) y vuelve a la bienvenida.
7. El **respaldo por archivo** se apaga al convertir la tienda en compartida; la pantalla
   Ajustes → Respaldo pasa a mostrar el estado de la sincronización (última sincronización,
   pendientes).
8. Lo que no sube a la nube: huella, tamaño de letra, tema, recorrido y consejos (son del
   celular).
9. **Lo pendiente de un celular desactivado se sube** (recomendación aprobada por el usuario
   con el documento el 2026-11-03): al enterarse de la desactivación, el
   celular hace una última subida de los movimientos con `fecha` anterior a la desactivación,
   luego borra sus datos y vuelve a la bienvenida. El servidor acepta de un celular revocado
   solo esos movimientos (fecha < momento de revocación) y nada más; no le entrega datos.
10. **Varios celulares del admin:** el correo del admin puede abrir la tienda en más de un
    celular. Todos los celulares (del admin y de vendedores) aparecen en **"Celulares de la
    tienda"** (Ajustes) y cualquiera se puede desactivar con el mismo flujo de borrado; el
    celular desde el que se está no puede desactivarse a sí mismo.
11. **Una tienda por celular:** "Unirme a una tienda" solo aparece en la bienvenida (celular
    sin tienda). Un celular que ya tiene tienda no puede unirse a otra sin antes borrar sus
    datos. Una sola base Drift y preferencias globales, como hoy.
12. **Sin vuelta atrás:** una tienda compartida sigue compartida aunque se quede sin vendedor
    (la sincronización funciona con un solo celular). Borrar la copia en la nube de una tienda
    queda para "Después" junto con la política de privacidad.
13. **Versión mínima:** el protocolo de sincronización lleva versión; el servidor rechaza
    celulares por debajo de la mínima y la app muestra "Actualiza la app para seguir
    sincronizando" sin dejar de vender localmente. E1 (ids globales) es requisito de E2, así
    que ningún celular con ids viejos puede sincronizar.
14. **Escala y costo:** noviembre en plan gratuito de Supabase (una tienda, uso diario, así que
    la pausa por inactividad no aplica). Antes de abrir a muchas tiendas en enero, pasar a un
    plan de pago y revisar límites. Mientras tanto, diseño frugal: imagen QR en Storage, no en
    tablas; Realtime solo con la app abierta y con sondeo como respaldo si se cae; índices por
    `tienda_id` y `actualizado_en`; nada que crezca sin límite por celular (p. ej. registros de
    sincronización viejos se podan).

## 8. Lo que queda al constructor

- Esquema exacto de Postgres, políticas RLS y funciones del servidor.
- Estrategia de migración de ids (UUID v4/v7 u otra) y prueba de migración con una base v10
  real de ejemplo.
- Mecanismo de sincronización concreto, tamaño de lotes, reintentos, cómo mostrar
  "sincronizando" y errores sin texto crudo.
- Cómo sube la imagen QR (blob) — puede ir a Storage en vez de a la tabla.
- Pruebas: unidad para resolución de choques y cálculo de existencias con movimientos fuera de
  orden; integración de dos bases locales que sincronizan contra una nube simulada; casos de
  revocación y de celular sin red durante días.

## 9. Pendientes legales a recordar al usuario (no bloquean el diseño)

Ley 1581 de 2012: los datos de clientes ya viajan a la nube con el respaldo de hoy; con la
tienda compartida además llegan al celular del vendedor. Antes de usarla con otros tenderos
conviene un aviso de privacidad y la autorización de los clientes del fiado; también va en
"Después → Subida a Play Store".
